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

            .Print => |p| {
                const v = try self.resolve(writer, strings, p.value);
                try printValue(writer, strings, v);
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

    fn printValue(
        writer: anytype,
        strings: []const []const u8,
        v: Value,
    ) !void {
        switch (v) {
            .literal => |lit| switch (lit) {
                .number => |n| {
                    try writer.print("{d}\n", .{n.value});
                },
                .string => |s| {
                    try writer.print("{s}\n", .{strings[s.value]});
                },
            },

            .truth => |_| try writer.print("yeah\n", .{}),
            .none => |_| try writer.print("nope\n", .{}),

            else => {
                try writer.print("cannot print value\n", .{});
                return error.RuntimeError;
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
            .truth => v,
            .none => v,
            .compare => |c| {
                const left_val = try self.resolve(writer, strings, c.left.*);
                const right_val = try self.resolve(writer, strings, c.right.*);

                if (left_val.equals(right_val)) {
                    return .{ .truth = c.span };
                } else {
                    return .{ .none = c.span };
                }
            },
        };
    }
};
