const Diagnostic = @import("Diagnostic.zig");
const std = @import("std");

source_code: []const u8,
diagnostics: *Diagnostic.S,

pub fn init(
    source_code: []const u8,
    diagnostics: *Diagnostic.S,
) @This() {
    return .{
        .source_code = source_code,
        .diagnostics = diagnostics,
    };
}

pub fn next(self: *@This()) !?Token {
    const token = try self.nextWithoutConsuming() orelse return null;
    self.source_code = self.source_code[token.source.len..];
    return token;
}

fn nextWithoutConsuming(self: *@This()) !?Token {
    if (try self.skipTrivia()) |trivia| return trivia;
    if (self.source_code.len == 0) return null;

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
            std.debug.assert(token_len != 0);
            const message = if (token_len == 1) "invalid byte" else "invalid bytes";
            try self.diagnostics.@"error"(message);
            return self.makeToken(token_len, .@"error");
        },
    }
}

fn skipTrivia(self: *@This()) !?Token {
    const State = enum { normal, start_of_comment, comment, end_of_comment };

    var state: State = .normal;
    for (0.., self.source_code) |i, c| {
        switch (state) {
            .normal => {
                if (std.ascii.isWhitespace(c)) continue;
                if (std.mem.startsWith(u8, self.source_code[i..], "/*")) {
                    state = .start_of_comment;
                    continue;
                }
                return if (i == 0) null else self.makeToken(i, .trivia);
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
    } else {
        if (state != .normal)
            try self.diagnostics.@"error"("unterminated comment");
        return if (self.source_code.len == 0)
            null
        else
            self.makeToken(self.source_code.len, .trivia);
    }
}

fn makeToken(self: @This(), len: usize, kind: SyntaxKind) Token {
    std.debug.assert(len != 0);
    return .{ .kind = kind, .source = self.source_code[0..len] };
}

const Token = struct {
    kind: SyntaxKind,
    source: []const u8,
};

const SyntaxKind = enum {
    kw_auto,
    kw_extrn,
    kw_if,
    kw_else,
    kw_for,
    kw_while,
    kw_repeat,
    kw_switch,
    kw_do,
    kw_return,
    kw_break,
    kw_goto,
    kw_next,
    kw_case,
    kw_default,

    @"~",
    @"}",
    @"||",
    @"|=",
    @"|",
    @"{",
    @"^=",
    @"^",
    @"]",
    @"[",
    @"@",
    @"?",
    @">>=",
    @">>",
    @">=",
    @">",
    @"==",
    @"=",
    @"<=",
    @"<<=",
    @"<<",
    @"<",
    @";",
    @"::",
    @":",
    @"/=",
    @"/",
    @"-=",
    @"--",
    @"-",
    @",",
    @"+=",
    @"++",
    @"+",
    @"*=",
    @"*",
    @")",
    @"(",
    @"&=",
    @"&&",
    @"&",
    @"%=",
    @"%",
    @"#>=",
    @"#>",
    @"#==",
    @"#<=",
    @"#<",
    @"#/",
    @"#-",
    @"#+",
    @"#*",
    @"##",
    @"#!=",
    @"#",
    @"!=",
    @"!",

    identifier,
    number,
    string_literal,
    character_literal,
    bcd_literal,

    trivia,
    @"error",
    eof,
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
    const gpa = std.testing.allocator;
    var string_arena = std.heap.ArenaAllocator.init(gpa);
    defer string_arena.deinit();
    var diagnostics = Diagnostic.S.init(gpa, string_arena.allocator());
    defer diagnostics.deinit();
    var lexer = init(input_bytes, &diagnostics);

    // Token stream must match input.
    while (try lexer.next()) |token| {
        try std.testing.expectStringStartsWith(input_bytes, token.source);
        input_bytes = input_bytes[token.source.len..];
    }
    try std.testing.expectEqualStrings("", input_bytes);
}
