const ast = @import("../ast.zig");
const Cst = @import("../Cst.zig");
const Diagnostics = @import("../Diagnostic.zig").S;
const ir = @import("../ir.zig");
const std = @import("std");

pub fn lower(
    cst: Cst,
    arena: std.mem.Allocator,
    diagnostics: *Diagnostics,
) !ir.Program {
    const document = ast.Document.cast(.root, cst).?;

    var iterator = document.functions(cst);
    const functions = try arena.alloc(ir.Function, iterator.count(cst));
    var i: usize = 0;
    while (iterator.next(cst)) |function| : (i += 1) {
        functions[i] = try lowerFunction(function, cst, arena, diagnostics);
    }

    return .{ .functions = functions };
}

fn lowerFunction(
    function: ast.Function,
    cst: Cst,
    arena: std.mem.Allocator,
    diagnostics: *Diagnostics,
) !ir.Function {
    const name = try arena.dupeZ(u8, function.name(cst).?.source(cst));
    const body = if (function.body(cst)) |body| try lowerStatement(body, arena, cst) else blk: {
        try diagnostics.emit(.{
            .level = .@"error",
            .message = "function has no body",
            .span = function.syntax.source(cst),
        });
        break :blk .@"error";
    };
    return .{
        .name = name,
        .parameter_count = 2,
        .body = body,
    };
}

fn lowerStatement(
    statement: ast.Statement,
    arena: std.mem.Allocator,
    cst: Cst,
) !ir.Statement {
    return switch (statement) {
        .compound => |it| blk: {
            var iterator = it.statements(cst);
            const statements = try arena.alloc(ir.Statement, iterator.count(cst));
            var i: usize = 0;
            while (iterator.next(cst)) |s| : (i += 1) {
                statements[i] = try lowerStatement(s, arena, cst);
            }
            break :blk .{ .compound = statements };
        },
    };
}
