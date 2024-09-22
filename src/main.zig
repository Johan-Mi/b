const lexer = @import("lexer.zig");
const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const source_code = "this is some source code";
    const token_stream = try lexer.lex(source_code);
    defer token_stream.deinit(allocator);
}

test {
    std.testing.refAllDecls(@This());
}
