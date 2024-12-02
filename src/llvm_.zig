const std = @import("std");
const Signedness = std.builtin.Signedness;

pub const Context = opaque {
    pub const init = LLVMContextCreate;
    extern fn LLVMContextCreate() *Context;

    pub const deinit = LLVMContextDispose;
    extern fn LLVMContextDispose(*Context) void;
};

pub const Module = opaque {
    pub fn init(context: *Context) *Module {
        return LLVMModuleCreateWithNameInContext(null, context);
    }
    extern fn LLVMModuleCreateWithNameInContext(?[*:0]const u8, *Context) *Module;

    pub const deinit = LLVMDisposeModule;
    extern fn LLVMDisposeModule(*Module) void;

    pub const setTarget = LLVMSetTarget;
    extern fn LLVMSetTarget(*Module, [*:0]const u8) void;

    pub fn verify(self: *Module) void {
        _ = LLVMVerifyModule(self, .abort_process);
    }
    extern fn LLVMVerifyModule(*Module, VerifierFailureAction) c_int;

    pub fn write(self: *Module, path: [*:0]const u8) error{FailedToWriteBitcode}!void {
        if (LLVMWriteBitcodeToFile(self, path) != 0) return error.FailedToWriteBitcode;
    }
    extern fn LLVMWriteBitcodeToFile(*Module, [*:0]const u8) c_int;
};

const VerifierFailureAction = enum(c_int) {
    abort_process = 0,
};

pub const Function = opaque {
    pub const init = LLVMAddFunction;
    extern fn LLVMAddFunction(*Module, [*:0]const u8, *Type) *Function;

    pub fn appendBasicBlock(self: *Function) *BasicBlock {
        return LLVMAppendBasicBlock(self, "");
    }
    extern fn LLVMAppendBasicBlock(*Function, [*:0]const u8) *BasicBlock;
};

pub const Type = opaque {
    pub const int64 = LLVMInt64TypeInContext;
    extern fn LLVMInt64TypeInContext(*Context) *Type;

    pub const double = LLVMDoubleTypeInContext;
    extern fn LLVMDoubleTypeInContext(*Context) *Type;

    pub fn pointer(context: *Context, options: struct { address_space: c_uint }) *Type {
        return LLVMPointerTypeInContext(context, options.address_space);
    }
    extern fn LLVMPointerTypeInContext(*Context, c_uint) *Type;

    pub fn function(parameters: []const *Type, return_type: *Type) *Type {
        const parameter_count = std.math.cast(c_uint, parameters.len) orelse
            @panic("too many parameters");
        return LLVMFunctionType(return_type, parameters.ptr, parameter_count, false);
    }
    extern fn LLVMFunctionType(*Type, [*]const *Type, c_uint, is_variadic: bool) *Type;
};

pub const BasicBlock = opaque {};

pub const Value = opaque {
    pub fn int(int_type: *Type, value: c_ulonglong, signedness: Signedness) *Value {
        return LLVMConstInt(int_type, value, @intFromBool(signedness == .signed));
    }
    extern fn LLVMConstInt(*Type, c_ulonglong, c_int) *Value;
};

