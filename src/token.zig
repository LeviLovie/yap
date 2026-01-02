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
    not: Span,

    pub fn span(self: Token) Span {
        return switch (self) {
            .identifier => |id| id.span,
            .literal => |lit| lit.span(),
            .assign, .equals, .print, .truth, .none => |sp| sp,
            .throw => |t| t.span,
            .condition => |sp| sp,
            .then => |sp| sp,
            .ifelse => |sp| sp,
            .end => |sp| sp,
            .not => |sp| sp,
        };
    }
};
