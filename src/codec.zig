const Calculation = @import("value.zig").Calculation;
const Ir = @import("ir.zig").Ir;
const LiteralTag = @import("value.zig").LiteralTag;
const Op = @import("op.zig").Op;
const Span = @import("span.zig").Span;
const Value = @import("value.zig").Value;
const std = @import("std");

pub const YAPC_MAGIC: []const u8 = "YAPC";
pub const YAPC_VERSION: u32 = 2;

pub const CodecError = error{
    InvalidFormat,
    UnsupportedVersion,
    UnexpectedEof,
};

// Helpers

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
    r: anytype,
    allocator: std.mem.Allocator,
) ![]u8 {
    const len = try readU32(r);
    const buf = try allocator.alloc(u8, len);
    errdefer allocator.free(buf);

    try r.readNoEof(buf);
    return buf;
}
pub fn readStringAlloc(r: anytype, allocator: std.mem.Allocator) ![]u8 {
    const len = try readU32(r);
    const buf = try allocator.alloc(u8, len);
    errdefer allocator.free(buf);
    try r.readNoEof(buf);
    return buf;
}

fn isYapcFile(file: std.fs.File) !bool {
    var magic: [4]u8 = undefined;
    const pos = try file.getPos();
    defer file.seekTo(pos) catch {};

    const n = try file.read(&magic);
    if (n < 4) return false;

    return std.mem.eql(u8, magic[0..], YAPC_MAGIC);
}

// Structs

pub fn writeIr(w: anytype, ir: Ir) !void {
    try w.writeAll(YAPC_MAGIC);
    try writeU32(w, YAPC_VERSION);

    try writeStringTable(w, ir.strings);
    try writeOps(w, ir.ops);
}
pub fn readIr(r: anytype, allocator: std.mem.Allocator) !Ir {
    var magic: [4]u8 = undefined;
    try r.readNoEof(&magic);
    if (!std.mem.eql(u8, magic[0..], YAPC_MAGIC)) return error.InvalidFormat;

    const version = try readU32(r);
    if (version != YAPC_VERSION) return error.UnsupportedVersion;

    const strings = try readStringTable(allocator, r);
    errdefer {
        for (strings) |s| allocator.free(s);
        allocator.free(strings);
    }

    const ops = try readOps(allocator, r);
    errdefer {
        for (ops) |op| op.deinit(allocator);
        allocator.free(ops);
    }

    return Ir.init(allocator, strings, ops);
}

pub fn writeStringTable(w: anytype, strings: []const []const u8) !void {
    try writeU32(w, @intCast(strings.len));
    for (strings) |s| try writeString(w, s);
}
pub fn readStringTable(
    allocator: std.mem.Allocator,
    r: anytype,
) ![]const []const u8 {
    const n = @as(usize, @intCast(try readU32(r)));
    const table = try allocator.alloc([]const u8, n);
    errdefer {
        for (table[0..]) |s| allocator.free(s);
        allocator.free(table);
    }

    for (table) |*slot| {
        slot.* = try readStringAlloc(r, allocator);
    }

    return table;
}

pub fn writeOps(w: anytype, ops: []const Op) !void {
    try writeU32(w, @intCast(ops.len));
    for (ops) |op| try writeOp(w, op);
}
pub fn readOps(
    allocator: std.mem.Allocator,
    r: anytype,
) ![]Op {
    const count_u32 = try readU32(r);
    const count: usize = @intCast(count_u32);

    const ops = try allocator.alloc(Op, count);
    errdefer allocator.free(ops);

    for (ops) |*op| {
        op.* = try readOp(r, allocator);
    }

    return ops;
}

