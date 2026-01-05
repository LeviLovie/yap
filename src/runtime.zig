const Literal = @import("literal.zig").Literal;
const Op = @import("op.zig").Op;
const Span = @import("span.zig").Span;
const StringID = @import("ir.zig").StringID;
const Token = @import("token.zig").Token;
const Value = @import("value.zig").Value;
const std = @import("std");

pub const RuntimeError =
    error{ RuntimeError, SyntaxError } || std.mem.Allocator.Error;

const Frame = struct {
    ops: []const Op,
    pc: usize,
};

pub const Runtime = struct {
    allocator: std.mem.Allocator,
    frames: std.ArrayList(Frame),
    vars: std.StringHashMap(Value),
    arrays: std.StringHashMap(std.ArrayList(Value)),
    upcoming_events: std.ArrayList([]const u8),
    dyn_strings: std.ArrayList([]const u8),
    dyn_string_ids: std.StringHashMap(StringID),

    pub fn init(
        allocator: std.mem.Allocator,
    ) Runtime {
        return Runtime{
            .allocator = allocator,
            .frames = std.ArrayList(Frame).init(allocator),
            .vars = std.StringHashMap(Value).init(allocator),
            .arrays = std.StringHashMap(std.ArrayList(Value)).init(allocator),
            .upcoming_events = std.ArrayList([]const u8).init(allocator),
            .dyn_strings = std.ArrayList([]const u8).init(allocator),
            .dyn_string_ids = std.StringHashMap(StringID).init(allocator),
        };
    }

    pub fn deinit(self: *Runtime) void {
        self.frames.deinit();
        self.upcoming_events.deinit();

        var vit = self.vars.iterator();
        while (vit.next()) |entry| {
            entry.value_ptr.deinit(self.allocator);
        }
        self.vars.deinit();

        var it = self.arrays.iterator();
        while (it.next()) |entry| {
            for (entry.value_ptr.items) |*v| {
                v.deinit(self.allocator);
            }
            entry.value_ptr.deinit();
        }
        self.arrays.deinit();

        for (self.dyn_strings.items) |s| self.allocator.free(s);
        self.dyn_strings.deinit();
        self.dyn_string_ids.deinit();
    }

    pub fn loadStrings(
        self: *Runtime,
        strings: []const []const u8,
    ) !void {
        for (strings) |s| {
            _ = try self.loadString(s);
        }
    }

    pub fn run(
        self: *Runtime,
        writer: anytype,
        root_ops: []const Op,
    ) !void {
        try self.upcoming_events.append("entry");

        while (self.upcoming_events.items.len > 0) {
            const event = self.upcoming_events.orderedRemove(0);
            const event_id = try self.loadString(event);
            const span = Span{ .start = 0, .end = 0, .line = 0, .column = 0 };
            try self.putVar("event", .{
                .literal = .{
                    .string = .{ .value = event_id, .span = span },
                },
            });

            self.frames.clearRetainingCapacity();
            try self.frames.append(.{ .ops = root_ops, .pc = 0 });

            while (self.frames.items.len > 0) {
                try self.exec(writer);
            }
        }
    }

    fn exec(
        self: *Runtime,
        writer: anytype,
    ) !void {
        var frame = &self.frames.items[self.frames.items.len - 1];

        if (frame.pc >= frame.ops.len) {
            _ = self.frames.pop();
            return;
        }

        const op = frame.ops[frame.pc];
        frame.pc += 1;

        switch (op) {
            .Assign => |a| {
                const name = self.getString(a.name);

                const rhs = try self.resolve(writer, self.dyn_strings.items, a.value);
                try self.putVar(name, rhs);
            },

            .Print => |p| {
                const v = try self.resolve(writer, self.dyn_strings.items, p.value);
                try self.printValue(writer, v);
            },

            .Throw => |t| {
                const ev = self.getString(t.event);
                try self.upcoming_events.append(ev);

                self.frames.clearRetainingCapacity();
                return;
            },

            .Mem => |m| {
                try self.execMem(writer, self.dyn_strings.items);

                const ev = self.getString(m.event);
                try self.upcoming_events.append(ev);

                self.frames.clearRetainingCapacity();
                return;
            },

            .If => |i| {
                if (try self.asBool(writer, self.dyn_strings.items, i.condition)) {
                    try self.frames.append(.{
                        .ops = i.then_ops,
                        .pc = 0,
                    });
                }
            },

            .IfElse => |ie| {
                const ops = if (try self.asBool(writer, self.dyn_strings.items, ie.condition))
                    ie.then_ops
                else
                    ie.else_ops;

                try self.frames.append(.{
                    .ops = ops,
                    .pc = 0,
                });
            },
        }
    }

    fn execMem(self: *Runtime, writer: anytype, strings: []const []const u8) RuntimeError!void {
        const action = try self.getVarString(writer, strings, "action");
        const ptr_name = try self.getVarString(writer, strings, "ptr");
        const index = try self.getVarIndex(writer, strings, "offset");

        var arr_ptr = self.arrays.getPtr(ptr_name);
        if (arr_ptr == null) {
            const new_arr = std.ArrayList(Value).init(self.allocator);
            try self.arrays.put(ptr_name, new_arr);
            arr_ptr = self.arrays.getPtr(ptr_name);
        }
        var arr = arr_ptr.?;

        if (std.mem.eql(u8, action, "set")) {
            const v0 = try self.getVar(writer, "value");
            const resolved = try self.resolve(writer, strings, v0);
            const cloned = try self.cloneValue(resolved);

            while (arr.items.len <= index) {
                try arr.append(noneValue());
            }

            arr.items[index].deinit(self.allocator);
            arr.items[index] = cloned;
            return;
        }

        if (std.mem.eql(u8, action, "get")) {
            const out: Value = if (index < arr.items.len) arr.items[index] else noneValue();

            try self.putVar("value", out);
            return;
        }

        writer.print("unknown mem action: {s}\n", .{action}) catch {};
        return error.RuntimeError;
    }

    fn loadString(
        self: *Runtime,
        s: []const u8,
    ) !StringID {
        if (self.dyn_string_ids.get(s)) |id| return id;

        const owned = try self.allocator.dupe(u8, s);
        try self.dyn_strings.append(owned);

        const id: StringID = @intCast(self.dyn_strings.items.len - 1);
        try self.dyn_string_ids.put(owned, id);
        return id;
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
        self: *Runtime,
        writer: anytype,
        v: Value,
    ) !void {
        switch (v) {
            .literal => |lit| switch (lit) {
                .number => |n| {
                    try writer.print("{d}", .{n.value});
                },
                .string => |s| {
                    try writer.print("{s}", .{self.getString(s.value)});
                },
            },

            .truth => |_| try writer.print("yeah", .{}),
            .none => |_| try writer.print("nope", .{}),

            else => {
                try writer.print("{{error printing value}}", .{});
                return error.RuntimeError;
            },
        }
    }

    fn asBool(
        self: *Runtime,
        writer: anytype,
        strings: []const []const u8,
        v: Value,
    ) !bool {
        const resolved = try self.resolve(writer, strings, v);
        return switch (resolved) {
            .truth => true,
            .none => false,
            else => {
                writer.print("expected boolean value\n", .{}) catch {};
                return error.RuntimeError;
            },
        };
    }

    fn getString(self: *Runtime, id: StringID) []const u8 {
        return self.dyn_strings.items[@intCast(id)];
    }

    fn resolve(self: *Runtime, writer: anytype, strings: []const []const u8, v: Value) RuntimeError!Value {
        return switch (v) {
            .literal => v,
            .truth => v,
            .none => v,

            .identifier => |id| {
                const name = strings[id.name];
                const stored = self.vars.get(name) orelse {
                    writer.print("undefined variable: {s}\n", .{name}) catch {};
                    return error.RuntimeError;
                };
                return try self.resolve(writer, strings, stored);
            },

            .calculate => |c| {
                const op = c.operation;

                if (op == .Not) {
                    const b = try self.expectBool(writer, strings, c.left.*);
                    return if (b) .{ .none = c.span } else .{ .truth = c.span };
                }

                if (op == .And or op == .Or or op == .Xor) {
                    const a = try self.expectBool(writer, strings, c.left.*);
                    const b = try self.expectBool(writer, strings, c.right.*);
                    const out = switch (op) {
                        .And => a and b,
                        .Or => a or b,
                        .Xor => (a != b),
                        else => unreachable,
                    };
                    return if (out) .{ .truth = c.span } else .{ .none = c.span };
                }

                if (op == .Plus or op == .Minus or op == .Multiply or op == .Divide or op == .Power) {
                    const a = try self.expectNumber(writer, strings, c.left.*);
                    const b = try self.expectNumber(writer, strings, c.right.*);

                    const res: f64 = switch (op) {
                        .Plus => a + b,
                        .Minus => a - b,
                        .Multiply => a * b,
                        .Divide => a / b,
                        .Power => std.math.pow(f64, a, b),
                        else => unreachable,
                    };

                    return .{ .literal = .{ .number = .{ .value = res, .span = c.span } } };
                }

                if (op == .Equal) {
                    const left_val = try self.resolve(writer, strings, c.left.*);
                    const right_val = try self.resolve(writer, strings, c.right.*);
                    return if (left_val.equals(right_val))
                        .{ .truth = c.span }
                    else
                        .{ .none = c.span };
                }

                if (op == .Less or op == .More) {
                    const a = try self.expectNumber(writer, strings, c.left.*);
                    const b = try self.expectNumber(writer, strings, c.right.*);
                    const out = if (op == .Less) (a < b) else (a > b);
                    return if (out) .{ .truth = c.span } else .{ .none = c.span };
                }

                writer.print("unknown calculation op\n", .{}) catch {};
                return error.RuntimeError;
            },
        };
    }

    fn expectNumber(self: *Runtime, writer: anytype, strings: []const []const u8, v: Value) !f64 {
        const r = try self.resolve(writer, strings, v);
        return switch (r) {
            .literal => |lit| switch (lit) {
                .number => |n| n.value,
                else => {
                    writer.print("expected number\n", .{}) catch {};
                    return error.RuntimeError;
                },
            },
            else => {
                writer.print("expected number\n", .{}) catch {};
                return error.RuntimeError;
            },
        };
    }

    fn expectBool(self: *Runtime, writer: anytype, strings: []const []const u8, v: Value) !bool {
        const r = try self.resolve(writer, strings, v);
        return switch (r) {
            .truth => true,
            .none => false,
            else => {
                writer.print("expected boolean\n", .{}) catch {};
                return error.RuntimeError;
            },
        };
    }

    fn putVar(self: *Runtime, name: []const u8, v: Value) !void {
        if (self.vars.getPtr(name)) |ptr| {
            ptr.deinit(self.allocator);
            ptr.* = v;
        } else {
            try self.vars.put(name, v);
        }
    }

    fn getVar(self: *Runtime, writer: anytype, name: []const u8) RuntimeError!Value {
        return self.vars.get(name) orelse {
            writer.print("missing var: {s}\n", .{name}) catch {};
            return error.RuntimeError;
        };
    }

    fn getVarString(self: *Runtime, writer: anytype, strings: []const []const u8, name: []const u8) RuntimeError![]const u8 {
        const v0 = try self.getVar(writer, name);
        const v = try self.resolve(writer, strings, v0);

        return switch (v) {
            .literal => |lit| switch (lit) {
                .string => |s| self.getString(s.value),
                else => {
                    writer.print("expected string in {s}\n", .{name}) catch {};
                    return error.RuntimeError;
                },
            },
            else => {
                writer.print("expected string in {s}\n", .{name}) catch {};
                return error.RuntimeError;
            },
        };
    }

    fn getVarIndex(self: *Runtime, writer: anytype, strings: []const []const u8, name: []const u8) RuntimeError!usize {
        const v0 = try self.getVar(writer, name);
        const n = try self.expectNumber(writer, strings, v0);

        if (n < 0) {
            writer.print("negative index in {s}\n", .{name}) catch {};
            return error.RuntimeError;
        }

        if (@floor(n) != n) {
            writer.print("non-integer index in {s}\n", .{name}) catch {};
            return error.RuntimeError;
        }

        return @intFromFloat(n);
    }

    fn noneValue() Value {
        const sp = Span{ .start = 0, .end = 0, .line = 0, .column = 0 };
        return .{ .none = sp };
    }

    fn cloneValue(self: *Runtime, v: Value) !Value {
        return switch (v) {
            .literal => v,
            .truth => v,
            .none => v,

            .calculate => |c| .{
                .calculate = .{
                    .left = try self.boxValue(try self.cloneValue(c.left.*)),
                    .right = try self.boxValue(try self.cloneValue(c.right.*)),
                    .operation = c.operation,
                    .span = c.span,
                },
            },

            else => unreachable,
        };
    }

    fn boxValue(self: *Runtime, v: Value) !*Value {
        const p = try self.allocator.create(Value);
        p.* = v;
        return p;
    }
};
