const Identifier = @import("token.zig").Identifier;
const Op = @import("op.zig").Op;
const Span = @import("span.zig").Span;
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

    ops: std.ArrayList(Op),
    strings: std.ArrayList([]const u8),
    string_map: std.StringHashMap(StringID),

    lastExpectation: ?Expectation = null,
    errorSpan: ?Span = null,

    pub fn init(
        allocator: std.mem.Allocator,
        tokens: []const Token,
    ) Parser {
        return Parser{
            .allocator = allocator,
            .tokens = tokens,
            .index = 0,
            .ops = std.ArrayList(Op).init(allocator),
            .strings = std.ArrayList([]const u8).init(allocator),
            .string_map = std.StringHashMap(StringID).init(allocator),
        };
    }

    pub fn deinit(self: *Parser) void {
        for (self.strings.items) |s| self.allocator.free(s);
        self.ops.deinit();
        self.strings.deinit();
        self.string_map.deinit();
    }

    fn boxValue(self: *Parser, v: Value) !*Value {
        const p = try self.allocator.create(Value);
        p.* = v;
        return p;
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
            self.errorSpan = null;
            return error.UnexpectedEof;
        };

        if (std.meta.activeTag(tok) != expected) {
            self.lastExpectation = .{ .Token = expected };
            self.errorSpan = tok.span();
            return error.UnexpectedToken;
        }
    }

    fn expectIdentifier(self: *Parser) !Identifier {
        const tok = self.next() orelse {
            self.lastExpectation = .Identifier;
            self.errorSpan = null;
            return error.UnexpectedEof;
        };

        return switch (tok) {
            .identifier => |id| id,
            else => {
                self.lastExpectation = .Identifier;
                self.errorSpan = tok.span();
                return error.UnexpectedToken;
            },
        };
    }

    fn expectValue(self: *Parser) !Value {
        const tok = self.next() orelse {
            self.lastExpectation = .{ .Pattern = "VALUE or IDENTIFIER" };
            self.errorSpan = null;
            return error.UnexpectedEof;
        };

        return switch (tok) {
            .identifier => |id| .{
                .identifier = .{
                    .name = try self.stringId(id.name),
                    .span = id.span,
                },
            },

            .literal => |lit| switch (lit) {
                .number => |n| .{
                    .literal = .{
                        .number = .{ .value = n.value, .span = n.span },
                    },
                },
                .string => |s| .{
                    .literal = .{
                        .string = .{
                            .value = try self.stringId(s.value),
                            .span = s.span,
                        },
                    },
                },
            },

            else => {
                self.lastExpectation = .{ .Pattern = "VALUE or IDENTIFIER" };
                self.errorSpan = null;
                return error.UnexpectedToken;
            },
        };
    }

    fn stringId(self: *Parser, s: []const u8) !StringID {
        if (self.string_map.get(s)) |id| {
            return id;
        }

        const owned = try self.allocator.dupe(u8, s);
        errdefer self.allocator.free(owned);

        const id: StringID = self.strings.items.len;
        try self.strings.append(owned);
        try self.string_map.put(owned, id);

        return id;
    }

    pub fn formatError(self: *Parser, writer: anytype) !void {
        if (self.errorSpan) |sp| {
            writer.print(
                "parse error at line {d}, column {d}\n",
                .{ sp.line, sp.column },
            );
        }

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
        errdefer self.deinit();

        while (self.peek() != null) {
            const tok = self.next().?;

            switch (tok) {
                // IDENT assign EXPR
                .identifier => |identifier| {
                    self.lastExpectation = .{ .Pattern = "IDENT assign EXPR" };
                    try self.expect(.assign);

                    const value = try self.parseExpr();
                    const name_id = try self.stringId(identifier.name);

                    try self.ops.append(.{
                        .Assign = .{
                            .name = name_id,
                            .value = value,
                            .span = identifier.span,
                        },
                    });
                },

                // print EXPR
                .print => |sp| {
                    self.lastExpectation = .{ .Pattern = "print EXPR" };
                    const value = try self.parseExpr();

                    try self.ops.append(.{
                        .Print = .{
                            .value = value,
                            .span = sp,
                        },
                    });
                },

                // throw MSG
                .throw => |t| {
                    const msg_id = try self.stringId(t.message);
                    try self.ops.append(.{
                        .Throw = .{ .message = msg_id, .span = t.span },
                    });
                },

                else => return error.UnexpectedToken,
            }
        }

        const ops = try self.ops.toOwnedSlice();
        const strings = try self.strings.toOwnedSlice();

        self.ops = undefined;
        self.strings = undefined;
        self.string_map.deinit();

        return .{ .ops = ops, .strings = strings };
    }

    fn parsePrimary(self: *Parser) !Value {
        const tok = self.next() orelse {
            self.lastExpectation = .{ .Pattern = "VALUE" };
            self.errorSpan = null;
            return error.UnexpectedEof;
        };

        return switch (tok) {
            .identifier => |id| .{
                .identifier = .{
                    .name = try self.stringId(id.name),
                    .span = id.span,
                },
            },

            .literal => |lit| switch (lit) {
                .number => |n| .{ .literal = .{ .number = .{ .value = n.value, .span = n.span } } },
                .string => |s| .{ .literal = .{ .string = .{ .value = try self.stringId(s.value), .span = s.span } } },
            },

            .truth => |sp| .{ .truth = sp },
            .none => |sp| .{ .none = sp },

            else => {
                self.lastExpectation = .{ .Pattern = "VALUE" };
                self.errorSpan = tok.span();
                return error.UnexpectedToken;
            },
        };
    }

    fn parseExpr(self: *Parser) !Value {
        var left = try self.parsePrimary();

        while (true) {
            const peeked = self.peek() orelse break;
            if (std.meta.activeTag(peeked) != .equals) break;
            const eq_span = self.next().?.equals;
            const right = try self.parsePrimary();

            left = .{
                .compare = .{
                    .left = try self.boxValue(left),
                    .right = try self.boxValue(right),
                    .span = eq_span,
                },
            };
        }

        return left;
    }
};