pub fn writeOp(w: anytype, op: Op) !void {
    const tag = @intFromEnum(std.meta.activeTag(op));
    try writeU8(w, tag);

    switch (op) {
        .Assign => |a| {
            try writeSpan(w, a.span);
            try writeUsize(w, a.name);
            try writeValue(w, a.value);
        },
        .Print => |p| {
            try writeSpan(w, p.span);
            try writeValue(w, p.value);
        },
        .Throw => |t| {
            try writeSpan(w, t.span);
            try writeUsize(w, t.event);
        },
        .Mem => |m| {
            try writeSpan(w, m.span);
            try writeUsize(w, m.event);
        },
        .If => |i| {
            try writeValue(w, i.condition);
            try writeU32(w, @intCast(i.then_ops.len));
            for (i.then_ops) |then_op| try writeOp(w, then_op);
            try writeSpan(w, i.span);
        },
        .IfElse => |ie| {
            try writeValue(w, ie.condition);
            try writeU32(w, @intCast(ie.then_ops.len));
            for (ie.then_ops) |then_op| try writeOp(w, then_op);
            try writeU32(w, @intCast(ie.else_ops.len));
            for (ie.else_ops) |else_op| try writeOp(w, else_op);
            try writeSpan(w, ie.span);
        },
    }
}
pub fn readOp(r: anytype, allocator: std.mem.Allocator) !Op {
    const tag_u8 = try readU8(r);
    const tag: std.meta.Tag(Op) = @enumFromInt(tag_u8);

    return switch (tag) {
        .Assign => blk: {
            const span = try readSpan(r);
            const name = try readUsize(r);
            const value = try readValue(r, allocator);
            break :blk .{ .Assign = .{ .name = name, .value = value, .span = span } };
        },
        .Print => blk: {
            const span = try readSpan(r);
            const value = try readValue(r, allocator);
            break :blk .{ .Print = .{ .value = value, .span = span } };
        },
        .Throw => blk: {
            const span = try readSpan(r);
            const event = try readUsize(r);
            break :blk .{ .Throw = .{ .event = event, .span = span } };
        },
        .Mem => blk: {
            const span = try readSpan(r);
            const event = try readUsize(r);
            break :blk .{ .Mem = .{ .event = event, .span = span } };
        },
        .If => blk: {
            const condition = try readValue(r, allocator);

            const then_count_u32 = try readU32(r);
            const then_count: usize = @intCast(then_count_u32);
            const then_ops = try allocator.alloc(Op, then_count);
            errdefer {
                for (then_ops) |*op| op.deinit(allocator);
                allocator.free(then_ops);
            }
            for (then_ops) |*op| {
                op.* = try readOp(r, allocator);
            }

            const span = try readSpan(r);

            break :blk .{ .If = .{ .condition = condition, .then_ops = then_ops, .span = span } };
        },
        .IfElse => blk: {
            const condition = try readValue(r, allocator);

            const then_count_u32 = try readU32(r);
            const then_count: usize = @intCast(then_count_u32);
            const then_ops = try allocator.alloc(Op, then_count);
            errdefer {
                for (then_ops) |*op| op.deinit(allocator);
                allocator.free(then_ops);
            }
            for (then_ops) |*op| {
                op.* = try readOp(r, allocator);
            }

            const else_count_u32 = try readU32(r);
            const else_count: usize = @intCast(else_count_u32);
            const else_ops = try allocator.alloc(Op, else_count);
            errdefer {
                for (else_ops) |*op| op.deinit(allocator);
                allocator.free(else_ops);
            }
            for (else_ops) |*op| {
                op.* = try readOp(r, allocator);
            }

            const span = try readSpan(r);

            break :blk .{
                .IfElse = .{
                    .condition = condition,
                    .then_ops = then_ops,
                    .else_ops = else_ops,
                    .span = span,
                },
            };
        },
    };
}

pub fn writeValue(w: anytype, v: Value) !void {
    const tag = @intFromEnum(std.meta.activeTag(v));
    try writeU8(w, tag);

    switch (v) {
        .identifier => |id| {
            try writeUsize(w, id.name);
            try writeSpan(w, id.span);
        },
        .literal => |lit| {
            const lit_tag = @intFromEnum(std.meta.activeTag(lit));
            try writeU8(w, lit_tag);

            switch (lit) {
                .number => |n| {
                    try w.writeAll(std.mem.asBytes(&n.value));
                    try writeSpan(w, n.span);
                },
                .string => |s| {
                    try writeUsize(w, s.value);
                    try writeSpan(w, s.span);
                },
            }
        },
        .truth => |sp| {
            try writeSpan(w, sp);
        },
        .none => |sp| {
            try writeSpan(w, sp);
        },
        .calculate => |c| {
            const calculation_tag = @intFromEnum(c.operation);
            try writeU8(w, calculation_tag);
            try writeValue(w, c.left.*);
            try writeValue(w, c.right.*);
            try writeSpan(w, c.span);
        },
    }
}
pub fn readValue(r: anytype, allocator: std.mem.Allocator) !Value {
    const tag_u8 = try readU8(r);
    const tag: std.meta.Tag(Value) = @enumFromInt(tag_u8);

    return switch (tag) {
        .identifier => blk: {
            const name = try readUsize(r);
            const span = try readSpan(r);
            break :blk .{ .identifier = .{ .name = name, .span = span } };
        },
        .literal => literal: {
            const lit_tag = try readU8(r);
            const lit_kind: LiteralTag = @enumFromInt(lit_tag);

            break :literal switch (lit_kind) {
                .number => blk: {
                    var num: f64 = undefined;
                    try r.readNoEof(std.mem.asBytes(&num));
                    const span = try readSpan(r);

                    break :blk .{
                        .literal = .{
                            .number = .{ .value = num, .span = span },
                        },
                    };
                },
                .string => blk: {
                    const value = try readUsize(r);
                    const span = try readSpan(r);

                    break :blk .{
                        .literal = .{
                            .string = .{ .value = value, .span = span },
                        },
                    };
                },
            };
        },
        .truth => blk: {
            const span = try readSpan(r);
            break :blk .{ .truth = span };
        },
        .none => blk: {
            const span = try readSpan(r);
            break :blk .{ .none = span };
        },
        .calculate => blk: {
            const operation_tag = try readU8(r);
            const operation: Calculation = @enumFromInt(operation_tag);

            const left_val = try readValue(r, allocator);
            errdefer left_val.deinit(allocator);

            const right_val = try readValue(r, allocator);
            errdefer right_val.deinit(allocator);

            const span = try readSpan(r);

            const left_ptr = try allocator.create(Value);
            errdefer allocator.destroy(left_ptr);
            left_ptr.* = left_val;

            const right_ptr = try allocator.create(Value);
            errdefer allocator.destroy(right_ptr);
            right_ptr.* = right_val;

            break :blk .{
                .calculate = .{
                    .left = left_ptr,
                    .right = right_ptr,
                    .operation = operation,
                    .span = span,
                },
            };
        }
    };
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
