const Span = @import("span.zig").Span;
const StringID = @import("ir.zig").StringID;

pub const Literal = union(enum) {
    number: struct {
        value: f64,
        span: Span
    },
    string: struct {
        value: []const u8,
        span: Span
    },
};
