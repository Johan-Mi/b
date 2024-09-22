const Diagnostic = @import("Diagnostic.zig");
const lexer = @import("lexer.zig");
const std = @import("std");

pub fn main() !u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    var diagnostics = Diagnostic.S.init(allocator);
    defer diagnostics.deinit();

    realMain(allocator) catch |err| try diagnostics.@"error"(@errorName(err));

    try diagnostics.show();
    return @intFromBool(!diagnostics.is_ok());
}

fn realMain(allocator: std.mem.Allocator) !void {
    const source_code = "this is some source code";
    const token_stream = try lexer.lex(source_code);
    defer token_stream.deinit(allocator);
}

test {
    std.testing.refAllDecls(@This());
}
