const Op = @import("op.zig").Op;
const OpTag = @import("op.zig").OpTag;
const Span = @import("span.zig").Span;
const Value = @import("value.zig").Value;
const std = @import("std");

pub const CodecError = error{
    InvalidFormat,
    UnsupportedVersion,
    UnexpectedEof,
};

pub fn writeU32(w: anytype, v: u32) !void {
    try w.writeInt(u32, v, .little);
}

pub fn readU32(r: anytype) !u32 {
    return try r.readInt(u32, .little);
}

pub fn writeUsize(w: anytype, v: usize) !void {
    try writeU32(w, @intCast(v));
}

pub fn readUsize(r: anytype) !usize {
    const v = try readU32(r);
    return @intCast(v);
}

pub fn writeU8(w: anytype, v: u8) !void {
    try w.writeByte(v);
}

pub fn readU8(r: anytype) !u8 {
    return try r.readByte();
}

pub fn writeBytes(w: anytype, bytes: []const u8) !void {
    try w.writeAll(bytes);
}

pub fn readExact(r: anytype, buf: []u8) !void {
    try r.readNoEof(buf);
}

pub fn writeString(w: anytype, s: []const u8) !void {
    try writeU32(w, @intCast(s.len));
    try w.writeAll(s);
}

pub fn readString(
    allocator: std.mem.Allocator,
    r: anytype,
) ![]u8 {
    const len = try readU32(r);
    const buf = try allocator.alloc(u8, len);
    errdefer allocator.free(buf);

    try r.readNoEof(buf);
    return buf;
}

pub fn readStringAlloc(allocator: std.mem.Allocator, r: anytype) ![]u8 {
    const len = try readU32(r);
    const buf = try allocator.alloc(u8, len);
    errdefer allocator.free(buf);
    try r.readNoEof(buf);
    return buf;
}

pub fn writeSpan(w: anytype, s: Span) !void {
    try writeUsize(w, s.start);
    try writeUsize(w, s.end);
    try writeUsize(w, s.line);
    try writeUsize(w, s.column);
}

pub fn readSpan(r: anytype) !Span {
    return .{
        .start = try readUsize(r),
        .end = try readUsize(r),
        .line = try readUsize(r),
        .column = try readUsize(r),
    };
}

pub fn writeValue(w: anytype, v: Value) !void {
    switch (v) {
        .identifier => |id| {
            try writeU8(w, 0);
            try writeUsize(w, id.name);
            try writeSpan(w, id.span);
        },
        .literal => |lit| switch (lit) {
            .number => |n| {
                try writeU8(w, 1);
                try w.writeAll(std.mem.asBytes(&n.value));
                try writeSpan(w, n.span);
            },
            .string => |s| {
                try writeU8(w, 2);
                try writeUsize(w, s.value);
                try writeSpan(w, s.span);
            },
        },
        .truth => |span| {
            try writeU8(w, 3);
            try writeSpan(w, span);
        },
        .none => |span| {
            try writeU8(w, 4);
            try writeSpan(w, span);
        },
        .compare => |c| {
            try writeU8(w, 5);
            try writeValue(w, c.left.*);
            try writeValue(w, c.right.*);
            try writeSpan(w, c.span);
        },
    }
}

pub fn readValue(allocator: std.mem.Allocator, r: anytype) !Value {
    const tag = try readU8(r);
    return switch (tag) {
        0 => .{
            .identifier = .{
                .name = try readUsize(r),
                .span = try readSpan(r),
            },
        },
        1 => blk: {
            var num: f64 = undefined;
            try r.readNoEof(std.mem.asBytes(&num));
            break :blk .{
                .literal = .{
                    .number = .{ .value = num, .span = try readSpan(r) },
                },
            };
        },
        2 => .{
            .literal = .{
                .string = .{
                    .value = try readUsize(r),
                    .span = try readSpan(r),
                },
            },
        },
        3 => .{
            .truth = try readSpan(r),
        },
        4 => .{
            .none = try readSpan(r),
        },
        5 => blk: {
            var left_val = try readValue(allocator, r);
            errdefer left_val.deinit(allocator);

            var right_val = try readValue(allocator, r);
            errdefer right_val.deinit(allocator);

            const sp = try readSpan(r);

            const left_ptr = try allocator.create(Value);
            errdefer {
                left_ptr.*.deinit(allocator);
                allocator.destroy(left_ptr);
            }
            left_ptr.* = left_val;

            left_val = .{ .none = .{ .start = 0, .end = 0, .line = 0, .column = 0 } };

            const right_ptr = try allocator.create(Value);
            errdefer {
                right_ptr.*.deinit(allocator);
                allocator.destroy(right_ptr);
            }
            right_ptr.* = right_val;

            right_val = .{ .none = .{ .start = 0, .end = 0, .line = 0, .column = 0 } };

            break :blk .{
                .compare = .{
                    .left = left_ptr,
                    .right = right_ptr,
                    .span = sp,
                },
            };
        },
        else => return error.InvalidFormat,
    };
}

pub fn writeOp(w: anytype, op: Op) !void {
    switch (op) {
        .Assign => |a| {
            try writeU8(w, @intFromEnum(OpTag.Assign));
            try writeSpan(w, a.span);
            try writeUsize(w, a.name);
            try writeValue(w, a.value);
        },
        .Print => |y| {
            try writeU8(w, @intFromEnum(OpTag.Print));
            try writeSpan(w, y.span);
            try writeValue(w, y.value);
        },
        .Throw => |t| {
            try writeU8(w, @intFromEnum(OpTag.Throw));
            try writeSpan(w, t.span);
            try writeUsize(w, t.message);
        },
    }
}

pub fn readOp(allocator: std.mem.Allocator, r: anytype) !Op {
    const tag_u8 = try readU8(r);
    const tag: OpTag = @enumFromInt(tag_u8);

    return switch (tag) {
        .Assign => blk: {
            const span = try readSpan(r);
            const name = try readUsize(r);
            const value = try readValue(allocator, r);
            break :blk .{ .Assign = .{ .name = name, .value = value, .span = span } };
        },
        .Print => blk: {
            const span = try readSpan(r);
            const value = try readValue(allocator, r);
            break :blk .{ .Print = .{ .value = value, .span = span } };
        },
        .Throw => blk: {
            const span = try readSpan(r);
            const message = try readUsize(r);
            break :blk .{ .Throw = .{ .message = message, .span = span } };
        },
    };
}

pub fn writeOps(ops: []const Op, w: anytype) !void {
    try writeU32(w, @intCast(ops.len));
    for (ops) |op| {
        try writeOp(w, op);
    }
}

pub fn readOps(allocator: std.mem.Allocator, r: anytype) ![]Op {
    const count_u32 = try readU32(r);
    const count: usize = @intCast(count_u32);

    const ops = try allocator.alloc(Op, count);
    errdefer allocator.free(ops);

    for (ops) |*op| {
        op.* = try readOp(allocator, r);
    }

    return ops;
}

pub fn writeStringTable(strings: []const []const u8, w: anytype) !void {
    try writeU32(w, @intCast(strings.len));
    for (strings) |s| try writeString(w, s);
}

pub fn readStringTable(allocator: std.mem.Allocator, r: anytype) ![]const []const u8 {
    const n = @as(usize, @intCast(try readU32(r)));
    const table = try allocator.alloc([]const u8, n);
    errdefer {
        for (table[0..]) |s| allocator.free(s);
        allocator.free(table);
    }

    for (table) |*slot| {
        slot.* = try readStringAlloc(allocator, r);
    }

    return table;
}
