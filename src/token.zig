const Literal = @import("literal.zig").Literal;
const Span = @import("span.zig").Span;
const StringID = @import("ir.zig").StringID;
const std = @import("std");

pub const Identifier = struct {
    name: []const u8,
    span: Span,
};

pub const Token = union(enum) {
    identifier: Identifier,
    literal: Literal,
    assign: Span,
    equals: Span,
    none: Span,
    print: Span,
    throw: struct {
        message: []const u8,
        span: Span,
    },
    truth: Span,
    condition: Span,
    then: Span,
    ifelse: Span,
    end: Span,

    b_not: Span,
    b_and: Span,
    b_or: Span,
    b_xor: Span,

    plus: Span,
    minus: Span,
    multiply: Span,
    divide: Span,
    power: Span,

    less: Span,
    more: Span,

    pub fn deinit(self: Token, allocator: std.mem.Allocator) void {
        switch (self) {
            .literal => |lit| lit.deinit(allocator),
            else => {},
        }
    }

    pub fn span(self: Token) Span {
        return switch (self) {
            .identifier => |id| id.span,
            .literal => |lit| lit.span(),

            .assign, .equals, .none, .print, .truth,
            .condition, .then, .ifelse, .end,
            .b_not, .b_and, .b_or, .b_xor,
            .plus, .minus, .multiply, .divide, .power,
            .less, .more,
            => |sp| sp,

            .throw => |t| t.span,
        };
    }
};
