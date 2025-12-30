const Span = @import("span.zig").Span;

pub const Identifier = struct {
    name: []const u8,
    span: Span,
};

pub const Literal = union(enum) {
    number: struct {
        value: f64,
        span: Span,
    },
    string: struct {
        value: []const u8,
        span: Span,
    },
};

pub const Token = union(enum) {
    identifier: Identifier,
    literal: Literal,

    yap: Span,
    be: Span,
    throw: struct {
        message: []const u8,
        span: Span,
    },
};
