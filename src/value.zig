const Identifier = @import("token.zig").Identifier;
const Literal = @import("literal.zig").Literal;
const Span = @import("span.zig").Span;
const StringID = @import("ir.zig").StringID;
const std = @import("std");

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
    truth: Span,
    none: Span,

    compare: struct {
        left: *Value,
        right: *Value,
        span: Span,
    },

    pub fn deinit(self: Value, allocator: std.mem.Allocator) void {
        switch (self) {
            .compare => |c| {
                c.left.deinit(allocator);
                allocator.destroy(c.left);

                c.right.deinit(allocator);
                allocator.destroy(c.right);
            },
            else => {},
        }
    }

    pub fn span(self: Value) Span {
        return switch (self) {
            .identifier => |id| id.span,
            .literal => |lit| switch (lit) {
                .number => |n| n.span,
                .string => |s| s.span,
            },
            .truth => |sp| sp,
            .none => |sp| sp,
            .compare => |c| c.span,
        };
    }

    pub fn equals(self: Value, other: Value) bool {
        return switch (self) {
            .identifier => |id1| switch (other) {
                .identifier => |id2| id1.name == id2.name,
                else => false,
            },
            .literal => |lit1| switch (other) {
                .literal => |lit2| switch (lit1) {
                    .number => |n1| switch (lit2) {
                        .number => |n2| n1.value == n2.value,
                        else => false,
                    },
                    .string => |s1| switch (lit2) {
                        .string => |s2| s1.value == s2.value,
                        else => false,
                    },
                },
                else => false,
            },
            .truth => switch (other) {
                .truth => true,
                else => false,
            },
            .none => switch (other) {
                .none => true,
                else => false,
            },
            .compare => false,
        };
    }
};
