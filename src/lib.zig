const std = @import("std");

pub const CompileError = @import("compiler.zig").CompileError;
pub const CompileResult = @import("compiler.zig").CompileResult;
pub const Compiler = @import("compiler.zig").Compiler;
pub const Identifier = @import("token.zig").Identifier;
pub const Ir = @import("ir.zig").Ir;
pub const Lexer = @import("lexer.zig").Lexer;
pub const Literal = @import("token.zig").Literal;
pub const Op = @import("op.zig").Op;
pub const Parser = @import("parser.zig").Parser;
pub const Runtime = @import("runtime.zig").Runtime;
pub const Span = @import("span.zig").Span;
pub const Token = @import("token.zig").Token;
pub const codec = @import("codec.zig");

pub const BuildResult = union(enum) {
    Ok,
    Err: CompileError,
};

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

pub fn compileToFile(
    allocator: std.mem.Allocator,
    source: []const u8,
    writer: anytype,
) BuildResult {
    const result = compile(allocator, source);
    switch (result) {
        .Ok => |ir| {
            defer ir.deinit();
            ir.serialize(writer) catch return .{ .Err = .Internal };
            return .Ok;
        },
        .Err => |err| return .{ .Err = err },
    }
}

pub fn runFromFile(
    allocator: std.mem.Allocator,
    reader: anytype,
    writer: anytype,
) !void {
    var ir = try Ir.deserialize(allocator, reader);
    defer ir.deinit();

    var rt = Runtime.init(allocator);
    defer rt.deinit();

    try rt.loadStrings(ir.strings);
    try rt.run(writer, ir.ops);
}

pub fn runWithWriter(
    allocator: std.mem.Allocator,
    writer: anytype,
    ir: Ir,
) !void {
    var rt = Runtime.init(allocator);
    defer rt.deinit();

    try rt.loadStrings(ir.strings);
    rt.run(writer, ir.ops) catch |err| {
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
            if (p.span) |span| {
                try w.print(
                    "parse error at {d}:{d}\n",
                    .{ span.line, span.column },
                );
            } else {
                try w.print("parse error at unknown location\n", .{});
            }
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
