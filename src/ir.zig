pub const Program = struct {
    functions: []const Function,
};

pub const Function = struct {
    name: [*:0]const u8,
    parameter_count: u8,
    body: Statement,
};

pub const Statement = union(enum) {
    compound: []Statement,

    @"error",
};
