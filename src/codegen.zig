pub fn compile(
    program: ir.Program,
    output_file: std.fs.File,
    arena: std.mem.Allocator,
) !void {
    var builder: llvm.Builder = try .init(.{ .allocator = arena });

    for (program.functions) |function| try compileFunction(function, &builder);

    const bitcode = try builder.toBitcode(arena, .{
        .name = "b",
        .version = .{ .major = 0, .minor = 0, .patch = 0 },
    });
    try output_file.writeAll(std.mem.sliceAsBytes(bitcode));
}

fn compileFunction(
    function: ir.Function,
    builder: *llvm.Builder,
) !void {
    const max_parameters = std.math.maxInt(@TypeOf(function.parameter_count));
    const all_parameters: [max_parameters]llvm.Builder.Type = @splat(.i64);
    const parameters = all_parameters[0..function.parameter_count];
    const return_type: llvm.Builder.Type = .i64;
    const signature = try builder.fnType(return_type, parameters, .normal);
    const l_function = try builder.addFunction(signature, .empty, .default);
    var wip_function: llvm.Builder.WipFunction = try .init(builder, .{
        .function = l_function,
        .strip = true,
    });
    const entry = try wip_function.block(0, "");
    wip_function.cursor = .{ .block = entry };
    try compileStatement(function.body, &wip_function);
}

fn compileStatement(
    statement: ir.Statement,
    function: *llvm.Builder.WipFunction,
) error{OutOfMemory}!void {
    switch (statement) {
        .compound => |it| for (it) |s| try compileStatement(s, function),
        .@"if" => |it| try compileIf(it.condition, it.body.*, function),
        .@"while" => |it| try compileWhile(it.condition, it.body.*, function),
        .expression => |it| _ = try compileExpression(it, function),
        .@"error" => unreachable,
    }
}

fn compileIf(
    condition: ir.Expression,
    body: ir.Statement,
    function: *llvm.Builder.WipFunction,
) !void {
    const l_condition = try compileExpression(condition, function);
    const then = try function.block(1, "");
    const after = try function.block(2, "");
    _ = try function.brCond(l_condition, then, after, .none);
    function.cursor = .{ .block = then };
    try compileStatement(body, function);
    _ = try function.br(after);
    function.cursor = .{ .block = after };
}

fn compileWhile(
    condition: ir.Expression,
    body: ir.Statement,
    function: *llvm.Builder.WipFunction,
) !void {
    const check = try function.block(2, "");
    _ = try function.br(check);
    function.cursor = .{ .block = check };
    const l_condition = try compileExpression(condition, function);
    const then = try function.block(1, "");
    const after = try function.block(1, "");
    _ = try function.brCond(l_condition, then, after, .none);
    function.cursor = .{ .block = then };
    try compileStatement(body, function);
    _ = try function.br(check);
    function.cursor = .{ .block = after };
}

