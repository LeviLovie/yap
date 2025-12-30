const std = @import("std");
const helpers = @import("helpers.zig");

test "identifier resolves transitively" {
    const src =
        \\a be "hello"
        \\b be a
        \\c be b
        \\yap c
    ;

    const out = try helpers.runProgram(std.testing.allocator, src);
    defer std.testing.allocator.free(out);

    try std.testing.expectEqualStrings(
        "hello\n",
        out,
    );
}

test "identifier resolves to string literal" {
    const src =
        \\file be "test.txt"
        \\yap file
    ;

    const out = try helpers.runProgram(std.testing.allocator, src);
    defer std.testing.allocator.free(out);

    try std.testing.expectEqualStrings(
        "test.txt\n",
        out,
    );
}

test "identifier resolves to number literal" {
    const src =
        \\pi be 3.14
        \\yap pi
    ;

    const out = try helpers.runProgram(std.testing.allocator, src);
    defer std.testing.allocator.free(out);

    try std.testing.expectEqualStrings(
        "3.14\n",
        out,
    );
}

test "undefined identifier produces runtime error" {
    const src =
        \\yap missing
    ;

    const out = try helpers.runProgram(std.testing.allocator, src);
    defer std.testing.allocator.free(out);

    try std.testing.expectEqualStrings(
        "undefined variable: missing\n",
        out,
    );
}

test "undefined identifier through chain" {
    const src =
        \\a be b
        \\yap a
    ;

    const out = try helpers.runProgram(std.testing.allocator, src);
    defer std.testing.allocator.free(out);

    try std.testing.expectEqualStrings(
        "undefined variable: b\n",
        out,
    );
}

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
        "parse error at token 1\nexpected be\n",
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
        "parse error at token 2\nexpected VALUE or IDENTIFIER\n",
        out,
    );
}
