const std = @import("std");
const Op = @import("op.zig").Op;
const codec = @import("codec.zig");

pub const YAPC_MAGIC: []const u8 = "YAPC";
pub const YAPC_VERSION: u32 = 1;

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
        try writer.writeAll(YAPC_MAGIC);
        try codec.writeU32(writer, YAPC_VERSION);

        try codec.writeStringTable(self.strings, writer);
        try codec.writeOps(self.ops, writer);
    }

    pub fn deserialize(allocator: std.mem.Allocator, reader: anytype) !Ir {
        var magic: [4]u8 = undefined;
        try reader.readNoEof(&magic);
        if (!std.mem.eql(u8, magic[0..], YAPC_MAGIC)) return error.InvalidFormat;

        const version = try codec.readU32(reader);
        if (version != YAPC_VERSION) return error.UnsupportedVersion;

        const strings = try codec.readStringTable(allocator, reader);
        errdefer {
            for (strings) |s| allocator.free(s);
            allocator.free(strings);
        }

        const ops = try codec.readOps(allocator, reader);
        errdefer {
            for (ops) |op| op.deinit(allocator);
            allocator.free(ops);
        }

        return Ir.init(allocator, strings, ops);
    }
};

fn isYapcFile(file: std.fs.File) !bool {
    var magic: [4]u8 = undefined;
    const pos = try file.getPos();
    defer file.seekTo(pos) catch {};

    const n = try file.read(&magic);
    if (n < 4) return false;

    return std.mem.eql(u8, magic[0..], YAPC_MAGIC);
}
