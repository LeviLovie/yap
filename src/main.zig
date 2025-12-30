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

    yap.run(allocator, source) catch |err| {
        printRuntimeError(err);
        return;
    };
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

fn printRuntimeError(err: anyerror) void {
    switch (err) {
        error.RuntimeError => {
            std.debug.print("runtime error occurred\n", .{});
        },
        else => {
            std.debug.print("unexpected error: {}\n", .{err});
        },
    }
}
