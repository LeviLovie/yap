const Identifier = @import("token.zig").Identifier;

pub const Op = union(enum) {
    Assign: struct {
        name: []const u8,
        value: Identifier,
    },
    Yap: struct {
        value: Identifier,
    },
    Throw: struct {
        message: []const u8,
    },
};
