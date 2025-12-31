const Identifier = @import("token.zig").Identifier;
const Literal = @import("token.zig").Literal;
const Span = @import("span.zig").Span;
const StringID = @import("ir.zig").StringID;
const Value = @import("value.zig").Value;
const codec = @import("codec.zig");
const std = @import("std");

pub const OpTag = enum(u8) {
    Assign,
    Yap,
    Throw,
};

pub const Op = union(enum) {
    Assign: struct {
        name: StringID,
        value: Value,
        span: Span,
    },
    Yap: struct {
        value: Value,
        span: Span,
    },
    Throw: struct {
        message: StringID,
        span: Span,
    },

    pub fn deinit(self: Op, allocator: std.mem.Allocator) void {
        switch (self) {
            .Assign => |a| {
                a.value.deinit(allocator);
            },
            .Yap => |y| y.value.deinit(allocator),
            .Throw => |_| {},
        }
    }
};
