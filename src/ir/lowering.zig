const Cst = @import("../Cst.zig");
const ir = @import("../ir.zig");

pub fn lower(cst: Cst) ir.Program {
    _ = cst; // autofix
    return .{ .functions = &.{.{
        .name = "main",
        .parameter_count = 2,
        .body = .noop,
    }} };
}