fn compileExpression(
    expression: ir.Expression,
    function: *llvm.Builder.WipFunction,
) !llvm.Builder.Value {
    return switch (expression) {
        .prefix => |it| blk: {
            const operand = try compileExpression(it.operand.*, function);
            break :blk switch (it.operator) {
                .@"#" => function.cast(
                    .bitcast,
                    try function.cast(.sitofp, operand, .double, ""),
                    .i64,
                    "",
                ),
                .@"##" => function.cast(
                    .fptosi,
                    try function.cast(.bitcast, operand, .double, ""),
                    .i64,
                    "",
                ),
                .@"~" => function.not(operand, ""),
                .@"-" => function.neg(operand, ""),
                .@"#-" => function.cast(
                    .bitcast,
                    try function.un(.fneg, try function.cast(.bitcast, operand, .double, ""), ""),
                    .i64,
                    "",
                ),
                .@"!" => function.cast(
                    .zext,
                    try function.icmp(.eq, operand, .@"0", ""),
                    .i64,
                    "",
                ),
                .@"*" => @panic("*"),
                .@"&" => @panic("&"),
                .@"++" => @panic("++"),
                .@"--" => @panic("--"),
                .@"@" => @panic("@"),
                else => unreachable,
            };
        },
        .infix => |it| blk: {
            const lhs = try compileExpression(it.lhs.*, function);
            const rhs = try compileExpression(it.rhs.*, function);
            break :blk switch (it.operator) {
                .@"=" => {
                    const dest = try function.cast(.inttoptr, lhs, .ptr, "");
                    _ = try function.store(.normal, rhs, dest, .default);
                    break :blk rhs;
                },
                .@"*=" => @panic("*="),
                .@"/=" => @panic("/="),
                .@"%=" => @panic("%="),
                .@"+=" => @panic("+="),
                .@"-=" => @panic("-="),
                .@"<<=" => @panic("<<="),
                .@">>=" => @panic(">>="),
                .@"&=" => @panic("&="),
                .@"^=" => @panic("^="),
                .@"|=" => @panic("|="),
                .@"?" => @panic("?"),
                .@"||" => @panic("||"),
                .@"&&" => @panic("&&"),
                .@"==" => function.cast(.zext, try function.icmp(.eq, lhs, rhs, ""), .i64, ""),
                .@"!=" => function.cast(.zext, try function.icmp(.ne, lhs, rhs, ""), .i64, ""),
                .@"<" => function.cast(.zext, try function.icmp(.slt, lhs, rhs, ""), .i64, ""),
                .@"<=" => function.cast(.zext, try function.icmp(.sle, lhs, rhs, ""), .i64, ""),
                .@">" => function.cast(.zext, try function.icmp(.sgt, lhs, rhs, ""), .i64, ""),
                .@">=" => function.cast(.zext, try function.icmp(.sge, lhs, rhs, ""), .i64, ""),
                .@"#==" => function.cast(.zext, try function.fcmp(
                    .normal,
                    .oeq,
                    try function.cast(.bitcast, lhs, .double, ""),
                    try function.cast(.bitcast, rhs, .double, ""),
                    "",
                ), .i64, ""),
                .@"#!=" => function.cast(.zext, try function.fcmp(
                    .normal,
                    .one,
                    try function.cast(.bitcast, lhs, .double, ""),
                    try function.cast(.bitcast, rhs, .double, ""),
                    "",
                ), .i64, ""),
                .@"#<" => function.cast(.zext, try function.fcmp(
                    .normal,
                    .olt,
                    try function.cast(.bitcast, lhs, .double, ""),
                    try function.cast(.bitcast, rhs, .double, ""),
                    "",
                ), .i64, ""),
                .@"#<=" => function.cast(.zext, try function.fcmp(
                    .normal,
                    .ole,
                    try function.cast(.bitcast, lhs, .double, ""),
                    try function.cast(.bitcast, rhs, .double, ""),
                    "",
                ), .i64, ""),
                .@"#>" => function.cast(.zext, try function.fcmp(
                    .normal,
                    .ogt,
                    try function.cast(.bitcast, lhs, .double, ""),
                    try function.cast(.bitcast, rhs, .double, ""),
                    "",
                ), .i64, ""),
                .@"#>=" => function.cast(.zext, try function.fcmp(
                    .normal,
                    .oge,
                    try function.cast(.bitcast, lhs, .double, ""),
                    try function.cast(.bitcast, rhs, .double, ""),
                    "",
                ), .i64, ""),
                .@"+" => function.bin(.add, lhs, rhs, ""),
                .@"-" => function.bin(.sub, lhs, rhs, ""),
                .@"#+" => function.cast(.bitcast, try function.bin(
                    .fadd,
                    try function.cast(.bitcast, lhs, .double, ""),
                    try function.cast(.bitcast, rhs, .double, ""),
                    "",
                ), .i64, ""),
                .@"#-" => function.cast(.bitcast, try function.bin(
                    .fsub,
                    try function.cast(.bitcast, lhs, .double, ""),
                    try function.cast(.bitcast, rhs, .double, ""),
                    "",
                ), .i64, ""),
                .@"*" => function.bin(.mul, lhs, rhs, ""),
                .@"/" => function.bin(.sdiv, lhs, rhs, ""),
                .@"%" => function.bin(.srem, lhs, rhs, ""),
                .@"#*" => function.cast(.bitcast, try function.bin(
                    .fmul,
                    try function.cast(.bitcast, lhs, .double, ""),
                    try function.cast(.bitcast, rhs, .double, ""),
                    "",
                ), .i64, ""),
                .@"#/" => function.cast(.bitcast, try function.bin(
                    .fdiv,
                    try function.cast(.bitcast, lhs, .double, ""),
                    try function.cast(.bitcast, rhs, .double, ""),
                    "",
                ), .i64, ""),
                .@"|" => function.bin(.@"or", lhs, rhs, ""),
                .@"^" => function.bin(.xor, lhs, rhs, ""),
                .@"&" => function.bin(.@"and", lhs, rhs, ""),
                .@"<<" => function.bin(.shl, lhs, rhs, ""),
                .@">>" => function.bin(.lshr, lhs, rhs, ""),
                else => unreachable,
            };
        },
        .postfix => |it| blk: {
            const operand = try compileExpression(it.operand.*, function);
            _ = operand; // autofix
            break :blk switch (it.operator) {
                .@"++" => @panic("++"),
                .@"--" => @panic("--"),
                .@"[" => @panic("["),
                else => unreachable,
            };
        },
        .number => |it| function.builder.intValue(.i64, it),
        .variable => @panic("codegen variables"),
        .@"error" => unreachable,
    };
}

const builtin = @import("builtin");
const ir = @import("ir.zig");
const std = @import("std");
const llvm = std.zig.llvm;
