const std = @import("std");

pub const CompileError = @import("compiler.zig").CompileError;
pub const CompileResult = @import("compiler.zig").CompileResult;
pub const Compiler = @import("compiler.zig").Compiler;
pub const Identifier = @import("token.zig").Identifier;
pub const Ir = @import("ir.zig").Ir;
pub const Literal = @import("token.zig").Literal;
pub const Op = @import("op.zig").Op;
pub const Span = @import("span.zig").Span;
pub const Token = @import("token.zig").Token;
pub const parser = @import("parser.zig");
pub const lexer = @import("lexer.zig");
pub const runtime = @import("runtime.zig");

pub fn compile(
    allocator: std.mem.Allocator,
    source: []const u8,
) CompileResult {
    var compiler = Compiler.init(allocator, source);
    defer compiler.deinit();
    return compiler.compile();
}

pub fn run(
    allocator: std.mem.Allocator,
    ir: Ir,
) !void {
    const writer = std.io.getStdOut().writer();
    try runWithWriter(allocator, writer, ir);
}

pub fn runWithWriter(
    allocator: std.mem.Allocator,
    writer: anytype,
    ir: Ir,
) !void {
    var rt = runtime.Runtime.init(allocator);
    defer rt.deinit();
    rt.exec(writer, ir.ops) catch |err| {
        switch (err) {
            error.RuntimeError => {
                return;
            },
            else => return err,
        }
    };
}

pub fn formatCompileError(
    allocator: std.mem.Allocator,
    err: CompileError,
) ![]u8 {
    var out = std.ArrayList(u8).init(allocator);
    errdefer out.deinit();
    const w = out.writer();

    switch (err) {
        .Parse => |p| {
            try w.print("parse error at token {d}\n", .{p.index});
            if (p.expectation) |exp| {
                try w.print("expected ", .{});
                switch (exp) {
                    .Identifier => try w.print("identifier\n", .{}),
                    .Token => |t| try w.print("{s}\n", .{@tagName(t)}),
                    .Pattern => |pat| try w.print("{s}\n", .{pat}),
                }
            }
        },

        .Lex => |l| {
            try w.print(
                "lex error at {d}:{d}: invalid character '{c}'\n",
                .{ l.span.line, l.span.column, l.ch },
            );
        },

        .OutOfMemory => {
            try w.print("error: out of memory\n", .{});
        },

        .Internal => {
            try w.print("internal compiler error\n", .{});
        },
    }

    return out.toOwnedSlice();
}
