const std = @import("std");
const Token = @import("token.zig").Token;
const Op = @import("op.zig").Op;

pub const RuntimeError = error{
    RuntimeError,
    SyntaxError,
};

pub const Runtime = struct {
    allocator: std.mem.Allocator,
    vars: std.StringHashMap([]const u8),

    pub fn init(allocator: std.mem.Allocator) Runtime {
        return Runtime{
            .allocator = allocator,
            .vars = std.StringHashMap([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *Runtime) void {
        self.vars.deinit();
    }

    pub fn exec(self: *Runtime, instrs: []const Op) !void {
        for (instrs) |inst| {
            switch (inst) {
                .Assign => |a| {
                    try self.vars.put(a.name, a.value.name);
                },

                .Yap => |y| {
                    if (self.vars.get(y.value.name)) |val| {
                        std.debug.print("{s}\n", .{val});
                    } else {
                        std.debug.print("undefined variable: {s}\n", .{y.value.name});
                        return error.RuntimeError;
                    }
                },

                .Throw => |t| {
                    std.debug.print("Error: {s}\n", .{t.message});
                    return error.RuntimeError;
                }
            }
        }
    }
};
