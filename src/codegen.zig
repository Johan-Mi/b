const builtin = @import("builtin");
const llvm = @import("llvm_.zig");

pub fn compile(output_path: [*:0]const u8) !void {
    const context: *llvm.Context = .init();
    defer context.deinit();

    const module: *llvm.Module = .init(context);
    defer module.deinit();
    module.setTarget("x86_64-unknown-linux-gnu");

    switch (builtin.mode) {
        .Debug, .ReleaseSafe => module.verify(),
        .ReleaseFast, .ReleaseSmall => {},
    }

    try module.write(output_path);
}
