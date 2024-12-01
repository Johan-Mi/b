const std = @import("std");

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

    pub fn function(parameters: []const *Type, return_type: *Type) *Type {
        const parameter_count = std.math.cast(c_uint, parameters.len) orelse
            @panic("too many parameters");
        return LLVMFunctionType(return_type, parameters.ptr, parameter_count, false);
    }
    extern fn LLVMFunctionType(*Type, [*]const *Type, c_uint, is_variadic: bool) *Type;
};

pub const BasicBlock = opaque {};

pub const Value = opaque {};

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
};
