const SyntaxKind = @import("syntax.zig").Kind;

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
    expression: Expression,

    @"error",
};

pub const Expression = union(enum) {
    prefix: struct {
        operator: SyntaxKind,
        operand: *Expression,
    },
    infix: struct {
        lhs: *Expression,
        operator: SyntaxKind,
        rhs: *Expression,
    },
    number: i64,

    @"error",
};
