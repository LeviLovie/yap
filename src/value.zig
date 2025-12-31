const Identifier = @import("token.zig").Identifier;
const Literal = @import("literal.zig").Literal;
const Span = @import("span.zig").Span;
const StringID = @import("ir.zig").StringID;
const std = @import("std");

pub const ValueTag = enum(u8) {
    Identifier,
    Number,
    String,
};

pub const Value = union(enum) {
    identifier: struct {
        name: StringID,
        span: Span,
    },
    literal: union(enum) {
        number: struct {
            value: f64,
            span: Span,
        },
        string: struct {
            value: StringID,
            span: Span,
        },
    },

    pub fn deinit(self: Value, allocator: std.mem.Allocator) void {
        _ = self;
        _ = allocator;
    }

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


