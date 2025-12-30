const std = @import("std");
const Token = @import("token.zig").Token;
const Op = @import("op.zig").Op;

pub fn parse(
    allocator: std.mem.Allocator,
    tokens: []const Token,
) !std.ArrayList(Op) {
    var instrs = std.ArrayList(Op).init(allocator);

    var i: usize = 0;
    while (i < tokens.len) {
        switch (tokens[i]) {
            // VAR be VALUE
            .identifier => |name| {
                if (i + 2 >= tokens.len) return error.SyntaxError;
                if (tokens[i + 1] != .be) return error.SyntaxError;

                const value = switch (tokens[i + 2]) {
                    .identifier => |v| v,
                    else => return error.SyntaxError,
                };

                try instrs.append(.{
                    .Assign = .{
                        .name = name,
                        .value = value,
                    },
                });

                i += 3;
            },
            // yap VALUE
            .yap => {
                if (i + 1 >= tokens.len) return error.SyntaxError;

                const value = switch (tokens[i + 1]) {
                    .identifier => |v| v,
                    else => return error.SyntaxError,
                };

                try instrs.append(.{
                    .Yap = .{ .value = value },
                });

                i += 2;
            },

            // throw MESSAGE
            .throw => {
                if (i + 1 >= tokens.len) return error.SyntaxError;

                const message = switch (tokens[i + 1]) {
                    .identifier => |msg| msg,
                    else => return error.SyntaxError,
                };

                try instrs.append(.{
                    .Throw = .{ .message = message },
                });

                return instrs;
            },

            else => return error.SyntaxError,
        }
    }

    return instrs;
}
