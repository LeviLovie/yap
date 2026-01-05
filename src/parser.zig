const Assoc = @import("op.zig").Assoc;
const Calculation = @import("value.zig").Calculation;
const Identifier = @import("token.zig").Identifier;
const Op = @import("op.zig").Op;
const OpInfo = @import("op.zig").OpInfo;
const Span = @import("span.zig").Span;
const StringID = @import("ir.zig").StringID;
const Token = @import("token.zig").Token;
const Value = @import("value.zig").Value;
const infixOp = @import("op.zig").infixOp;
const prefixCalc = @import("op.zig").prefixCalc;
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

pub const Error = ParseError || std.mem.Allocator.Error;

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

    fn peekTag(self: *Parser) ?std.meta.Tag(Token) {
        const t = self.peek() orelse return null;
        return std.meta.activeTag(t);
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
            const stmt = try self.parseStatement();
            try self.ops.append(stmt);
        }

        const ops = try self.ops.toOwnedSlice();
        const strings = try self.strings.toOwnedSlice();

        self.ops = undefined;
        self.strings = undefined;
        self.string_map.deinit();

        return .{ .ops = ops, .strings = strings };
    }

    fn parseAtom(self: *Parser) !Value {
        const tok = self.next() orelse {
            self.lastExpectation = .{ .Pattern = "VALUE" };
            self.errorSpan = null;
            return error.UnexpectedEof;
        };

        return switch (tok) {
            .identifier => |id| .{
                .identifier = .{ .name = try self.stringId(id.name), .span = id.span },
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

    fn parseStatement(self: *Parser) Error!Op {
        const tok = self.next() orelse {
            self.lastExpectation = .{ .Pattern = "STATEMENT" };
            self.errorSpan = null;
            return error.UnexpectedEof;
        };

        return switch (tok) {
            // IDENT assign EXPR
            .identifier => |identifier| blk: {
                self.lastExpectation = .{ .Pattern = "IDENT assign EXPR" };
                try self.expect(.assign);

                const value = try self.parseExpr();
                const name_id = try self.stringId(identifier.name);

                break :blk .{
                    .Assign = .{
                        .name = name_id,
                        .value = value,
                        .span = identifier.span,
                    },
                };
            },

            // print EXPR
            .print => |sp| blk: {
                self.lastExpectation = .{ .Pattern = "print EXPR" };
                const value = try self.parseExpr();

                break :blk .{
                    .Print = .{ .value = value, .span = sp },
                };
            },

            // throw EVENT
            .throw => |t| blk: {
                const event_id = try self.stringId(t.event);
                break :blk .{
                    .Throw = .{ .event = event_id, .span = t.span },
                };
            },

            // mem EVENT
            .mem => |t| blk: {
                const event_id = try self.stringId(t.event);
                break :blk .{
                    .Mem = .{ .event = event_id, .span = t.span },
                };
            },

            // peek EXPR pls ... [nah ...] thx
            .condition => |sp| try self.parseIfLike(sp),

            .then, .ifelse, .end => {
                self.lastExpectation = .{ .Pattern = "STATEMENT" };
                self.errorSpan = tok.span();
                return error.UnexpectedToken;
            },

            else => {
                self.lastExpectation = .{ .Pattern = "STATEMENT" };
                self.errorSpan = tok.span();
                return error.UnexpectedToken;
            },
        };
    }

    fn parseBlockUntil(self: *Parser, stop1: std.meta.Tag(Token), stop2: ?std.meta.Tag(Token)) ![]Op {
        var list = std.ArrayList(Op).init(self.allocator);
        errdefer {
            for (list.items) |*op| op.deinit(self.allocator);
            list.deinit();
        }

        while (true) {
            const tag = self.peekTag() orelse {
                self.lastExpectation = .{ .Token = .end };
                self.errorSpan = null;
                return error.UnexpectedEof;
            };

            if (tag == stop1) break;
            if (stop2) |s2| if (tag == s2) break;

            const stmt = try self.parseStatement();
            try list.append(stmt);
        }

        return try list.toOwnedSlice();
    }

    fn parsePrefix(self: *Parser) !Value {
        const tag = self.peekTag() orelse return error.UnexpectedEof;

        if (prefixCalc(tag)) |calc| {
            const tok = self.next().?;
            const sp = tok.span();

            const right = try self.parsePrefix();
            return try self.makeCalc(calc, sp, right, .{ .none = sp });
        }

        return self.parseAtom();
    }

    fn parseExpr(self: *Parser) !Value {
        return self.parseExpression(1);
    }

    fn parseExpression(self: *Parser, min_prec: u8) !Value {
        var left = try self.parsePrefix();

        while (true) {
            const tag = self.peekTag() orelse break;
            const info = infixOp(tag) orelse break;

            if (info.prec < min_prec) break;

            const tok = self.next().?;
            const sp = tok.span();

            const next_min =
                if (info.assoc == .Left)
                    info.prec + 1
                else
                    info.prec;

            const right = try self.parseExpression(next_min);
            left = try self.makeCalc(info.calc, sp, left, right);
        }

        return left;
    }

    fn parseIfLike(self: *Parser, start_span: Span) !Op {
        const condition = try self.parseExpr();

        try self.expect(.then);

        const then_ops = try self.parseBlockUntil(.ifelse, .end);

        if (self.peekTag() == .ifelse) {
            _ = self.next();
            const else_ops = try self.parseBlockUntil(.end, null);
            try self.expect(.end);

            return .{
                .IfElse = .{
                    .condition = condition,
                    .then_ops = then_ops,
                    .else_ops = else_ops,
                    .span = start_span,
                },
            };
        }

        try self.expect(.end);
        return .{
            .If = .{
                .condition = condition,
                .then_ops = then_ops,
                .span = start_span,
            },
        };
    }

    fn makeCalc(self: *Parser, op: Calculation, sp: Span, left: Value, right: Value) !Value {
        return .{
            .calculate = .{
                .left = try self.boxValue(left),
                .right = try self.boxValue(right),
                .operation = op,
                .span = sp,
            },
        };
    }
};
