const Identifier = @import("token.zig").Identifier;
const Literal = @import("token.zig").Literal;
const Span = @import("span.zig").Span;
const StringID = @import("ir.zig").StringID;
const Value = @import("value.zig").Value;
const codec = @import("codec.zig");
const std = @import("std");

pub const OpTag = enum(u8) {
    Assign,
    Print,
    Throw,
    If,
    IfElse,
};

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

    pub fn deinit(self: Op, allocator: std.mem.Allocator) void {
        switch (self) {
            .Assign => |a| a.value.deinit(allocator),
            .Print => |p| p.value.deinit(allocator),
            .Throw => |_| {},
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
