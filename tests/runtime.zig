const std = @import("std");
const helpers = @import("helpers.zig");

test "runtime error stops execution" {
    const src =
        \\a be "ok"
        \\yap a
        \\yap missing
        \\yap a
    ;

    const out = try helpers.runProgram(std.testing.allocator, src);
    defer std.testing.allocator.free(out);

    try std.testing.expectEqualStrings(
        "ok\nundefined variable: missing\n",
        out,
    );
}
