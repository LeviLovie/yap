const Calculation = @import("value.zig").Calculation;
const Identifier = @import("token.zig").Identifier;
const Literal = @import("token.zig").Literal;
const Span = @import("span.zig").Span;
const StringID = @import("ir.zig").StringID;
const Token = @import("token.zig").Token;
const Value = @import("value.zig").Value;
const codec = @import("codec.zig");
const std = @import("std");

// NOTE: Op union tag order is part of the on-disk format.
// Reordering union fields or inserting new ones in the middle
// breaks compatibility and requires bumping YAPC_VERSION.
pub const Op = union(enum) {
    Assign: struct {
        name: StringID,
        value: Value,
        span: Span,
    },
    Print: struct {
        value: Value,
        span: Span,
    },
    Throw: struct {
        event: StringID,
        span: Span,
    },
    If: struct {
        condition: Value,
        then_ops: []Op,
        span: Span,
    },
    IfElse: struct {
        condition: Value,
        then_ops: []Op,
        else_ops: []Op,
        span: Span,
    },
    Mem: struct {
        event: StringID,
        span: Span,
    },

    pub fn deinit(self: Op, allocator: std.mem.Allocator) void {
        switch (self) {
            .Assign => |a| a.value.deinit(allocator),
            .Print => |p| p.value.deinit(allocator),
            .Throw => |_| {},
            .Mem => |_| {},
            .If => |i| {
                i.condition.deinit(allocator);
                for (i.then_ops) |*op| op.deinit(allocator);
                allocator.free(i.then_ops);
            },
            .IfElse => |ie| {
                ie.condition.deinit(allocator);
                for (ie.then_ops) |*op| op.deinit(allocator);
                allocator.free(ie.then_ops);
                for (ie.else_ops) |*op| op.deinit(allocator);
                allocator.free(ie.else_ops);
            },
        }
    }
};

const Assoc = enum { Left, Right };

const OpInfo = struct {
    prec: u8,
    assoc: Assoc,
    calc: Calculation,
};

pub fn infixOp(tag: std.meta.Tag(Token)) ?OpInfo {
    return switch (tag) {
        .b_or  => .{ .prec = 1, .assoc = .Left, .calc = .Or },
        .b_xor => .{ .prec = 2, .assoc = .Left, .calc = .Xor },
        .b_and => .{ .prec = 3, .assoc = .Left, .calc = .And },

        .equals => .{ .prec = 4, .assoc = .Left, .calc = .Equal },
        .less   => .{ .prec = 4, .assoc = .Left, .calc = .Less },
        .more   => .{ .prec = 4, .assoc = .Left, .calc = .More },

        .plus     => .{ .prec = 5, .assoc = .Left,  .calc = .Plus },
        .minus    => .{ .prec = 5, .assoc = .Left,  .calc = .Minus },
        .multiply => .{ .prec = 6, .assoc = .Left,  .calc = .Multiply },
        .divide   => .{ .prec = 6, .assoc = .Left,  .calc = .Divide },
        .power    => .{ .prec = 7, .assoc = .Right, .calc = .Power },

        else => null,
    };
}

pub fn prefixCalc(tag: std.meta.Tag(Token)) ?Calculation {
    return switch (tag) {
        .b_not => .Not,
        else => null,
    };
}
