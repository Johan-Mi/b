source_code: []const u8,

pub fn init(source_code: []const u8) Lexer {
    return .{ .source_code = source_code };
}

pub fn next(lexer: *Lexer) ?Token {
    const token = lexer.nextWithoutConsuming() orelse return null;
    lexer.source_code = lexer.source_code[token.source.len..];
    return token;
}

fn nextWithoutConsuming(lexer: *Lexer) ?Token {
    if (lexer.source_code.len == 0) return null;
    if (lexer.skipTrivia()) |trivia| return trivia;

    inline for (symbols) |symbol| {
        if (std.mem.startsWith(u8, lexer.source_code, symbol.text))
            return lexer.makeToken(symbol.text.len, @fromBackingInt(@intCast(symbol.raw)));
    } else if (nonZero(std.mem.indexOfNone(u8, lexer.source_code, identifier_chars) orelse lexer.source_code.len)) |token_len| {
        const text = lexer.source_code[0..token_len];
        const kind: SyntaxKind = keywords.get(text) orelse
            if (std.ascii.isDigit(lexer.source_code[0])) .number else .identifier;
        return lexer.makeToken(token_len, kind);
    } else switch (lexer.source_code[0]) {
        '"', '\'', '`' => {
            const quote = lexer.source_code[0];
            const kind: SyntaxKind = switch (quote) {
                '"' => .string_literal,
                '\'' => .character_literal,
                '`' => .bcd_literal,
                else => unreachable,
            };
            const token_len = if (std.mem.indexOfScalarPos(u8, lexer.source_code, 1, quote)) |end|
                end + 1
            else
                lexer.source_code.len;
            return lexer.makeToken(token_len, kind);
        },
        else => {
            const token_len = std.mem.indexOfAny(u8, lexer.source_code, all_valid_chars) orelse lexer.source_code.len;
            return lexer.makeToken(token_len, .@"error");
        },
    }
}

fn skipTrivia(lexer: *Lexer) ?Token {
    std.debug.assert(lexer.source_code.len != 0);
    var state: enum { normal, start_of_comment, comment, end_of_comment } = .normal;
    return for (0.., lexer.source_code) |i, c| {
        switch (state) {
            .normal => {
                if (std.ascii.isWhitespace(c)) continue;
                if (std.mem.startsWith(u8, lexer.source_code[i..], "/*")) {
                    state = .start_of_comment;
                    continue;
                }
                break if (i == 0) null else lexer.makeToken(i, .trivia);
            },
            // Skip the asterisk
            .start_of_comment => state = .comment,
            .comment => {
                if (std.mem.startsWith(u8, lexer.source_code[i..], "*/"))
                    state = .end_of_comment;
            },
            // Skip the slash
            .end_of_comment => state = .normal,
        }
    } else lexer.makeToken(lexer.source_code.len, .trivia);
}

fn makeToken(lexer: Lexer, len: usize, kind: SyntaxKind) Token {
    std.debug.assert(len != 0);
    return .{ .kind = kind, .source = lexer.source_code[0..len] };
}

pub const Token = struct {
    kind: SyntaxKind,
    source: []const u8,
};

const identifier_chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._";
const all_valid_chars = identifier_chars ++ "!\"#%&'()*+,-/:;<=>?@[]^`{|}";

const keywords: std.StaticStringMap(SyntaxKind) = blk: {
    const prefix = "kw_";
    const syntax_kinds = @typeInfo(SyntaxKind).@"enum".field_names;
    var array: [syntax_kinds.len]struct { []const u8, SyntaxKind } = undefined;
    var len = 0;
    for (syntax_kinds, 0..) |kind, i| {
        if (std.mem.cutPrefix(u8, kind, prefix)) |keyword| {
            array[len] = .{ keyword, @fromBackingInt(@intCast(i)) };
            len += 1;
        }
    }
    break :blk .initComptime(array[0..len]);
};

const symbols = blk: {
    @setEvalBranchQuota(7000);

    const syntax_kinds = @typeInfo(SyntaxKind).@"enum".field_names;
    var array: [syntax_kinds.len]struct { text: []const u8, raw: comptime_int } = undefined;
    var len = 0;
    for (syntax_kinds, 0..) |kind, i| {
        if (std.mem.indexOfAny(u8, kind, identifier_chars) == null) {
            array[len] = .{ .text = kind, .raw = i };
            len += 1;
        }
    }
    break :blk array[0..len].*;
};

fn nonZero(n: anytype) ?@TypeOf(n) {
    return if (n == 0) null else n;
}

test "fuzz lexer" {
    try std.testing.fuzz({}, fuzzLexer, .{});
}

fn fuzzLexer(_: void, smith: *std.testing.Smith) !void {
    var buffer: [1024]u8 = undefined;
    var input_bytes = buffer[0..smith.slice(&buffer)];
    var lexer = init(input_bytes);

    // Token stream must match input.
    while (lexer.next()) |token| {
        try std.testing.expectEqual(input_bytes.ptr, token.source.ptr);
        input_bytes = input_bytes[token.source.len..];
    }
    try std.testing.expectEqualStrings("", input_bytes);
}

const Lexer = @This();

const std = @import("std");
const SyntaxKind = @import("syntax.zig").Kind;