pub const Builder = opaque {
    pub const init = LLVMCreateBuilderInContext;
    extern fn LLVMCreateBuilderInContext(*Context) *Builder;

    pub const deinit = LLVMDisposeBuilder;
    extern fn LLVMDisposeBuilder(*Builder) void;

    pub const positionAtEnd = LLVMPositionBuilderAtEnd;
    extern fn LLVMPositionBuilderAtEnd(*Builder, *BasicBlock) void;

    pub fn add(self: *Builder, lhs: *Value, rhs: *Value) *Value {
        return LLVMBuildAdd(self, lhs, rhs, "");
    }
    extern fn LLVMBuildAdd(*Builder, *Value, *Value, [*:0]const u8) *Value;

    pub fn fAdd(self: *Builder, lhs: *Value, rhs: *Value) *Value {
        return LLVMBuildFAdd(self, lhs, rhs, "");
    }
    extern fn LLVMBuildFAdd(*Builder, *Value, *Value, [*:0]const u8) *Value;

    pub fn sub(self: *Builder, lhs: *Value, rhs: *Value) *Value {
        return LLVMBuildSub(self, lhs, rhs, "");
    }
    extern fn LLVMBuildSub(*Builder, *Value, *Value, [*:0]const u8) *Value;

    pub fn fSub(self: *Builder, lhs: *Value, rhs: *Value) *Value {
        return LLVMBuildFSub(self, lhs, rhs, "");
    }
    extern fn LLVMBuildFSub(*Builder, *Value, *Value, [*:0]const u8) *Value;

    pub fn mul(self: *Builder, lhs: *Value, rhs: *Value) *Value {
        return LLVMBuildMul(self, lhs, rhs, "");
    }
    extern fn LLVMBuildMul(*Builder, *Value, *Value, [*:0]const u8) *Value;

    pub fn fMul(self: *Builder, lhs: *Value, rhs: *Value) *Value {
        return LLVMBuildFMul(self, lhs, rhs, "");
    }
    extern fn LLVMBuildFMul(*Builder, *Value, *Value, [*:0]const u8) *Value;

    pub fn sDiv(self: *Builder, lhs: *Value, rhs: *Value) *Value {
        return LLVMBuildSDiv(self, lhs, rhs, "");
    }
    extern fn LLVMBuildSDiv(*Builder, *Value, *Value, [*:0]const u8) *Value;

    pub fn fDiv(self: *Builder, lhs: *Value, rhs: *Value) *Value {
        return LLVMBuildFDiv(self, lhs, rhs, "");
    }
    extern fn LLVMBuildFDiv(*Builder, *Value, *Value, [*:0]const u8) *Value;

    pub fn sRem(self: *Builder, lhs: *Value, rhs: *Value) *Value {
        return LLVMBuildSRem(self, lhs, rhs, "");
    }
    extern fn LLVMBuildSRem(*Builder, *Value, *Value, [*:0]const u8) *Value;

    pub fn shl(self: *Builder, lhs: *Value, rhs: *Value) *Value {
        return LLVMBuildShl(self, lhs, rhs, "");
    }
    extern fn LLVMBuildShl(*Builder, *Value, *Value, [*:0]const u8) *Value;

    pub fn lShr(self: *Builder, lhs: *Value, rhs: *Value) *Value {
        return LLVMBuildLShr(self, lhs, rhs, "");
    }
    extern fn LLVMBuildLShr(*Builder, *Value, *Value, [*:0]const u8) *Value;

    pub fn @"and"(self: *Builder, lhs: *Value, rhs: *Value) *Value {
        return LLVMBuildAnd(self, lhs, rhs, "");
    }
    extern fn LLVMBuildAnd(*Builder, *Value, *Value, [*:0]const u8) *Value;

    pub fn @"or"(self: *Builder, lhs: *Value, rhs: *Value) *Value {
        return LLVMBuildOr(self, lhs, rhs, "");
    }
    extern fn LLVMBuildOr(*Builder, *Value, *Value, [*:0]const u8) *Value;

    pub fn xor(self: *Builder, lhs: *Value, rhs: *Value) *Value {
        return LLVMBuildXor(self, lhs, rhs, "");
    }
    extern fn LLVMBuildXor(*Builder, *Value, *Value, [*:0]const u8) *Value;

    pub fn neg(self: *Builder, operand: *Value) *Value {
        return LLVMBuildNeg(self, operand, "");
    }
    extern fn LLVMBuildNeg(*Builder, *Value, [*:0]const u8) *Value;

    pub fn fNeg(self: *Builder, operand: *Value) *Value {
        return LLVMBuildFNeg(self, operand, "");
    }
    extern fn LLVMBuildFNeg(*Builder, *Value, [*:0]const u8) *Value;

    pub fn not(self: *Builder, operand: *Value) *Value {
        return LLVMBuildNot(self, operand, "");
    }
    extern fn LLVMBuildNot(*Builder, *Value, [*:0]const u8) *Value;

    pub fn store(self: *Builder, options: struct { value: *Value, to: *Value }) *Value {
        return LLVMBuildStore(self, options.value, options.to, "");
    }
    extern fn LLVMBuildStore(*Builder, *Value, *Value, [*:0]const u8) *Value;

    pub fn zExt(self: *Builder, operand: *Value, dest_type: *Type) *Value {
        return LLVMBuildZExt(self, operand, dest_type, "");
    }
    extern fn LLVMBuildZExt(*Builder, *Value, *Type, [*:0]const u8) *Value;

    pub fn fpToSi(self: *Builder, operand: *Value, dest_type: *Type) *Value {
        return LLVMBuildFPToSI(self, operand, dest_type, "");
    }
    extern fn LLVMBuildFPToSI(*Builder, *Value, *Type, [*:0]const u8) *Value;

    pub fn siToFp(self: *Builder, operand: *Value, dest_type: *Type) *Value {
        return LLVMBuildSIToFP(self, operand, dest_type, "");
    }
    extern fn LLVMBuildSIToFP(*Builder, *Value, *Type, [*:0]const u8) *Value;

    pub fn intToPtr(self: *Builder, operand: *Value, dest_type: *Type) *Value {
        return LLVMBuildIntToPtr(self, operand, dest_type, "");
    }
    extern fn LLVMBuildIntToPtr(*Builder, *Value, *Type, [*:0]const u8) *Value;

    pub fn bitCast(self: *Builder, operand: *Value, dest_type: *Type) *Value {
        return LLVMBuildBitCast(self, operand, dest_type, "");
    }
    extern fn LLVMBuildBitCast(*Builder, *Value, *Type, [*:0]const u8) *Value;

    pub fn iCmp(self: *Builder, op: IntPredicate, lhs: *Value, rhs: *Value) *Value {
        return LLVMBuildICmp(self, op, lhs, rhs, "");
    }
    extern fn LLVMBuildICmp(*Builder, IntPredicate, *Value, *Value, [*:0]const u8) *Value;

    pub fn fCmp(self: *Builder, op: RealPredicate, lhs: *Value, rhs: *Value) *Value {
        return LLVMBuildFCmp(self, op, lhs, rhs, "");
    }
    extern fn LLVMBuildFCmp(*Builder, RealPredicate, *Value, *Value, [*:0]const u8) *Value;
};

pub const IntPredicate = enum(c_int) {
    eq,
    ne,
    ugt,
    uge,
    ult,
    ule,
    sgt,
    sge,
    slt,
    sle,
};

pub const RealPredicate = enum(c_int) {
    false,
    oeq,
    ogt,
    oge,
    olt,
    ole,
    one,
    ord,
    uno,
    ueq,
    ugt,
    uge,
    ult,
    ule,
    une,
    true,
};
