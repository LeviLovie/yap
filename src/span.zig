const codec = @import("codec.zig");

pub const Span = struct {
    start: usize,
    end: usize,
    line: usize,
    column: usize,
};
