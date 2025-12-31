const Lexer = @import("yap").Lexer;
const Op = @import("yap").Op;
const Parser = @import("yap").Parser;
const Value = @import("yap").Value;
const helpers = @import("helpers.zig");
const std = @import("std");

fn deinitParse(alloc: std.mem.Allocator, ops: []Op, strings: []const []const u8) void {
    for (ops) |op| op.deinit(alloc);
    alloc.free(ops);

    for (strings) |s| alloc.free(s);
    alloc.free(strings);
}

test "assign, print, throw produce correct ops" {
    const src =
        \\a be "ok"
        \\yap a
        \\throw boom
    ;

    var lx = Lexer.init(std.testing.allocator, src);
    var toks = try lx.lex();
    defer toks.deinit();

    var p = Parser.init(std.testing.allocator, toks.items);
    const res = try p.parse();
    defer deinitParse(std.testing.allocator, res.ops, res.strings);

    try std.testing.expectEqual(@as(usize, 3), res.ops.len);
    try std.testing.expectEqual(std.meta.activeTag(res.ops[0]), .Assign);
    try std.testing.expectEqual(std.meta.activeTag(res.ops[1]), .Print);
    try std.testing.expectEqual(std.meta.activeTag(res.ops[2]), .Throw);

    try std.testing.expectEqual(@as(usize, 3), res.strings.len);
    try std.testing.expect(helpers.hasString(res.strings, "a"));
    try std.testing.expect(helpers.hasString(res.strings, "ok"));
    try std.testing.expect(helpers.hasString(res.strings, "boom"));
}

test "interns identical strings (same StringID)" {
    const src =
        \\a be "x"
        \\yap "x"
        \\yap a
    ;

    var lx = Lexer.init(std.testing.allocator, src);
    var toks = try lx.lex();
    defer toks.deinit();

    var p = Parser.init(std.testing.allocator, toks.items);
    const res = try p.parse();
    defer deinitParse(std.testing.allocator, res.ops, res.strings);

    try std.testing.expectEqual(@as(usize, 2), res.strings.len);
    try std.testing.expect(helpers.hasString(res.strings, "a"));
    try std.testing.expect(helpers.hasString(res.strings, "x"));
}

test "parses truth/none values" {
    const src =
        \\yap yeah
        \\yap nope
    ;

    var lx = Lexer.init(std.testing.allocator, src);
    var toks = try lx.lex();
    defer toks.deinit();

    var p = Parser.init(std.testing.allocator, toks.items);
    const res = try p.parse();
    defer deinitParse(std.testing.allocator, res.ops, res.strings);

    try std.testing.expectEqual(@as(usize, 2), res.ops.len);

    const p0 = res.ops[0].Print.value;
    const p1 = res.ops[1].Print.value;

    try std.testing.expectEqual(std.meta.activeTag(p0), .truth);
    try std.testing.expectEqual(std.meta.activeTag(p1), .none);
}

test "chained reckons is left-associative compare(compare(a,b),c)" {
    const src = "yap 1 reckons 1 reckons yeah";

    var lx = Lexer.init(std.testing.allocator, src);
    var toks = try lx.lex();
    defer toks.deinit();

    var p = Parser.init(std.testing.allocator, toks.items);
    const res = try p.parse();
    defer deinitParse(std.testing.allocator, res.ops, res.strings);

    try std.testing.expectEqual(@as(usize, 1), res.ops.len);

    const v = res.ops[0].Print.value;
    try std.testing.expectEqual(std.meta.activeTag(v), .compare);

    const outer = v.compare;
    try std.testing.expectEqual(std.meta.activeTag(outer.left.*), .compare);
    try std.testing.expectEqual(std.meta.activeTag(outer.right.*), .truth);

    const inner = outer.left.*.compare;
    try std.testing.expectEqual(std.meta.activeTag(inner.left.*), .literal);
    try std.testing.expectEqual(std.meta.activeTag(inner.right.*), .literal);
}
