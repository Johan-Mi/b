const Cst = @import("Cst.zig");
const SyntaxKind = @import("syntax.zig").Kind;

const Document = struct {
    syntax: Cst.Node,

    const cast = CastImpl(@This(), .document).cast;
    const functions = ChildrenImpl(@This(), Function).init;
};

const Function = struct {
    syntax: Cst.Node,

    const cast = CastImpl(@This(), .function).cast;
};

fn CastImpl(Self: type, syntax_kind: SyntaxKind) type {
    return struct {
        fn cast(syntax: Cst.Node) ?Self {
            return if (syntax.kind() == syntax_kind) .{ .syntax = syntax } else null;
        }
    };
}

fn ChildrenImpl(Self: type, Child: type) type {
    return struct {
        iterator: Cst.Node.ChildIterator,

        fn init(self: Self) @This() {
            return .{ .iterator = self.syntax.children() };
        }

        fn next(self: *@This()) ?Child {
            return while (self.iterator.next()) |node| {
                if (Child.cast(node)) |child| break child;
            } else null;
        }
    };
}
