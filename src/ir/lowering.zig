const ast = @import("../ast.zig");
const Cst = @import("../Cst.zig");
const ir = @import("../ir.zig");
const std = @import("std");

pub fn lower(cst: Cst, arena: std.mem.Allocator) !ir.Program {
    const document = ast.Document.cast(.root, cst).?;

    var iterator = document.functions(cst);
    const functions = try arena.alloc(ir.Function, iterator.count(cst));
    var i: usize = 0;
    while (iterator.next(cst)) |function| : (i += 1) {
        functions[i] = try lowerFunction(function, cst, arena);
    }

    return .{ .functions = functions };
}

fn lowerFunction(function: ast.Function, cst: Cst, arena: std.mem.Allocator) !ir.Function {
    const name = try arena.dupeZ(u8, function.name(cst).?.source(cst));
    return .{
        .name = name,
        .parameter_count = 2,
        .body = .noop,
    };
}
