const std = @import("std");
const Identifier = @import("token.zig").Identifier;
const Op = @import("op.zig").Op;
const Token = @import("token.zig").Token;
const Value = @import("op.zig").Value;

pub const ParseError = error{
    UnexpectedToken,
    UnexpectedEof,
};

pub const Expectation = union(enum) {
    Identifier,
    Token: std.meta.Tag(Token),
    Pattern: []const u8,
};

pub const Parser = struct {
    allocator: std.mem.Allocator,
    tokens: []const Token,
    index: usize,

    lastExpectation: ?Expectation = null,
    errorIndex: usize = 0,

    pub fn init(
        allocator: std.mem.Allocator,
        tokens: []const Token,
    ) Parser {
        return Parser{
            .allocator = allocator,
            .tokens = tokens,
            .index = 0,
        };
    }

    fn has(self: *Parser, n: usize) bool {
        return self.index + n <= self.tokens.len;
    }

    fn peek(self: *Parser) ?Token {
        if (self.index >= self.tokens.len) return null;
        return self.tokens[self.index];
    }

    fn next(self: *Parser) ?Token {
        if (!self.has(1)) return null;
        const token = self.tokens[self.index];
        self.index += 1;
        return token;
    }

    fn expect(self: *Parser, expected: std.meta.Tag(Token)) !void {
        const tok = self.next() orelse {

            self.lastExpectation = .{ .Token = expected };
            self.errorIndex = self.index;
            return error.UnexpectedEof;
        };

        if (std.meta.activeTag(tok) != expected) {
            self.lastExpectation = .{ .Token = expected };
            self.errorIndex = self.index - 1;
            return error.UnexpectedToken;
        }
    }

    fn expectIdentifier(self: *Parser) !Identifier {
        const tok = self.next() orelse {
            self.lastExpectation = .Identifier;
            self.errorIndex = self.index;
            return error.UnexpectedEof;
        };

        return switch (tok) {
            .identifier => |id| id,
            else => {
                self.lastExpectation = .Identifier;
                self.errorIndex = self.index - 1;
                return error.UnexpectedToken;
            },
        };
    }

    fn expectValue(self: *Parser) !Value {
        const tok = self.next() orelse {
            self.lastExpectation = .{ .Pattern = "VALUE or IDENTIFIER" };
            self.errorIndex = self.index;
            return error.UnexpectedEof;
        };

        return switch (tok) {
            .identifier => |id| .{ .identifier = id },
            .literal => |lit| .{ .literal = lit },
            else => {
                self.lastExpectation = .{ .Pattern = "VALUE or IDENTIFIER" };
                self.errorIndex = self.index - 1;
                return error.UnexpectedToken;
            },
        };
    }

    pub fn formatError(self: *Parser, writer: anytype) !void {
        try writer.print("parse error at token {d}\n", .{self.errorIndex});

        if (self.lastExpectation) |exp| {
            try writer.print("expected ", .{});
            switch (exp) {
                .Identifier => try writer.print("identifier\n", .{}),
                .Token => |t| try writer.print("{s}\n", .{@tagName(t)}),
                .Pattern => |p| try writer.print("{s}\n", .{p}),
            }
        }
    }

    pub fn parse(self: *Parser) !std.ArrayList(Op) {
        var ops = std.ArrayList(Op).init(self.allocator);
        errdefer ops.deinit();

        while (self.peek() != null) {
            const tok = self.next().?;

            switch (tok) {
                // VAR be VALUE
                .identifier => {
                    self.lastExpectation = .{ .Pattern = "VAR be VALUE" };
                    try self.expect(.be);
                    const value = try self.expectValue();

                    try ops.append(.{
                        .Assign = .{
                            .name = tok.identifier.name,
                            .value = value,
                        },
                    });
                },

                // yap VAR
                .yap => {
                    self.lastExpectation = .{ .Pattern = "yap VALUE" };
                    const value = try self.expectValue();

                    try ops.append(.{
                        .Yap = .{ .value = value },
                    });
                },

                // throw MSG
                .throw => |t| {
                    try ops.append(.{
                        .Throw = .{ .message = t.message },
                    });
                },

                else => return error.UnexpectedToken,
            }
        }

        return ops;
    }
};
