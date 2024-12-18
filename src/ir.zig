const Name = @import("Name.zig");
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
    @"if": struct {
        condition: Expression,
        body: *Statement,
    },
    @"while": struct {
        condition: Expression,
        body: *Statement,
    },
    expression: Expression,

    @"error",

    pub const nop: @This() = .{ .compound = &.{} };
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
    postfix: struct {
        operator: SyntaxKind,
        operand: *Expression,
    },
    number: i64,
    variable: Name,

    @"error",
};
