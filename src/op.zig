const Identifier = @import("token.zig").Identifier;
const Literal = @import("token.zig").Literal;

pub const Value = union(enum) {
    identifier: Identifier,
    literal: Literal,
};

pub const Op = union(enum) {
    Assign: struct {
        name: []const u8,
        value: Value,
    },
    Yap: struct {
        value: Value,
    },
    Throw: struct {
        message: []const u8,
    },
};
