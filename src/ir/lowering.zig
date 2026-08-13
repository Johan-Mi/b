pub fn lower(
    cst: Cst,
    arena: std.mem.Allocator,
    diagnostics: *Diagnostics,
) !ir.Program {
    const document = ast.Document.cast(.{ .index = .root, .cst = cst }).?;

    var iterator = document.functions();
    const functions = try arena.alloc(ir.Function, iterator.count());
    var i: usize = 0;
    while (iterator.next()) |function| : (i += 1) {
        functions[i] = try lowerFunction(function, arena, diagnostics);
    }

    return .{ .functions = functions };
}

fn lowerFunction(
    function: ast.Function,
    arena: std.mem.Allocator,
    diagnostics: *Diagnostics,
) !ir.Function {
    const name = try arena.dupeSentinel(u8, function.name().?.source(), 0);
    const body = if (function.body()) |body|
        try lowerStatement(body, arena, diagnostics)
    else blk: {
        try diagnostics.emit(.{
            .level = .@"error",
            .message = "function has no body",
            .span = function.syntax.source(),
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
    diagnostics: *Diagnostics,
) error{OutOfMemory}!ir.Statement {
    return switch (statement) {
        .auto, .extrn => .nop,
        .compound => |it| blk: {
            var iterator = it.statements();
            const statements = try arena.alloc(ir.Statement, iterator.count());
            var i: usize = 0;
            while (iterator.next()) |s| : (i += 1) {
                statements[i] = try lowerStatement(s, arena, diagnostics);
            }
            break :blk .{ .compound = statements };
        },
        .@"if" => |it| .{ .@"if" = .{
            .condition = try lowerExpressionOpt(it.condition(), arena, diagnostics),
            .body = try box(arena, try lowerStatementOpt(it.body(), arena, diagnostics)),
        } },
        .@"while" => |it| .{ .@"while" = .{
            .condition = try lowerExpressionOpt(it.condition(), arena, diagnostics),
            .body = try box(arena, try lowerStatementOpt(it.body(), arena, diagnostics)),
        } },
        .expression => |it| .{
            .expression = try lowerExpressionOpt(it.expression(), arena, diagnostics),
        },
    };
}

fn lowerStatementOpt(
    statement: ?ast.Statement,
    arena: std.mem.Allocator,
    diagnostics: *Diagnostics,
) !ir.Statement {
    return if (statement) |it| lowerStatement(it, arena, diagnostics) else .@"error";
}

fn lowerExpression(
    expression: ast.Expression,
    arena: std.mem.Allocator,
    diagnostics: *Diagnostics,
) error{OutOfMemory}!ir.Expression {
    return switch (expression) {
        .prefix => |it| .{ .prefix = .{
            .operator = it.operator().?.kind(),
            .operand = try box(arena, try lowerExpressionOpt(
                it.operand(),
                arena,
                diagnostics,
            )),
        } },
        .infix => |it| .{ .infix = .{
            .lhs = try box(arena, try lowerExpressionOpt(
                it.lhs(),
                arena,
                diagnostics,
            )),
            .operator = it.operator().?.kind(),
            .rhs = try box(arena, try lowerExpressionOpt(
                it.rhs().?.expression(),
                arena,
                diagnostics,
            )),
        } },
        .postfix => |it| .{ .postfix = .{
            .operator = it.operator().?.kind(),
            .operand = try box(arena, try lowerExpressionOpt(
                it.operand(),
                arena,
                diagnostics,
            )),
        } },
        .number => |it| if (std.fmt.parseInt(i64, it.syntax.source(), 10)) |n|
            .{ .number = n }
        else |_| blk: {
            try diagnostics.emit(.{
                .level = .@"error",
                .message = "integer literal is out of range",
                .span = it.syntax.source(),
            });
            break :blk .@"error";
        },
        .variable => |it| blk: {
            const token = it.identifier().?;
            if (Name.resolve(token)) |name| {
                break :blk .{ .variable = name };
            } else {
                try diagnostics.emit(.{
                    .level = .@"error",
                    .message = "undeclared identifier",
                    .span = token.source(),
                });
                break :blk .@"error";
            }
        },
        .parenthesized => |it| lowerExpressionOpt(it.inner(), arena, diagnostics),
    };
}

fn lowerExpressionOpt(
    expression: ?ast.Expression,
    arena: std.mem.Allocator,
    diagnostics: *Diagnostics,
) !ir.Expression {
    return if (expression) |it| lowerExpression(it, arena, diagnostics) else .@"error";
}

fn box(allocator: std.mem.Allocator, value: anytype) !*@TypeOf(value) {
    const slot = try allocator.create(@TypeOf(value));
    slot.* = value;
    return slot;
}

const ast = @import("../ast.zig");
const Cst = @import("../Cst.zig");
const Diagnostics = @import("../Diagnostic.zig").S;
const ir = @import("../ir.zig");
const Name = @import("../Name.zig");
const std = @import("std");
