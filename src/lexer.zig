const std = @import("std");
const Token = @import("token.zig").Token;

pub fn lex(
    allocator: std.mem.Allocator,
    input: []const u8,
) !std.ArrayList(Token) {
    var tokens = std.ArrayList(Token).init(allocator);

    var it = std.mem.tokenizeAny(u8, input, " \n\t");
    while (it.next()) |word| {
        const token: Token =
            if (std.mem.eql(u8, word, "be"))
                Token.be
            else if (std.mem.eql(u8, word, "yap"))
                Token.yap
            else if (std.mem.startsWith(u8, word, "throw")) blk: {
                const msg = std.mem.trimLeft(u8, word[5..], " \t");
                break :blk Token{ .throw = msg };
            }
            else
                Token{ .identifier = word };
        try tokens.append(token);
    }

    return tokens;
}
