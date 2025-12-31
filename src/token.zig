const Span = @import("span.zig").Span;
const Literal = @import("literal.zig").Literal;
const StringID = @import("ir.zig").StringID;

pub const Identifier = struct {
    name: []const u8,
    span: Span,
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
