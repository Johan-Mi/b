node: Cst.Node,

pub fn resolve(token: Cst.Node, cst: Cst) ?@This() {
    std.debug.assert(token.kind(cst) == .identifier);
    const name = token.source(cst);
    var maybe_node = token.parent(cst);
    return blk: while (maybe_node) |node| : (maybe_node = node.parent(cst)) {
        if (ast.Document.cast(node, cst)) |document| {
            var iterator = document.functions(cst);
            while (iterator.next(cst)) |function| {
                const it = function.name(cst) orelse continue;
                if (std.mem.eql(u8, name, it.source(cst))) break :blk .{ .node = it };
            }
        } else if (ast.CompoundStatement.cast(node, cst)) |compound| {
            var statements = compound.statements(cst);
            while (statements.next(cst)) |statement| {
                switch (statement) {
                    inline .auto, .extrn => |decls| {
                        var iterator = decls.syntax.children(cst);
                        while (iterator.next(cst)) |it| {
                            if (it.kind(cst) == .identifier and
                                std.mem.eql(u8, name, it.source(cst))) break :blk .{ .node = it };
                        }
                    },
                    else => {},
                }
            }
        }
    } else null;
}

const ast = @import("ast.zig");
const Cst = @import("Cst.zig");
const std = @import("std");
