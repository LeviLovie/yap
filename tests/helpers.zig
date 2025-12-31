const std = @import("std");
const yap = @import("yap");

pub fn runProgram(
    allocator: std.mem.Allocator,
    source: []const u8,
) ![]u8 {
    const result = yap.compile(allocator, source);

    switch (result) {
        .Err => |err| {
            return try yap.formatCompileError(allocator, err);
        },
        .Ok => |ir| {
            defer ir.deinit();

            // Run the IR
            var out_ir = std.ArrayList(u8).init(allocator);
            defer out_ir.deinit();
            try yap.runWithWriter(allocator, out_ir.writer(), ir);

            // Serialize -> Deserialize -> Run IR
            var buffer = std.ArrayList(u8).init(allocator);
            defer buffer.deinit();
            try ir.serialize(buffer.writer());

            var stream = std.io.fixedBufferStream(buffer.items);
            var deserialized_ir = try yap.Ir.deserialize(allocator, stream.reader());
            defer deserialized_ir.deinit();

            var out_deser = std.ArrayList(u8).init(allocator);
            defer out_deser.deinit();
            try yap.runWithWriter(allocator, out_deser.writer(), deserialized_ir);

            // Compare the two
            try std.testing.expectEqualStrings(out_ir.items, out_deser.items);
            return out_ir.toOwnedSlice();
        },
    }
}

pub fn hasString(strings: []const []const u8, needle: []const u8) bool {
    for (strings) |s| {
        if (std.mem.eql(u8, s, needle)) return true;
    }
    return false;
}
