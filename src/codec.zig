const Op = @import("op.zig").Op;
const OpTag = @import("op.zig").OpTag;
const Span = @import("span.zig").Span;
const Value = @import("op.zig").Value;
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
    try w.writeInt(usize, v, .little);
}

pub fn readUsize(r: anytype) !usize {
    return try r.readInt(usize, .little);
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
            try writeString(w, id.name);
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
                try writeString(w, s.value);
                try writeSpan(w, s.span);
            },
        },
    }
}

pub fn readValue(allocator: std.mem.Allocator, r: anytype) !Value {
    const tag = try readU8(r);
    return switch (tag) {
        0 => .{
            .identifier = .{
                .name = try readStringAlloc(allocator, r),
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
                    .value = try readStringAlloc(allocator, r),
                    .span = try readSpan(r),
                },
            },
        },
        else => return error.InvalidFormat,
    };
}

pub fn writeOp(w: anytype, op: Op) !void {
    switch (op) {
        .Assign => |a| {
            try writeU8(w, @intFromEnum(OpTag.Assign));
            try writeSpan(w, a.span);
            try writeString(w, a.name);
            try writeValue(w, a.value);
        },
        .Yap => |y| {
            try writeU8(w, @intFromEnum(OpTag.Yap));
            try writeSpan(w, y.span);
            try writeValue(w, y.value);
        },
        .Throw => |t| {
            try writeU8(w, @intFromEnum(OpTag.Throw));
            try writeSpan(w, t.span);
            try writeString(w, t.message);
        },
    }
}

pub fn readOp(allocator: std.mem.Allocator, r: anytype) !Op {
    const tag_u8 = try readU8(r);
    const tag: OpTag = @enumFromInt(tag_u8);

    return switch (tag) {
        .Assign => blk: {
            const span = try readSpan(r);
            const name = try readStringAlloc(allocator, r);
            const value = try readValue(allocator, r);
            break :blk .{ .Assign = .{ .name = name, .value = value, .span = span } };
        },
        .Yap => blk: {
            const span = try readSpan(r);
            const value = try readValue(allocator, r);
            break :blk .{ .Yap = .{ .value = value, .span = span } };
        },
        .Throw => blk: {
            const span = try readSpan(r);
            const message = try readStringAlloc(allocator, r);
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
