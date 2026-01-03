const std = @import("std");
const Op = @import("op.zig").Op;
const codec = @import("codec.zig");

pub const StringID = usize;

pub const Ir = struct {
    allocator: std.mem.Allocator,
    strings: []const []const u8,
    ops: []Op,

    pub fn init(
        allocator: std.mem.Allocator,
        strings: []const []const u8,
        ops: []Op,
    ) Ir {
        return .{
            .allocator = allocator,
            .strings = strings,
            .ops = ops,
        };
    }

    pub fn deinit(self: Ir) void {
        for (self.ops) |op| op.deinit(self.allocator);
        self.allocator.free(self.ops);

        for (self.strings) |s| self.allocator.free(s);
        self.allocator.free(self.strings);
    }

    pub fn serialize(self: Ir, writer: anytype) !void {
        return codec.writeIr(writer, self);
    }

    pub fn deserialize(
        reader: anytype,
        allocator: std.mem.Allocator,
    ) !Ir {
        return codec.readIr(reader, allocator);
    }
};
