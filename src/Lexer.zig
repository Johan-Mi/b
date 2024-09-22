const Diagnostic = @import("Diagnostic.zig");
const std = @import("std");

source_code: []const u8,
token_stream: TokenStream = .{},
diagnostics: *Diagnostic.S,
gpa: std.mem.Allocator,

pub fn lex(
    source_code: []const u8,
    diagnostics: *Diagnostic.S,
    gpa: std.mem.Allocator,
) !TokenStream {
    var self = @This(){
        .source_code = source_code,
        .diagnostics = diagnostics,
        .gpa = gpa,
    };
    errdefer self.token_stream.deinit(gpa);

    while (true) {
        try self.skipTrivia();
        if (self.source_code.len == 0) break;

        inline for (symbols) |symbol| {
            if (std.mem.startsWith(u8, self.source_code, symbol.text)) {
                try self.put(symbol.text.len, @enumFromInt(symbol.raw));
                break;
            }
        } else if (nonZero(std.mem.indexOfNone(u8, self.source_code, identifier_chars) orelse self.source_code.len)) |token_len| {
            try self.put(token_len, .identifier_or_number);
        } else if (nonZero(std.mem.indexOfAny(u8, self.source_code, all_valid_chars) orelse self.source_code.len)) |token_len| {
            // TODO: where?
            const message = if (token_len == 1) "invalid byte" else "invalid bytes";
            try self.diagnostics.@"error"(message);
            try self.put(token_len, .@"error");
        } else {
            // TODO: lex string literals
            unreachable;
        }
    }

    return self.token_stream;
}

fn skipTrivia(self: *@This()) !void {
    const State = enum { normal, comment, end_of_comment };

    var state: State = .normal;
    for (0.., self.source_code) |i, c| {
        switch (state) {
            .normal => {
                if (std.ascii.isWhitespace(c)) continue;
                if (std.mem.startsWith(u8, self.source_code[i..], "/*")) {
                    state = .comment;
                    continue;
                }

                if (i != 0) try self.put(i, .trivia);
                break;
            },
            .comment => {
                if (std.mem.startsWith(u8, self.source_code[i..], "*/"))
                    state = .end_of_comment;
            },
            // Skip the slash
            .end_of_comment => state = .normal,
        }
    } else {
        if (state != .normal) // TODO: where?
            try self.diagnostics.@"error"("unterminated comment");
        if (self.source_code.len != 0)
            try self.put(self.source_code.len, .trivia);
    }
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

    identifier_or_number,

    trivia,
    @"error",
    eof,
};

const identifier_chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._";
const all_valid_chars = identifier_chars ++ "!#%&()*+,-/:;<=>?@[]^{|}";

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
    var diagnostics = Diagnostic.S.init(gpa);
    defer diagnostics.deinit();
    const tokens = try lex(input_bytes, &diagnostics, gpa);
    defer tokens.deinit(gpa);

    // Token stream must match input.
    for (tokens.tokens.items(.source)) |token| {
        try std.testing.expectStringStartsWith(input_bytes, token);
        input_bytes = input_bytes[token.len..];
    }
    try std.testing.expectEqualStrings("", input_bytes);
}
