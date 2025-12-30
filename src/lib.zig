const std = @import("std");

pub const lexer = @import("lexer.zig");
pub const parser = @import("parser.zig");
pub const runtime = @import("runtime.zig");
pub const Token = @import("token.zig").Token;
pub const Op = @import("op.zig").Op;

pub fn run(
    allocator: std.mem.Allocator,
    source: []const u8,
) !void {
    var tokens = try lexer.lex(allocator, source);
    defer tokens.deinit();

    var ops = try parser.parse(allocator, tokens.items);
    defer ops.deinit();

    var rt = runtime.Runtime.init(allocator);
    defer rt.deinit();

    try rt.exec(ops.items);
}
