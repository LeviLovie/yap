const std = @import("std");
const Op = @import("op.zig").Op;
const codec = @import("codec.zig");

pub const YAPC_MAGIC: []const u8 = "YAPC";
pub const YAPC_VERSION: u32 = 1;

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

    pub fn deinitDeep(self: Ir) void {
        for (self.ops) |*op| {
            op.deinitDeep(self.allocator);
        }
        self.allocator.free(self.ops);
    }

    pub fn serialize(self: Ir, writer: anytype) !void {
        try writer.writeAll(YAPC_MAGIC);
        try codec.writeU32(writer, YAPC_VERSION);

        try codec.writeOps(self.ops, writer);
    }

    pub fn deserialize(allocator: std.mem.Allocator, reader: anytype) !Ir {
        var magic: [4]u8 = undefined;
        try reader.readNoEof(&magic);
        if (!std.mem.eql(u8, magic[0..], YAPC_MAGIC)) {
            return error.InvalidFormat;
        }

        const version = try codec.readU32(reader);
        if (version != YAPC_VERSION) {
            return error.UnsupportedVersion;
        }

        const ops = try codec.readOps(allocator, reader);

        return Ir.init(allocator, ops);
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
