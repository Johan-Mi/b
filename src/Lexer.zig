const std = @import("std");
const SyntaxKind = @import("syntax.zig").Kind;

source_code: []const u8,

pub fn init(source_code: []const u8) @This() {
    return .{ .source_code = source_code };
}

pub fn next(self: *@This()) ?Token {
    const token = self.nextWithoutConsuming() orelse return null;
    self.source_code = self.source_code[token.source.len..];
    return token;
}

fn nextWithoutConsuming(self: *@This()) ?Token {
    if (self.source_code.len == 0) return null;
    if (self.skipTrivia()) |trivia| return trivia;

    inline for (symbols) |symbol| {
        if (std.mem.startsWith(u8, self.source_code, symbol.text))
            return self.makeToken(symbol.text.len, @enumFromInt(symbol.raw));
    } else if (nonZero(std.mem.indexOfNone(u8, self.source_code, identifier_chars) orelse self.source_code.len)) |token_len| {
        const text = self.source_code[0..token_len];
        const kind: SyntaxKind = keywords.get(text) orelse
            if (std.ascii.isDigit(self.source_code[0])) .number else .identifier;
        return self.makeToken(token_len, kind);
    } else switch (self.source_code[0]) {
        '"', '\'', '`' => {
            const quote = self.source_code[0];
            const kind: SyntaxKind = switch (quote) {
                '"' => .string_literal,
                '\'' => .character_literal,
                '`' => .bcd_literal,
                else => unreachable,
            };
            const token_len = if (std.mem.indexOfScalarPos(u8, self.source_code, 1, quote)) |end|
                end + 1
            else
                self.source_code.len;
            return self.makeToken(token_len, kind);
        },
        else => {
            const token_len = std.mem.indexOfAny(u8, self.source_code, all_valid_chars) orelse self.source_code.len;
            return self.makeToken(token_len, .@"error");
        },
    }
}

fn skipTrivia(self: *@This()) ?Token {
    std.debug.assert(self.source_code.len != 0);
    var state: enum { normal, start_of_comment, comment, end_of_comment } = .normal;
    return for (0.., self.source_code) |i, c| {
        switch (state) {
            .normal => {
                if (std.ascii.isWhitespace(c)) continue;
                if (std.mem.startsWith(u8, self.source_code[i..], "/*")) {
                    state = .start_of_comment;
                    continue;
                }
                break if (i == 0) null else self.makeToken(i, .trivia);
            },
            // Skip the asterisk
            .start_of_comment => state = .comment,
            .comment => {
                if (std.mem.startsWith(u8, self.source_code[i..], "*/"))
                    state = .end_of_comment;
            },
            // Skip the slash
            .end_of_comment => state = .normal,
        }
    } else self.makeToken(self.source_code.len, .trivia);
}

fn makeToken(self: @This(), len: usize, kind: SyntaxKind) Token {
    std.debug.assert(len != 0);
    return .{ .kind = kind, .source = self.source_code[0..len] };
}

pub const Token = struct {
    kind: SyntaxKind,
    source: []const u8,
};

const identifier_chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._";
const all_valid_chars = identifier_chars ++ "!\"#%&'()*+,-/:;<=>?@[]^`{|}";

const keywords = blk: {
    const prefix = "kw_";
    const syntax_kinds = @typeInfo(SyntaxKind).@"enum".fields;
    var array: [syntax_kinds.len]struct { []const u8, SyntaxKind } = undefined;
    var len = 0;
    for (syntax_kinds, 0..) |kind, i| {
        if (std.mem.startsWith(u8, kind.name, prefix)) {
            array[len] = .{ kind.name[prefix.len..], @enumFromInt(i) };
            len += 1;
        }
    }
    break :blk std.StaticStringMap(SyntaxKind).initComptime(array[0..len]);
};

const symbols = blk: {
    @setEvalBranchQuota(7000);

    const syntax_kinds = @typeInfo(SyntaxKind).@"enum".fields;
    var array: [syntax_kinds.len]struct { text: []const u8, raw: comptime_int } = undefined;
    var len = 0;
    for (syntax_kinds, 0..) |kind, i| {
        if (std.mem.indexOfAny(u8, kind.name, identifier_chars) == null) {
            array[len] = .{ .text = kind.name, .raw = i };
            len += 1;
        }
    }
    break :blk array[0..len].*;
};

fn nonZero(n: anytype) ?@TypeOf(n) {
    return if (n == 0) null else n;
}

test "fuzz lexer" {
    var input_bytes = std.testing.fuzzInput(.{});
    var lexer = init(input_bytes);

    // Token stream must match input.
    while (lexer.next()) |token| {
        try std.testing.expectEqual(input_bytes.ptr, token.source.ptr);
        input_bytes = input_bytes[token.source.len..];
    }
    try std.testing.expectEqualStrings("", input_bytes);
}
