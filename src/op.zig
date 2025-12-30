const Identifier = @import("token.zig").Identifier;
const Literal = @import("token.zig").Literal;
const Span = @import("span.zig").Span;

pub const Value = union(enum) {
    identifier: Identifier,
    literal: Literal,

    pub fn span(self: Value) Span {
        return switch (self) {
            .identifier => |id| id.span,
            .literal => |lit| switch (lit) {
                .number => |n| n.span,
                .string => |s| s.span,
            },
        };
    }
};

pub const Op = union(enum) {
    Assign: struct {
        name: []const u8,
        value: Value,
        span: Span,
    },
    Yap: struct {
        value: Value,
        span: Span,
    },
    Throw: struct {
        message: []const u8,
        span: Span,
    },
};
