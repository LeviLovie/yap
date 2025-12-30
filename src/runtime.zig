const std = @import("std");
const Op = @import("op.zig").Op;
const Token = @import("token.zig").Token;
const Value = @import("op.zig").Value;
const Literal = @import("token.zig").Literal;

pub const RuntimeError = error{
    RuntimeError,
    SyntaxError,
};

pub const Runtime = struct {
    allocator: std.mem.Allocator,
    vars: std.StringHashMap(Value),

    pub fn init(
        allocator: std.mem.Allocator,
    ) Runtime {
        return Runtime{
            .allocator = allocator,
            .vars = std.StringHashMap(Value).init(allocator),
        };
    }

    pub fn deinit(self: *Runtime) void {
        self.vars.deinit();
    }

    pub fn exec(self: *Runtime, writer: anytype, ops: []const Op) !void {
        for (ops) |op| switch (op) {
            .Assign => |a| {
                try self.vars.put(a.name, a.value);
            },

            .Yap => |y| {
                const lit = try self.resolve(writer, y.value);
                printLiteral(writer, lit);
            },

            .Throw => |t| {
                writer.print("Error: {s}\n", .{t.message}) catch {};
                return error.RuntimeError;
            },
        };
    }

    fn evalValue(self: *Runtime, value: Value) ![]const u8 {
        return switch (value) {
            .literal => |lit| switch (lit) {
                .string => |s| s.value,
                .number => |n| blk: {
                    break :blk try std.fmt.allocPrint(self.allocator, "{d}", .{n.value});
                },
            },
            .identifier => |id| {
                if (self.vars.get(id.name)) |val| return val;
                std.debug.print("undefined variable: {s}\n", .{id.name});
                return error.RuntimeError;
            },
        };
    }

    fn printLiteral(writer: anytype, lit: Literal) void {
        switch (lit) {
            .number => |n| {
                writer.print("{d}\n", .{n.value}) catch {};
            },
            .string => |s| {
                writer.print("{s}\n", .{s.value}) catch {};
            },
        }
    }

    fn resolve(self: *Runtime, writer: anytype, v: Value) !Literal {
        return switch (v) {
            .literal => |lit| lit,

            .identifier => |id| blk: {
                const stored = self.vars.get(id.name) orelse {
                    writer.print("undefined variable: {s}\n", .{id.name}) catch {};
                    return error.RuntimeError;
                };

                break :blk try self.resolve(writer, stored);
            },
        };
    }
};
