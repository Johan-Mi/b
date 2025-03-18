pub const Document = struct {
    syntax: Cst.Node,

    pub const cast = CastImpl(@This(), .document).cast;
    pub const functions = ChildrenImpl(@This(), Function).init;
};

pub const Function = struct {
    syntax: Cst.Node,

    const cast = CastImpl(@This(), .function).cast;
    pub const name = ChildTokenImpl(@This(), .identifier).find;
    pub const body = ChildImpl(@This(), Statement).find;
};

pub const Statement = union(enum) {
    auto: Auto,
    extrn: Extrn,
    compound: CompoundStatement,
    @"while": While,
    @"if": If,
    expression: ExpressionStatement,

    const cast = CastUnionEnumImpl(@This()).cast;
};

pub const Auto = struct {
    syntax: Cst.Node,

    const cast = CastImpl(@This(), .auto).cast;
};

pub const Extrn = struct {
    syntax: Cst.Node,

    pub const cast = CastImpl(@This(), .extrn).cast;
};

pub const CompoundStatement = struct {
    syntax: Cst.Node,

    pub const cast = CastImpl(@This(), .compound_statement).cast;
    pub const statements = ChildrenImpl(@This(), Statement).init;
};

const While = struct {
    syntax: Cst.Node,

    const cast = CastImpl(@This(), .@"while").cast;
    pub const condition = ChildImpl(@This(), Expression).find;
    pub const body = ChildImpl(@This(), Statement).find;
};

const If = struct {
    syntax: Cst.Node,

    const cast = CastImpl(@This(), .@"if").cast;
    pub const condition = ChildImpl(@This(), Expression).find;
    pub const body = ChildImpl(@This(), Statement).find;
};

pub const ExpressionStatement = struct {
    syntax: Cst.Node,

    const cast = CastImpl(@This(), .expression_statement).cast;
    pub const expression = ChildImpl(@This(), Expression).find;
};

pub const Expression = union(enum) {
    prefix: PrefixOperation,
    infix: InfixOperation,
    postfix: PostfixOperation,
    number: Number,
    variable: Variable,
    parenthesized: Parenthesized,

    const cast = CastUnionEnumImpl(@This()).cast;

    const Parenthesized = struct {
        syntax: Cst.Node,

        const cast = CastImpl(@This(), .parenthesized_expression).cast;
        pub const inner = ChildImpl(@This(), Expression).find;
    };
};

pub const PrefixOperation = struct {
    syntax: Cst.Node,

    const cast = CastImpl(@This(), .prefix_operation).cast;

    pub const operand = ChildImpl(@This(), Expression).find;

    pub fn operator(self: @This(), cst: Cst) ?Cst.Node {
        var iterator = self.syntax.children(cst);
        return while (iterator.next(cst)) |child| {
            if (Parser.prefixBindingPower(child.kind(cst))) |_| break child;
        } else null;
    }
};

pub const InfixOperation = struct {
    syntax: Cst.Node,

    const cast = CastImpl(@This(), .infix_operation).cast;

    pub const lhs = ChildImpl(@This(), Expression).find;
    pub const rhs = ChildImpl(@This(), Rhs).find;

    pub fn operator(self: @This(), cst: Cst) ?Cst.Node {
        var iterator = self.syntax.children(cst);
        return while (iterator.next(cst)) |child| {
            if (Parser.infixBindingPower(child.kind(cst))) |_| break child;
        } else null;
    }
};

pub const PostfixOperation = struct {
    syntax: Cst.Node,

    const cast = CastImpl(@This(), .postfix_operation).cast;

    pub const operand = ChildImpl(@This(), Expression).find;

    pub fn operator(self: @This(), cst: Cst) ?Cst.Node {
        var iterator = self.syntax.children(cst);
        return while (iterator.next(cst)) |child| {
            if (Parser.postfixBindingPower(child.kind(cst))) |_| break child;
        } else null;
    }
};

pub const Rhs = struct {
    syntax: Cst.Node,

    const cast = CastImpl(@This(), .rhs).cast;

    pub const expression = ChildImpl(@This(), Expression).find;
};

pub const Number = struct {
    syntax: Cst.Node,

    const cast = CastImpl(@This(), .number).cast;
};

pub const Variable = struct {
    syntax: Cst.Node,

    const cast = CastImpl(@This(), .variable).cast;
    pub const identifier = ChildTokenImpl(@This(), .identifier).find;
};

fn CastImpl(Self: type, syntax_kind: SyntaxKind) type {
    return struct {
        fn cast(syntax: Cst.Node, cst: Cst) ?Self {
            return if (syntax.kind(cst) == syntax_kind) .{ .syntax = syntax } else null;
        }
    };
}

fn CastUnionEnumImpl(Self: type) type {
    return struct {
        fn cast(syntax: Cst.Node, cst: Cst) ?Self {
            const type_info = @typeInfo(Self).@"union";
            return inline for (type_info.fields) |field| {
                if (field.type.cast(syntax, cst)) |it| break @unionInit(Self, field.name, it);
            } else null;
        }
    };
}

fn ChildImpl(Self: type, Child: type) type {
    return struct {
        fn find(self: Self, cst: Cst) ?Child {
            var iterator = self.syntax.children(cst);
            return while (iterator.next(cst)) |node| {
                if (Child.cast(node, cst)) |child| break child;
            } else null;
        }
    };
}

fn ChildTokenImpl(Self: type, syntax_kind: SyntaxKind) type {
    return struct {
        fn find(self: Self, cst: Cst) ?Cst.Node {
            var iterator = self.syntax.children(cst);
            return while (iterator.next(cst)) |child| {
                if (child.kind(cst) == syntax_kind) break child;
            } else null;
        }
    };
}

fn ChildrenImpl(Self: type, Child: type) type {
    return struct {
        iterator: Cst.Node.ChildIterator,

        fn init(self: Self, cst: Cst) @This() {
            return .{ .iterator = self.syntax.children(cst) };
        }

        pub fn next(self: *@This(), cst: Cst) ?Child {
            return while (self.iterator.next(cst)) |node| {
                if (Child.cast(node, cst)) |child| break child;
            } else null;
        }

        pub fn count(self: @This(), cst: Cst) usize {
            var copy = self;
            var i: usize = 0;
            while (copy.next(cst)) |_| i += 1;
            return i;
        }
    };
}

const Parser = @import("Parser.zig");
const Cst = @import("Cst.zig");
const SyntaxKind = @import("syntax.zig").Kind;
