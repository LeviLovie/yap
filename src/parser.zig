const Identifier = @import("token.zig").Identifier;
const Op = @import("op.zig").Op;
const StringID = @import("ir.zig").StringID;
const Token = @import("token.zig").Token;
const Value = @import("value.zig").Value;
const std = @import("std");

pub const ParseResult = struct {
    ops: []Op,
    strings: []const []const u8,
};

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

    fn intern(self: *Parser, strings: *std.ArrayList([]const u8), s: []const u8) !StringID {
        const owned = try self.allocator.dupe(u8, s);
        errdefer self.allocator.free(owned);
        try strings.append(owned);
        return strings.items.len - 1;
    }

    fn expectValue(self: *Parser, strings: *std.ArrayList([]const u8)) !Value {
        const tok = self.next() orelse {
            self.lastExpectation = .{ .Pattern = "VALUE or IDENTIFIER" };
            self.errorIndex = self.index;
            return error.UnexpectedEof;
        };

        return switch (tok) {
            .identifier => |id_tok| .{
                .identifier = .{
                    .name = try self.intern(strings, id_tok.name),
                    .span = id_tok.span,
                },
            },
            .literal => |lit_tok| switch (lit_tok) {
                .number => |n| .{ .literal = .{ .number = .{ .value = n.value, .span = n.span } } },
                .string => |s| .{
                    .literal = .{
                        .string = .{
                            .value = try self.intern(strings, s.value),
                            .span = s.span,
                        },
                    },
                },
            },
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

    pub fn parse(self: *Parser) !ParseResult {
        var ops = std.ArrayList(Op).init(self.allocator);
        var strings = std.ArrayList([]const u8).init(self.allocator);
        errdefer ops.deinit();

        while (self.peek() != null) {
            const tok = self.next().?;

            switch (tok) {
                // VAR be VALUE
                .identifier => |identifier| {
                    self.lastExpectation = .{ .Pattern = "VAR be VALUE" };
                    try self.expect(.be);
                    const value = try self.expectValue(&strings);

                    const owned_name = try self.allocator.dupe(u8, identifier.name);
                    try strings.append(owned_name);
                    const string_id = strings.items.len - 1;

                    try ops.append(.{
                        .Assign = .{
                            .name = string_id,
                            .value = value,
                            .span = identifier.span,
                        },
                    });
                },

                // yap VAR
                .yap => |span| {
                    self.lastExpectation = .{ .Pattern = "yap VALUE" };
                    const value = try self.expectValue(&strings);

                    try ops.append(.{
                        .Yap = .{
                            .value = value,
                            .span = span,
                        },
                    });
                },

                // throw MSG
                .throw => |throw| {
                    try strings.append(throw.message);
                    const string_id = strings.items.len - 1;

                    try ops.append(.{
                        .Throw = .{
                            .message = string_id,
                            .span = throw.span,
                        },
                    });
                },

                else => return error.UnexpectedToken,
            }
        }

        return .{
            .ops = try ops.toOwnedSlice(),
            .strings = try strings.toOwnedSlice(),
        };
    }
};
