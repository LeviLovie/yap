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

    const cmd = args[1];

    if (std.mem.eql(u8, cmd, "build")) {
        if (args.len != 3) {
            printUsage();
            std.process.exit(1);
        }

        const out_path = try deriveYapcPath(allocator, args[2]);
        defer allocator.free(out_path);

        try cmdBuild(allocator, args[2], out_path);
        return;
    }

    if (std.mem.eql(u8, cmd, "run")) {
        if (args.len != 3) {
            printUsage();
            std.process.exit(1);
        }

        try cmdAuto(allocator, args[2]);
        return;
    }

    try cmdAuto(allocator, cmd);
}

fn cmdAuto(
    allocator: std.mem.Allocator,
    path: []const u8,
) !void {
    const file = std.fs.cwd().openFile(path, .{}) catch |err| {
        std.debug.print("error: cannot open '{s}': {}\n", .{ path, err });
        std.process.exit(1);
    };
    defer file.close();

    if (try isYapcFile(file)) {
        try yap.runFromFile(
            allocator,
            file.reader(),
            std.io.getStdOut().writer(),
        );
        return;
    }

    const source = try readFile(allocator, path);
    defer allocator.free(source);

    const result = yap.compile(allocator, source);
    switch (result) {
        .Ok => |ir| {
            defer ir.deinit();
            try yap.runWithWriter(
                allocator,
                std.io.getStdOut().writer(),
                ir,
            );
        },
        .Err => |err| {
            try printCompileError(allocator, err);
            std.process.exit(1);
        },
    }
}

fn cmdBuild(
    allocator: std.mem.Allocator,
    input_path: []const u8,
    output_path: []const u8,
) !void {
    const source = try readFile(allocator, input_path);
    defer allocator.free(source);

    const file = try std.fs.cwd().createFile(output_path, .{ .truncate = true });
    defer file.close();

    const res = yap.compileToFile(allocator, source, file.writer());
    switch (res) {
        .Ok => {},
        .Err => |err| {
            const msg = try yap.formatCompileError(allocator, err);
            defer allocator.free(msg);
            std.debug.print("{s}", .{msg});
            std.process.exit(1);
        },
    }
}

fn isYapcFile(file: std.fs.File) !bool {
    var magic: [4]u8 = undefined;

    const pos = try file.getPos();
    defer file.seekTo(pos) catch {};

    const n = try file.read(&magic);
    if (n < 4) return false;

    return std.mem.eql(u8, magic[0..], "YAPC");
}

fn deriveYapcPath(
    allocator: std.mem.Allocator,
    input: []const u8,
) ![]u8 {
    if (std.mem.endsWith(u8, input, ".yap")) {
        return try std.fmt.allocPrint(
            allocator,
            "{s}.yapc",
            .{input[0 .. input.len - 4]},
        );
    }

    return try std.fmt.allocPrint(allocator, "{s}.yapc", .{input});
}

fn readFile(
    allocator: std.mem.Allocator,
    path: []const u8,
) ![]u8 {
    return std.fs.cwd().readFileAlloc(allocator, path, 1 << 20);
}

fn printCompileError(
    allocator: std.mem.Allocator,
    err: yap.CompileError,
) !void {
    const msg = try yap.formatCompileError(allocator, err);
    defer allocator.free(msg);
    std.debug.print("{s}", .{msg});
}

fn printUsage() void {
    std.debug.print(
        \\Usage:
        \\  yap build <file.yap>
        \\  yap run <file>
        \\  yap <file>
        \\
    , .{});
}
