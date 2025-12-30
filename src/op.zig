pub const Op = union(enum) {
    Assign: struct {
        name: []const u8,
        value: []const u8,
    },
    Yap: struct {
        value: []const u8,
    },
    Throw: struct {
        message: []const u8,
    },
};
