const Span = @import("span.zig").Span;
const StringID = @import("ir.zig").StringID;
const std = @import("std");

pub const Literal = union(enum) {
    number: struct {
        value: f64,
        span: Span
    },
    string: struct {
        value: []const u8,
        span: Span
    },

    pub fn deinit(self: Literal, allocator: std.mem.Allocator) void {
        switch (self) {
            .string => |s| allocator.free(s.value),
            else => {},
        }
    }

    pub fn span(self: Literal) Span {
        return switch (self) {
            .number => |n| n.span,
            .string => |s| s.span,
        };
    }
};
