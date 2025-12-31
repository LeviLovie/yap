const helpers = @import("helpers.zig");
const std = @import("std");

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

test "throw stops execution and prints message" {
    const src =
        \\yap "before"
        \\throw oh no it broke
        \\yap "after"
    ;

    const out = try helpers.runProgram(std.testing.allocator, src);
    defer std.testing.allocator.free(out);

    try std.testing.expectEqualStrings(
        "before\nError: oh no it broke\n",
        out,
    );
}

test "print truth/none literals" {
    const src =
        \\yap yeah
        \\yap nope
    ;

    const out = try helpers.runProgram(std.testing.allocator, src);
    defer std.testing.allocator.free(out);

    try std.testing.expectEqualStrings(
        "yeah\nnope\n",
        out,
    );
}

test "reckons: literal equality and inequality" {
    const src =
        \\yap 3.14 reckons 3.14
        \\yap 3.14 reckons 2.71
        \\yap "a" reckons "a"
        \\yap "a" reckons "b"
    ;

    const out = try helpers.runProgram(std.testing.allocator, src);
    defer std.testing.allocator.free(out);

    try std.testing.expectEqualStrings(
        "yeah\nnope\nyeah\nnope\n",
        out,
    );
}

test "reckons: identifier vs literal" {
    const src =
        \\pi be 3.14
        \\yap pi reckons 3.14
        \\yap pi reckons 2.71
    ;

    const out = try helpers.runProgram(std.testing.allocator, src);
    defer std.testing.allocator.free(out);

    try std.testing.expectEqualStrings(
        "yeah\nnope\n",
        out,
    );
}

test "reckons: identifier vs identifier through transitive resolution" {
    const src =
        \\a be "x"
        \\b be a
        \\c be "x"
        \\yap b reckons c
    ;

    const out = try helpers.runProgram(std.testing.allocator, src);
    defer std.testing.allocator.free(out);

    try std.testing.expectEqualStrings(
        "yeah\n",
        out,
    );
}

test "reckons: type mismatch is false" {
    const src =
        \\yap 1 reckons "1"
        \\yap yeah reckons 1
        \\yap nope reckons "nope"
    ;

    const out = try helpers.runProgram(std.testing.allocator, src);
    defer std.testing.allocator.free(out);

    try std.testing.expectEqualStrings(
        "nope\nnope\nnope\n",
        out,
    );
}

test "reckons: chained comparisons work (left-associative) " {
    const src =
        \\yap 1 reckons 1 reckons yeah
        \\yap 1 reckons 2 reckons yeah
        \\yap 1 reckons 2 reckons nope
    ;

    const out = try helpers.runProgram(std.testing.allocator, src);
    defer std.testing.allocator.free(out);

    try std.testing.expectEqualStrings(
        "yeah\nnope\nyeah\n",
        out,
    );
}
