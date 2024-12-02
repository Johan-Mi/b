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
    const float_type: *llvm.Type = .double(context);
    const pointer_type: *llvm.Type = .pointer(context, .{ .address_space = 0 });

    const builder: *llvm.Builder = .init(context);
    defer builder.deinit();

    for (program.functions) |function| {
        compileFunction(function, module, builder, word_type, float_type, pointer_type);
    }

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
    float_type: *llvm.Type,
    pointer_type: *llvm.Type,
) void {
    const max_parameters = std.math.maxInt(@TypeOf(function.parameter_count));
    const all_parameters: [max_parameters]*llvm.Type = @splat(word_type);
    const parameters = all_parameters[0..function.parameter_count];
    const return_type = word_type;
    const signature: *llvm.Type = .function(parameters, return_type);
    const l_function: *llvm.Function = .init(module, function.name, signature);
    const entry = l_function.appendBasicBlock();
    builder.positionAtEnd(entry);
    compileStatement(function.body, builder, word_type, float_type, pointer_type);
}

fn compileStatement(
    statement: ir.Statement,
    builder: *llvm.Builder,
    word_type: *llvm.Type,
    float_type: *llvm.Type,
    pointer_type: *llvm.Type,
) void {
    switch (statement) {
        .compound => |it| for (it) |s| compileStatement(
            s,
            builder,
            word_type,
            float_type,
            pointer_type,
        ),
        .expression => |it| _ = compileExpression(
            it,
            builder,
            word_type,
            float_type,
            pointer_type,
        ),
        .@"error" => unreachable,
    }
}

fn compileExpression(
    expression: ir.Expression,
    builder: *llvm.Builder,
    word_type: *llvm.Type,
    float_type: *llvm.Type,
    pointer_type: *llvm.Type,
) *llvm.Value {
    return switch (expression) {
        .prefix => |it| blk: {
            const operand = compileExpression(
                it.operand.*,
                builder,
                word_type,
                float_type,
                pointer_type,
            );
            break :blk switch (it.operator) {
                .@"#" => builder.bitCast(builder.siToFp(operand, float_type), word_type),
                .@"##" => builder.fpToSi(builder.bitCast(operand, float_type), word_type),
                .@"~" => builder.not(operand),
                .@"-" => builder.neg(operand),
                .@"#-" => builder.bitCast(
                    builder.fNeg(builder.bitCast(operand, float_type)),
                    word_type,
                ),
                .@"!" => builder.zExt(
                    builder.iCmp(.eq, operand, .int(word_type, 0, .signed)),
                    word_type,
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
            const lhs = compileExpression(
                it.lhs.*,
                builder,
                word_type,
                float_type,
                pointer_type,
            );
            const rhs = compileExpression(
                it.rhs.*,
                builder,
                word_type,
                float_type,
                pointer_type,
            );
            break :blk switch (it.operator) {
                .@"=" => {
                    _ = builder.store(.{ .value = rhs, .to = builder.intToPtr(lhs, pointer_type) });
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
                .@"==" => builder.zExt(builder.iCmp(.eq, lhs, rhs), word_type),
                .@"!=" => builder.zExt(builder.iCmp(.ne, lhs, rhs), word_type),
                .@"<" => builder.zExt(builder.iCmp(.slt, lhs, rhs), word_type),
                .@"<=" => builder.zExt(builder.iCmp(.sle, lhs, rhs), word_type),
                .@">" => builder.zExt(builder.iCmp(.sgt, lhs, rhs), word_type),
                .@">=" => builder.zExt(builder.iCmp(.sge, lhs, rhs), word_type),
                .@"#==" => builder.zExt(builder.fCmp(
                    .oeq,
                    builder.bitCast(lhs, float_type),
                    builder.bitCast(rhs, float_type),
                ), word_type),
                .@"#!=" => builder.zExt(builder.fCmp(
                    .one,
                    builder.bitCast(lhs, float_type),
                    builder.bitCast(rhs, float_type),
                ), word_type),
                .@"#<" => builder.zExt(builder.fCmp(
                    .olt,
                    builder.bitCast(lhs, float_type),
                    builder.bitCast(rhs, float_type),
                ), word_type),
                .@"#<=" => builder.zExt(builder.fCmp(
                    .ole,
                    builder.bitCast(lhs, float_type),
                    builder.bitCast(rhs, float_type),
                ), word_type),
                .@"#>" => builder.zExt(builder.fCmp(
                    .ogt,
                    builder.bitCast(lhs, float_type),
                    builder.bitCast(rhs, float_type),
                ), word_type),
                .@"#>=" => builder.zExt(builder.fCmp(
                    .oge,
                    builder.bitCast(lhs, float_type),
                    builder.bitCast(rhs, float_type),
                ), word_type),
                .@"+" => builder.add(lhs, rhs),
                .@"-" => builder.sub(lhs, rhs),
                .@"#+" => builder.bitCast(builder.fAdd(
                    builder.bitCast(lhs, float_type),
                    builder.bitCast(rhs, float_type),
                ), word_type),
                .@"#-" => builder.bitCast(builder.fSub(
                    builder.bitCast(lhs, float_type),
                    builder.bitCast(rhs, float_type),
                ), word_type),
                .@"*" => builder.mul(lhs, rhs),
                .@"/" => builder.sDiv(lhs, rhs),
                .@"%" => builder.sRem(lhs, rhs),
                .@"#*" => builder.bitCast(builder.fMul(
                    builder.bitCast(lhs, float_type),
                    builder.bitCast(rhs, float_type),
                ), word_type),
                .@"#/" => builder.bitCast(builder.fDiv(
                    builder.bitCast(lhs, float_type),
                    builder.bitCast(rhs, float_type),
                ), word_type),
                .@"|" => builder.@"or"(lhs, rhs),
                .@"^" => builder.xor(lhs, rhs),
                .@"&" => builder.@"and"(lhs, rhs),
                .@"<<" => builder.shl(lhs, rhs),
                .@">>" => builder.lShr(lhs, rhs),
                else => unreachable,
            };
        },
        .@"error" => unreachable,
    };
}
