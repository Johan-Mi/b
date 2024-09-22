const std = @import("std");

source_code: []const u8,
token_stream: TokenStream = .{},
gpa: std.mem.Allocator,

pub fn lex(source_code: []const u8, gpa: std.mem.Allocator) !TokenStream {
    var self = @This(){ .source_code = source_code, .gpa = gpa };
    errdefer self.token_stream.deinit(gpa);

    while (true) {
        try self.skipTrivia();
        if (self.source_code.len == 0) break;

        // FIXME: lex things properly instead of only checking whitespace
        const token_len = std.mem.indexOfAny(u8, self.source_code, &std.ascii.whitespace) orelse self.source_code.len;
        try self.put(token_len, .@"error");
    }

    return self.token_stream;
}

fn skipTrivia(self: *@This()) !void {
    for (0.., self.source_code) |i, c| {
        // TODO: comments
        if (std.ascii.isWhitespace(c)) continue;

        if (i != 0) try self.put(i, .trivia);
        break;
    } else if (self.source_code.len != 0)
        try self.put(self.source_code.len, .trivia);
}

fn put(self: *@This(), len: usize, kind: SyntaxKind) !void {
    std.debug.assert(len != 0);
    try self.token_stream.tokens.append(self.gpa, .{
        .kind = kind,
        .source = self.source_code[0..len],
    });
    self.source_code = self.source_code[len..];
}

const TokenStream = struct {
    tokens: std.MultiArrayList(Token) = .{},

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
    trivia,
    @"error",
    eof,
};

test "fuzz lexer" {
    const input_bytes = std.testing.fuzzInput(.{});
    const tokens = try lex(input_bytes);
    defer tokens.deinit(std.testing.allocator);
}
