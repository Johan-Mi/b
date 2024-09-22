const std = @import("std");

pub fn lex(source_code: []const u8) !TokenStream {
    // TODO
    _ = source_code; // autofix
    return .{ .tokens = .{} };
}

const TokenStream = struct {
    tokens: std.MultiArrayList(Token),

    pub fn deinit(self: @This(), gpa: std.mem.Allocator) void {
        var tokens = self.tokens;
        tokens.deinit(gpa);
    }
};

const Token = struct {
    kind: SyntaxKind,
    source: []const u8,
};

const SyntaxKind = enum {
    eof,
};

test "fuzz lexer" {
    const input_bytes = std.testing.fuzzInput(.{});
    const tokens = try lex(input_bytes);
    defer tokens.deinit(std.testing.allocator);
}
