const Identifier = @import("token.zig").Identifier;
const Literal = @import("token.zig").Literal;
const Span = @import("span.zig").Span;
const codec = @import("codec.zig");
const std = @import("std");

pub const ValueTag = enum(u8) {
    Identifier,
    Number,
    String,
};

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

    pub fn deinitDeep(self: *Value, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .identifier => |*id| {
                allocator.free(id.name);
            },
            .literal => |*lit| switch (lit.*) {
                .number => |_| {},
                .string => |*s| {
                    allocator.free(s.value);
                },
            },
        }
    }
};

pub const OpTag = enum(u8) {
    Assign,
    Yap,
    Throw,
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

    pub fn deinitDeep(self: *Op, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .Assign => |*a| {
                allocator.free(a.name);
                a.value.deinitDeep(allocator);
            },
            .Yap => |*y| {
                y.value.deinitDeep(allocator);
            },
            .Throw => |*t| {
                allocator.free(t.message);
            },
        }
    }
};
