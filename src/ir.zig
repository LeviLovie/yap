const std = @import("std");
const Op = @import("op.zig").Op;

pub const Ir = struct {
    allocator: std.mem.Allocator,
    ops: []Op,

    pub fn init(allocator: std.mem.Allocator, ops: []Op) Ir {
        return Ir{
            .allocator = allocator,
            .ops = ops,
        };
    }

    pub fn deinit(self: Ir) void {
        self.allocator.free(self.ops);
    }
};
