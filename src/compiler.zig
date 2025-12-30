const std = @import("std");
const Ir = @import("ir.zig").Ir;
const lexer = @import("lexer.zig");
const parser = @import("parser.zig");

pub const CompileError = union(enum) {
    Parse: struct {
        index: usize,
        expectation: ?parser.Expectation,
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
        var tokens = lexer.lex(self.allocator, self.source) catch {
            return .{ .Err = .Internal };
        };
        defer tokens.deinit();

        var p = parser.Parser.init(self.allocator, tokens.items);

        var ops = p.parse() catch {
            return .{
                .Err = .{
                    .Parse = .{
                        .index = p.errorIndex,
                        .expectation = p.lastExpectation,
                    },
                },
            };
        };
        defer ops.deinit();

        const owned_ops = ops.toOwnedSlice() catch |err| switch (err) {
            error.OutOfMemory => {
                ops.deinit();
                return .{ .Err = .OutOfMemory };
            },
        };
        return .{ .Ok = Ir.init(self.allocator, owned_ops) };
    }
};
