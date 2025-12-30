const std = @import("std");

pub const CompileError = @import("compiler.zig").CompileError;
pub const CompileResult = @import("compiler.zig").CompileResult;
pub const Compiler = @import("compiler.zig").Compiler;
pub const Identifier = @import("token.zig").Identifier;
pub const Ir = @import("ir.zig").Ir;
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
    var rt = runtime.Runtime.init(allocator);
    defer rt.deinit();
    try rt.exec(ir.ops);
}
