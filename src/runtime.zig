const std = @import("std");
const Op = @import("op.zig").Op;
const Token = @import("token.zig").Token;
const Value = @import("value.zig").Value;
const Literal = @import("literal.zig").Literal;

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

    pub fn exec(
        self: *Runtime,
        writer: anytype,
        strings: []const []const u8,
        ops: []const Op,
    ) !void {
        for (ops) |op| switch (op) {
            .Assign => |a| {
                const name = strings[a.name];
                try self.vars.put(name, a.value);
            },

            .Yap => |y| {
                const v2 = try self.resolve(writer, strings, y.value);
                switch (v2) {
                    .literal => |lit| switch (lit) {
                        .number => |n| try writer.print("{d}\n", .{n.value}),
                        .string => |s| try writer.print("{s}\n", .{strings[s.value]}),
                    },
                    else => unreachable,
                }
            },

            .Throw => |t| {
                const msg = strings[t.message];
                writer.print("Error: {s}\n", .{msg}) catch {};
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

    fn resolve(self: *Runtime, writer: anytype, strings: []const []const u8, v: Value) !Value {
        return switch (v) {
            .literal => v,
            .identifier => |id| {
                const name = strings[id.name];
                const stored = self.vars.get(name) orelse {
                    writer.print("undefined variable: {s}\n", .{name}) catch {};
                    return error.RuntimeError;
                };
                return try self.resolve(writer, strings, stored);
            },
        };
    }
};
