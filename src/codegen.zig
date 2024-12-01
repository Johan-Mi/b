const builtin = @import("builtin");
const ir = @import("ir.zig");
const llvm = @import("llvm_.zig");
const std = @import("std");

pub fn compile(program: ir.Program, output_path: [*:0]const u8) !void {
    const context: *llvm.Context = .init();
    defer context.deinit();

    const module: *llvm.Module = .init(context);
    defer module.deinit();
    module.setTarget("x86_64-unknown-linux-gnu");

    const word_type: *llvm.Type = .int64(context);

    const builder: *llvm.Builder = .init(context);
    defer builder.deinit();

    for (program.functions) |function| compileFunction(function, module, builder, word_type);

    switch (builtin.mode) {
        .Debug, .ReleaseSafe => module.verify(),
        .ReleaseFast, .ReleaseSmall => {},
    }

    try module.write(output_path);
}

fn compileFunction(
    function: ir.Function,
    module: *llvm.Module,
    builder: *llvm.Builder,
    word_type: *llvm.Type,
) void {
    const max_parameters = std.math.maxInt(@TypeOf(function.parameter_count));
    const all_parameters: [max_parameters]*llvm.Type = @splat(word_type);
    const parameters = all_parameters[0..function.parameter_count];
    const return_type = word_type;
    const signature: *llvm.Type = .function(parameters, return_type);
    const l_function: *llvm.Function = .init(module, function.name, signature);
    _ = l_function; // autofix
    compileStatement(function.body, builder);
}

fn compileStatement(statement: ir.Statement, builder: *llvm.Builder) void {
    switch (statement) {
        .compound => |it| for (it) |s| compileStatement(s, builder),
        .expression => |it| _ = compileExpression(it, builder),
        .@"error" => unreachable,
    }
}

fn compileExpression(expression: ir.Expression, builder: *llvm.Builder) *llvm.Value {
    return switch (expression) {
        .infix => |it| blk: {
            const lhs = compileExpression(it.lhs.*, builder);
            const rhs = compileExpression(it.rhs.*, builder);
            break :blk switch (it.operator) {
                .@"=" => @panic("="),
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
                .@"==" => @panic("=="),
                .@"!=" => @panic("!="),
                .@"<" => @panic("<"),
                .@"<=" => @panic("<="),
                .@">" => @panic(">"),
                .@">=" => @panic(">="),
                .@"#==" => @panic("#=="),
                .@"#!=" => @panic("#!="),
                .@"#<" => @panic("#<"),
                .@"#<=" => @panic("#<="),
                .@"#>" => @panic("#>"),
                .@"#>=" => @panic("#>="),
                .@"+" => builder.add(lhs, rhs),
                .@"-" => @panic("-"),
                .@"#+" => @panic("#+"),
                .@"#-" => @panic("#-"),
                .@"*" => @panic("*"),
                .@"/" => @panic("/"),
                .@"%" => @panic("%"),
                .@"#*" => @panic("#*"),
                .@"#/" => @panic("#/"),
                .@"|" => @panic("|"),
                .@"^" => @panic("^"),
                .@"&" => @panic("&"),
                .@"<<" => @panic("<<"),
                .@">>" => @panic(">>"),
                else => unreachable,
            };
        },
        .@"error" => unreachable,
    };
}
