const std = @import("std");
const yap = @import("lib.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        printUsage();
        return;
    }

    const path = args[1];

    const source = std.fs.cwd().readFileAlloc(
        allocator,
        path,
        1 << 20,
    ) catch |err| {
        printFileError(path, err);
        return;
    };
    defer allocator.free(source);

    const result = yap.compile(allocator, source);

    switch (result) {
        .Ok => |ir| {
            defer ir.deinit();
            if (yap.run(allocator, ir)) |_| {} else |err| {
                std.debug.print("runtime error: {}\n", .{err});
            }
        },

        .Err => |err| {
            const msg = try yap.formatCompileError(allocator, err);
            defer allocator.free(msg);
            std.debug.print("{s}", .{msg});
        },
    }
}

fn printUsage() void {
    std.debug.print(
        \\Usage:
        \\  yap <file>
        \\
    , .{});
}

fn printFileError(path: []const u8, err: anyerror) void {
    switch (err) {
        error.FileNotFound => {
            std.debug.print(
                "error: file not found: {s}\n",
                .{path},
            );
        },
        error.AccessDenied => {
            std.debug.print(
                "error: permission denied: {s}\n",
                .{path},
            );
        },
        else => {
            std.debug.print(
                "error: failed to read '{s}': {}\n",
                .{path, err},
            );
        },
    }
}

fn printExpectation(exp: yap.parser.Expectation) void {
    std.debug.print("expected ", .{});
    switch (exp) {
        .Identifier => std.debug.print("identifier\n", .{}),
        .Token => |t| std.debug.print("{s}\n", .{@tagName(t)}),
        .Pattern => |p| std.debug.print("{s}\n", .{p}),
    }
}
