const std = @import("std");
const Token = @import("token.zig").Token;
const Span = @import("span.zig").Span;

pub const LexError = error{
    InvalidCharacter,
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

            const start = self.mark();

            const word = self.readWord();
            const span = self.makeSpan(start);

            if (word.len == 0) {
                const bad_mark = self.mark();
                const bad_char = self.peek().?;
                self.advance();

                self.last_error_char = bad_char;
                self.last_error_span = self.makeSpan(bad_mark);

                return error.InvalidCharacter;
            }

            if (std.mem.eql(u8, word, "be")) {
                try tokens.append(.{ .be = span });
            } else if (std.mem.eql(u8, word, "yap")) {
                try tokens.append(.{ .yap = span });
            } else if (std.mem.eql(u8, word, "throw")) {
                self.skipWhitespace();
                const msg_start = self.mark();
                const msg = self.readLine();
                const msg_span = self.makeSpan(msg_start);

                try tokens.append(.{
                    .throw = .{
                        .message = msg,
                        .span = msg_span,
                    },
                });
            } else {
                try tokens.append(.{
                    .identifier = .{
                        .name = word,
                        .span = span,
                    },
                });
            }
        }

        return tokens;
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
