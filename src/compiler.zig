const std = @import("std");
const Span = @import("span.zig").Span;
const Ir = @import("ir.zig").Ir;
const lexer = @import("lexer.zig");
const parser = @import("parser.zig");

pub const CompileError = union(enum) {
    Parse: struct {
        span: ?Span,
        expectation: ?parser.Expectation,
    },
    Lex: struct {
        span: Span,
        ch: u8,
    },

    OutOfMemory,
    Internal,
};

pub const CompileResult = union(enum) {
    Ok: Ir,
    Err: CompileError,
};

pub const Compiler = struct {
    allocator: std.mem.Allocator,
    source: []const u8,

    pub fn init(allocator: std.mem.Allocator, source: []const u8) Compiler {
        return Compiler{
            .allocator = allocator,
            .source = source,
        };
    }

    pub fn deinit(self: Compiler) void {
        _ = self;
    }

    pub fn compile(self: Compiler) CompileResult {
        var lx = lexer.Lexer.init(self.allocator, self.source);
        var tokens = lx.lex() catch |err| switch (err) {
            error.OutOfMemory => return .{ .Err = .OutOfMemory },
            error.InvalidCharacter => return .{
                .Err = .{
                    .Lex = .{
                        .span = lx.last_error_span orelse Span{ .start = 0, .end = 0, .line = 1, .column = 1 },
                        .ch = lx.last_error_char orelse 0,
                    },
                },
            },
            error.UnterminatedString => return .{
                .Err = .{
                    .Lex = .{
                        .span = lx.last_error_span orelse Span{ .start = 0, .end = 0, .line = 1, .column = 1 },
                        .ch = '"',
                    },
                },
            },
        };
        defer tokens.deinit();

        var p = parser.Parser.init(self.allocator, tokens.items);

        const res = p.parse() catch {
            return .{
                .Err = .{
                    .Parse = .{
                        .span = p.errorSpan,
                        .expectation = p.lastExpectation,
                    },
                },
            };
        };

        return .{ .Ok = Ir.init(self.allocator, res.strings, res.ops) };
    }
};
