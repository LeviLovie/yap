const std = @import("std");
const yap = @import("yap");

pub fn runProgram(
    allocator: std.mem.Allocator,
    source: []const u8,
) ![]u8 {
    var out = std.ArrayList(u8).init(allocator);
    errdefer out.deinit();
    const writer = out.writer();

    const result = yap.compile(allocator, source);

    switch (result) {
        .Ok => |ir| {
            defer ir.deinit();
            try yap.runWithWriter(allocator, writer, ir);
        },

        .Err => |err| {
            const msg = try yap.formatCompileError(allocator, err);
            defer allocator.free(msg);
            try writer.writeAll(msg);
        },
    }

    return out.toOwnedSlice();
}
