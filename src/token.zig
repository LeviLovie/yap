const Span = @import("span.zig").Span;

pub const Identifier = struct {
    name: []const u8,
    span: Span,
};

pub const Token = union(enum) {
    identifier: Identifier,
    yap: Span,
    be: Span,
    throw: struct {
        message: []const u8,
        span: Span,
    },
};
