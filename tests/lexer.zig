const Lexer = @import("yap").Lexer;
const Token = @import("yap").Token;
const std = @import("std");

fn tag(tok: Token) std.meta.Tag(Token) {
    return std.meta.activeTag(tok);
}

test "lexes identifiers, numbers, strings, keywords, equals" {
    const src =
        \\_a1 be 3.14
        \\yap _a1
        \\yap "hi"
        \\yap yeah
        \\yap nope
        \\yap _a1 reckons 3.14
    ;

    var lx = Lexer.init(std.testing.allocator, src);
    var toks = try lx.lex();
    defer toks.deinit();

    try std.testing.expectEqual(@as(usize, 15), toks.items.len);

    try std.testing.expectEqual(tag(toks.items[0]), .identifier);
    try std.testing.expectEqual(tag(toks.items[1]), .assign);
    try std.testing.expectEqual(tag(toks.items[2]), .literal);

    try std.testing.expectEqual(tag(toks.items[3]), .print);
    try std.testing.expectEqual(tag(toks.items[4]), .identifier);

    try std.testing.expectEqual(tag(toks.items[5]), .print);
    try std.testing.expectEqual(tag(toks.items[6]), .literal);

    try std.testing.expectEqual(tag(toks.items[7]), .print);
    try std.testing.expectEqual(tag(toks.items[8]), .truth);

    try std.testing.expectEqual(tag(toks.items[9]), .print);
    try std.testing.expectEqual(tag(toks.items[10]), .none);

    try std.testing.expectEqual(tag(toks.items[11]), .print);
    try std.testing.expectEqual(tag(toks.items[12]), .identifier);
    try std.testing.expectEqual(tag(toks.items[13]), .equals);
    try std.testing.expectEqual(tag(toks.items[14]), .literal);
}

test "keyword boundaries (beep is identifier, not assign)" {
    const src = "beep be 1";
    var lx = Lexer.init(std.testing.allocator, src);
    var toks = try lx.lex();
    defer toks.deinit();

    try std.testing.expectEqual(@as(usize, 3), toks.items.len);
    try std.testing.expectEqual(std.meta.activeTag(toks.items[0]), .identifier);
    try std.testing.expectEqual(std.meta.activeTag(toks.items[1]), .assign);
    try std.testing.expectEqual(std.meta.activeTag(toks.items[2]), .literal);
}

test "invalid character reports correct position and char" {
    const src = "foo$bar";
    var lx = Lexer.init(std.testing.allocator, src);

    _ = lx.lex() catch |err| {
        try std.testing.expectEqual(error.InvalidCharacter, err);
        try std.testing.expect(lx.last_error_span != null);
        try std.testing.expectEqual(@as(u8, '$'), lx.last_error_char.?);

        const sp = lx.last_error_span.?;
        try std.testing.expectEqual(@as(usize, 1), sp.line);
        try std.testing.expectEqual(@as(usize, 4), sp.column);
        return;
    };

    return error.TestExpectedError;
}

test "unterminated string reports UnterminatedString" {
    const src = "\"oops";
    var lx = Lexer.init(std.testing.allocator, src);

    _ = lx.lex() catch |err| {
        try std.testing.expectEqual(error.UnterminatedString, err);
        try std.testing.expect(lx.last_error_span != null);
        const sp = lx.last_error_span.?;
        try std.testing.expectEqual(@as(usize, 1), sp.line);
        try std.testing.expectEqual(@as(usize, 1), sp.column);
        return;
    };

    return error.TestExpectedError;
}

test "number with second dot fails at the dot" {
    const src = "1.2.3";
    var lx = Lexer.init(std.testing.allocator, src);

    _ = lx.lex() catch |err| {
        try std.testing.expectEqual(error.InvalidCharacter, err);
        try std.testing.expectEqual(@as(u8, '.'), lx.last_error_char.?);
        const sp = lx.last_error_span.?;
        try std.testing.expectEqual(@as(usize, 1), sp.line);
        try std.testing.expectEqual(@as(usize, 4), sp.column);
        return;
    };

    return error.TestExpectedError;
}

test "throw captures rest of line (including spaces) and stops at newline" {
    const src =
        \\throw hello world 123
        \\yap "x"
    ;

    var lx = Lexer.init(std.testing.allocator, src);
    var toks = try lx.lex();
    defer toks.deinit();

    try std.testing.expectEqual(@as(usize, 3), toks.items.len);
    try std.testing.expectEqual(std.meta.activeTag(toks.items[0]), .throw);
    try std.testing.expectEqual(std.meta.activeTag(toks.items[1]), .print);
    try std.testing.expectEqual(std.meta.activeTag(toks.items[2]), .literal);

    const t = toks.items[0].throw;
    try std.testing.expect(std.mem.eql(u8, t.message, "hello world 123"));
}
