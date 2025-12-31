const helpers = @import("helpers.zig");
const std = @import("std");

test "identifier with invalid character fails lexing" {
    const src =
        \\foo$bar be "nope"
    ;

    const out = try helpers.runProgram(std.testing.allocator, src);
    defer std.testing.allocator.free(out);

    try std.testing.expectEqualStrings(
        "lex error at 1:4: invalid character '$'\n",
        out,
    );
}

test "unterminated string after identifier" {
    const src =
        \\file be "oops
    ;

    const out = try helpers.runProgram(std.testing.allocator, src);
    defer std.testing.allocator.free(out);

    try std.testing.expectEqualStrings(
        "lex error at 1:9: invalid character '\"'\n",
        out,
    );
}

test "assignment without be fails parsing" {
    const src =
        \\file "test.txt"
    ;

    const out = try helpers.runProgram(std.testing.allocator, src);
    defer std.testing.allocator.free(out);

    try std.testing.expectEqualStrings(
        "parse error at 1:6\nexpected assign\n",
        out,
    );
}

test "assignment missing value" {
    const src =
        \\file be
    ;

    const out = try helpers.runProgram(std.testing.allocator, src);
    defer std.testing.allocator.free(out);

    try std.testing.expectEqualStrings(
        "parse error at unknown location\nexpected VALUE\n",
        out,
    );
}
