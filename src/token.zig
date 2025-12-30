pub const Token = union(enum) {
    be,
    identifier: []const u8,
    throw: []const u8,
    yap,
};
