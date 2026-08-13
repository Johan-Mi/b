node: Cst.Node,

pub fn resolve(token: Cst.Node) ?Name {
    std.debug.assert(token.kind() == .identifier);
    const name = token.source();
    var maybe_node = token.parent();
    return blk: while (maybe_node) |node| : (maybe_node = node.parent()) {
        if (ast.Document.cast(node)) |document| {
            var iterator = document.functions();
            while (iterator.next()) |function| {
                const it = function.name() orelse continue;
                if (std.mem.eql(u8, name, it.source())) break :blk .{ .node = it };
            }
        } else if (ast.CompoundStatement.cast(node)) |compound| {
            var statements = compound.statements();
            while (statements.next()) |statement| {
                switch (statement) {
                    inline .auto, .extrn => |decls| {
                        var iterator = decls.syntax.children();
                        while (iterator.next()) |it| {
                            if (it.kind() == .identifier and
                                std.mem.eql(u8, name, it.source())) break :blk .{ .node = it };
                        }
                    },
                    else => {},
                }
            }
        }
    } else null;
}

const Name = @This();

const ast = @import("ast.zig");
const Cst = @import("Cst.zig");
const std = @import("std");
