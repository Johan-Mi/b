const Cst = @import("Cst.zig");
const SyntaxKind = @import("syntax.zig").Kind;

pub const Document = struct {
    syntax: Cst.Node,

    pub const cast = CastImpl(@This(), .document).cast;
    pub const functions = ChildrenImpl(@This(), Function).init;
};

pub const Function = struct {
    syntax: Cst.Node,

    const cast = CastImpl(@This(), .function).cast;
    pub const name = ChildTokenImpl(@This(), .identifier).find;
};

fn CastImpl(Self: type, syntax_kind: SyntaxKind) type {
    return struct {
        fn cast(syntax: Cst.Node, cst: Cst) ?Self {
            return if (syntax.kind(cst) == syntax_kind) .{ .syntax = syntax } else null;
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
