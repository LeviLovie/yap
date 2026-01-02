const std = @import("std");
const Token = @import("token.zig").Token;
const Span = @import("span.zig").Span;

pub const LexError = error{
    InvalidCharacter,
    UnterminatedString,
};

pub const Lexer = struct {
    allocator: std.mem.Allocator,
    input: []const u8,

    index: usize = 0,
    line: usize = 1,
    column: usize = 1,

    last_error_span: ?Span = null,
    last_error_char: ?u8 = null,

    pub fn init(
        allocator: std.mem.Allocator,
        input: []const u8,
    ) Lexer {
        return Lexer{
            .allocator = allocator,
            .input = input,
        };
    }

    pub fn lex(self: *Lexer) !std.ArrayList(Token) {
        var tokens = std.ArrayList(Token).init(self.allocator);
        errdefer tokens.deinit();

        while (!self.eof()) {
            self.skipWhitespace();
            if (self.eof()) break;

            const c = self.peek().?;
            if (c == '"') {
                try tokens.append(try self.lexString());
            } else if (std.ascii.isDigit(c)) {
                try tokens.append(try self.lexNumber());
            } else if (std.ascii.isAlphabetic(c) or c == '_') {
                try tokens.append(try self.lexWordOrKeyword());
            } else {
                const m = self.mark();
                self.last_error_char = c;
                self.advance();
                self.last_error_span = self.makeSpan(m);
                return error.InvalidCharacter;
            }
        }

        return tokens;
    }

    fn lexString(self: *Lexer) !Token {
        const start = self.mark();
        self.advance();

        const value_start = self.index;

        while (!self.eof()) {
            const c = self.peek().?;
            if (c == '"') break;
            self.advance();
        }

        if (self.eof()) {
            self.last_error_span = self.makeSpan(start);
            return error.UnterminatedString;
        }

        const value = self.input[value_start..self.index];
        self.advance();

        return .{
            .literal = .{
                .string = .{
                    .value = value,
                    .span = self.makeSpan(start),
                },
            },
        };
    }

    fn lexNumber(self: *Lexer) !Token {
        const start = self.mark(); const slice = self.readNumber();

        const value = std.fmt.parseFloat(f64, slice) catch {
            self.last_error_span = self.makeSpan(start);
            return error.InvalidCharacter;
        };

        return .{
            .literal = .{
                .number = .{
                    .value = value,
                    .span = self.makeSpan(start),
                },
            },
        };
    }

    fn lexWordOrKeyword(self: *Lexer) !Token {
        const start = self.mark();
        const word = self.readWord();
        const span = self.makeSpan(start);

        if (std.mem.eql(u8, word, "be")) {
            return .{ .assign = span };
        }
        if (std.mem.eql(u8, word, "yap")) {
            return .{ .print = span };
        }
        if (std.mem.eql(u8, word, "yeah")) {
            return .{ .truth = span };
        }
        if (std.mem.eql(u8, word, "nope")) {
            return .{ .none = span };
        }
        if (std.mem.eql(u8, word, "reckons")) {
            return .{ .equals = span };
        }
        if (std.mem.eql(u8, word, "peek")) {
            return .{ .condition = span };
        }
        if (std.mem.eql(u8, word, "pls")) {
            return .{ .then = span };
        }
        if (std.mem.eql(u8, word, "nah")) {
            return .{ .ifelse = span };
        }
        if (std.mem.eql(u8, word, "thx")) {
            return .{ .end = span };
        }
        if (std.mem.eql(u8, word, "flip")) {
            return .{ .not = span };
        }
        if (std.mem.eql(u8, word, "throw")) {
            self.skipWhitespace();
            const msg_start = self.mark();
            const msg = self.readLine();

            return .{
                .throw = .{
                    .message = msg,
                    .span = self.makeSpan(msg_start),
                },
            };
        }

        return .{
            .identifier = .{
                .name = word,
                .span = span,
            },
        };
    }

    fn eof(self: *Lexer) bool {
        return self.index >= self.input.len;
    }

    fn peek(self: *Lexer) ?u8 {
        if (self.eof()) return null;
        return self.input[self.index];
    }

    fn advance(self: *Lexer) void {
        const c = self.input[self.index];
        self.index += 1;

        if (c == '\n') {
            self.line += 1;
            self.column = 1;
        } else {
            self.column += 1;
        }
    }

    fn skipWhitespace(self: *Lexer) void {
        while (!self.eof()) {
            const c = self.peek() orelse break;
            if (c == ' ' or c == '\t' or c == '\n' or c == '\r') {
                self.advance();
            } else {
                break;
            }
        }
    }

    fn readWord(self: *Lexer) []const u8 {
        const start = self.index;
        while (!self.eof()) {
            const c = self.peek() orelse break;
            if (std.ascii.isAlphabetic(c) or std.ascii.isDigit(c) or c == '_') {
                self.advance();
            } else {
                break;
            }
        }
        return self.input[start..self.index];
    }

    fn readLine(self: *Lexer) []const u8 {
        const start = self.index;
        while (!self.eof()) {
            const c = self.peek() orelse break;
            if (c != '\n') {
                self.advance();
            } else {
                break;
            }
        }
        return self.input[start..self.index];
    }

    fn readNumber(self: *Lexer) []const u8 {
        const start = self.index;
        var seen_dot = false;

        while (!self.eof()) {
            const c = self.peek().?;

            if (std.ascii.isDigit(c)) {
                self.advance();
            } else if (c == '.' and !seen_dot) {
                seen_dot = true;
                self.advance();
            } else {
                break;
            }
        }

        return self.input[start..self.index];
    }

    fn mark(self: *Lexer) struct {
        index: usize,
        line: usize,
        column: usize,
    } {
        return .{
            .index = self.index,
            .line = self.line,
            .column = self.column,
        };
    }

    fn makeSpan(self: *Lexer, m: anytype) Span {
        return .{
            .start = m.index,
            .end = self.index,
            .line = m.line,
            .column = m.column,
        };
    }
};
