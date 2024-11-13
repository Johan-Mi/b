pub const Context = opaque {
    pub const init = LLVMContextCreate;
    extern fn LLVMContextCreate() *Context;

    pub const deinit = LLVMContextDispose;
    extern fn LLVMContextDispose(*Context) void;
};

pub const Module = opaque {
    pub fn init(context: *Context) *Module {
        return LLVMModuleCreateWithName(context, null);
    }
    extern fn LLVMModuleCreateWithName(*Context, ?[*:0]const u8) *Module;

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
