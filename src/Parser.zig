tokens: std.MultiArrayList(Token).Slice,
index: usize = 0,
cst: Cst.Builder,

pub fn parse(
    source: [*]const u8,
    tokens: std.MultiArrayList(Token).Slice,
    arena: std.mem.Allocator,
) !Cst {
    var p: Parser = .{ .tokens = tokens, .cst = .init(source, arena) };
    try p.cst.startNode(.document);
    while (!p.at(.eof))
        try p.parseTopLevelItem();
    try p.cst.finishNode();
    return p.cst.finish();
}

fn parseTopLevelItem(p: *Parser) !void {
    if (!p.at(.identifier))
        try p.@"error"()
    else switch (p.peekNth(1)) {
        .@"(" => try p.parseFunction(),
        .@";", .@"{", .@"[" => try p.parseGlobalDeclaration(),
        else => try p.@"error"(),
    }
}

fn parseGlobalDeclaration(p: *Parser) !void {
    std.debug.assert(p.at(.identifier));
    try p.startNode(.global_declaration);

    try p.bump();

    if (p.at(.@"[")) {
        try p.startNode(.vector_size);

        try p.bump();

        if (!try p.eat(.@"]")) {
            try p.parseExpression();
            _ = try p.eat(.@"]");
        }

        try p.cst.finishNode();
    }

    if (p.at(.@"{")) {
        try p.startNode(.vector_initializer);

        try p.bump();

        while (!p.at(.eof) and !try p.eat(.@"}")) {
            switch (p.peek()) {
                .@";" => break,
                .@"," => try p.bump(),
                else => try p.parseExpression(),
            }
        }

        try p.cst.finishNode();
    }

    _ = try p.eat(.@";");

    try p.cst.finishNode();
}

fn parseFunction(p: *Parser) !void {
    std.debug.assert(p.at(.identifier));
    try p.startNode(.function);

    try p.bump();
    try p.parseFunctionParameters();
    try p.parseStatement();

    try p.cst.finishNode();
}

fn parseFunctionParameters(p: *Parser) !void {
    std.debug.assert(p.at(.@"("));
    try p.startNode(.function_parameters);

    try p.bump();
    while (!p.at(.eof) and !try p.eat(.@")"))
        try p.@"error"();

    try p.cst.finishNode();
}

fn parseStatement(p: *Parser) error{OutOfMemory}!void {
    switch (p.peek()) {
        .@";" => try p.parseNullStatement(),
        .@"{" => try p.parseCompoundStatement(),
        .kw_auto => try p.parseAuto(),
        .kw_extrn => try p.parseExtrn(),
        .kw_if => try p.parseIf(),
        .kw_while => try p.parseWhile(),
        else => try p.parseExpressionStatement(),
    }
}

fn parseNullStatement(p: *Parser) !void {
    std.debug.assert(p.at(.@";"));
    try p.startNode(.null_statement);

    try p.bump();

    try p.cst.finishNode();
}

fn parseCompoundStatement(p: *Parser) !void {
    std.debug.assert(p.at(.@"{"));
    try p.startNode(.compound_statement);

    try p.bump();
    while (!p.at(.eof) and !try p.eat(.@"}"))
        try p.parseStatement();

    try p.cst.finishNode();
}

fn parseAuto(p: *Parser) !void {
    std.debug.assert(p.at(.kw_auto));
    try p.startNode(.auto);

    try p.bump();
    while (true) {
        switch (p.peek()) {
            .identifier, .@"," => try p.bump(),
            .@";" => {
                try p.bump();
                break;
            },
            else => break,
        }
    }

    try p.cst.finishNode();
}

fn parseExtrn(p: *Parser) !void {
    std.debug.assert(p.at(.kw_extrn));
    try p.startNode(.extrn);

    try p.bump();
    while (true) {
        switch (p.peek()) {
            .identifier, .@"," => try p.bump(),
            .@";" => {
                try p.bump();
                break;
            },
            else => break,
        }
    }

    try p.cst.finishNode();
}

fn parseIf(p: *Parser) !void {
    std.debug.assert(p.at(.kw_if));
    try p.startNode(.@"if");

    try p.bump();
    _ = try p.eat(.@"(");
    try p.parseExpression();
    _ = try p.eat(.@")");
    try p.parseStatement();

    try p.cst.finishNode();
}

fn parseWhile(p: *Parser) !void {
    std.debug.assert(p.at(.kw_while));
    try p.startNode(.@"while");

    try p.bump();
    _ = try p.eat(.@"(");
    try p.parseExpression();
    _ = try p.eat(.@")");
    try p.parseStatement();

    try p.cst.finishNode();
}

fn parseExpressionStatement(p: *Parser) !void {
    try p.startNode(.expression_statement);

    try p.parseExpression();
    _ = try p.eat(.@";");

    try p.cst.finishNode();
}

fn parseExpression(p: *Parser) error{OutOfMemory}!void {
    try p.parseExpressionRecursively(0);
}

fn parseAtom(p: *Parser) !void {
    switch (p.peek()) {
        .identifier => if (p.peekNth(1) == .@"(")
            try p.parseFunctionCall()
        else
            try p.parseVariable(),
        .number, .string_literal, .character_literal, .bcd_literal => {
            try p.bump();
        },
        .@"(" => try p.parseParenthesizedExpression(),
        else => try p.@"error"(),
    }
}

fn parseVariable(p: *Parser) !void {
    std.debug.assert(p.at(.identifier));
    try p.startNode(.variable);

    try p.bump();

    try p.cst.finishNode();
}

fn parseParenthesizedExpression(p: *Parser) !void {
    std.debug.assert(p.at(.@"("));
    try p.startNode(.parenthesized_expression);

    try p.bump();
    try p.parseExpression();
    _ = try p.eat(.@")");

    try p.cst.finishNode();
}

fn parseFunctionCall(p: *Parser) !void {
    std.debug.assert(p.at(.identifier));
    try p.startNode(.function_call);

    try p.bump();

    std.debug.assert(p.at(.@"("));
    try p.startNode(.arguments);

    try p.bump();
    while (!p.at(.eof) and !try p.eat(.@")")) {
        switch (p.peek()) {
            .@"," => try p.bump(),
            else => try p.parseExpression(),
        }
    }

    try p.cst.finishNode();
    try p.cst.finishNode();
}

fn parseExpressionRecursively(p: *Parser, bp_min: BindingPower) !void {
    const checkpoint = try p.makeCheckpoint();

    if (prefixBindingPower(p.peek())) |bp_right| {
        try p.startNode(.prefix_operation);
        try p.bump();
        try p.parseExpressionRecursively(bp_right);
        try p.cst.finishNode();
    } else try p.parseAtom();

    while (true) {
        const op = p.peek();
        if (postfixBindingPower(op)) |bp_left| {
            if (bp_left < bp_min) break;

            try p.bump();
            if (op == .@"[") {
                try p.parseExpression();
                _ = try p.eat(.@"]");
            }

            try p.cst.finishNodeAt(checkpoint, .postfix_operation);
        } else if (infixBindingPower(op)) |bp| {
            if (bp.left < bp_min) break;

            try p.bump();
            if (op == .@"?") {
                try p.parseExpression();
                _ = try p.eat(.@":");
            }
            try p.startNode(.rhs);
            try p.parseExpressionRecursively(bp.right);
            try p.cst.finishNode();

            try p.cst.finishNodeAt(checkpoint, .infix_operation);
        } else {
            break;
        }
    }
}

const BindingPower = u5;

pub fn prefixBindingPower(kind: SyntaxKind) ?BindingPower {
    return switch (kind) {
        .@"#", .@"##", .@"~", .@"-", .@"#-", .@"!", .@"*", .@"&", .@"++", .@"--", .@"@" => 23,
        else => null,
    };
}

pub fn postfixBindingPower(kind: SyntaxKind) ?BindingPower {
    return switch (kind) {
        .@"++", .@"--" => 23,
        .@"[" => 25,
        else => null,
    };
}

pub fn infixBindingPower(kind: SyntaxKind) ?struct { left: BindingPower, right: BindingPower } {
    return switch (kind) {
        .@"=",
        .@"*=",
        .@"/=",
        .@"%=",
        .@"+=",
        .@"-=",
        .@"<<=",
        .@">>=",
        .@"&=",
        .@"^=",
        .@"|=",
        => .{ .left = 2, .right = 1 },
        .@"?" => .{ .left = 4, .right = 3 },
        .@"||" => .{ .left = 5, .right = 6 },
        .@"&&" => .{ .left = 7, .right = 8 },
        .@"==",
        .@"!=",
        .@"<",
        .@"<=",
        .@">",
        .@">=",
        .@"#==",
        .@"#!=",
        .@"#<",
        .@"#<=",
        .@"#>",
        .@"#>=",
        => .{ .left = 9, .right = 10 },
        .@"+",
        .@"-",
        .@"#+",
        .@"#-",
        => .{ .left = 11, .right = 12 },
        .@"*",
        .@"/",
        .@"%",
        .@"#*",
        .@"#/",
        => .{ .left = 13, .right = 14 },
        .@"|" => .{ .left = 15, .right = 16 },
        .@"^" => .{ .left = 17, .right = 18 },
        .@"&" => .{ .left = 19, .right = 20 },
        .@"<<",
        .@">>",
        => .{ .left = 21, .right = 22 },
        else => null,
    };
}

fn @"error"(p: *Parser) !void {
    try p.startNode(.@"error");
    try p.parseAnything();
    try p.cst.finishNode();
}

fn parseAnything(p: *Parser) !void {
    switch (p.peek()) {
        .@"(" => {
            try p.bump();
            while (!p.at(.eof) and !try p.eat(.@")"))
                try p.parseAnything();
        },
        .@"{" => {
            try p.bump();
            while (!p.at(.eof) and !try p.eat(.@"}"))
                try p.parseAnything();
        },
        .@"[" => {
            try p.bump();
            while (!p.at(.eof) and !try p.eat(.@"]"))
                try p.parseAnything();
        },
        .@";" => try p.parseNullStatement(),
        .kw_auto => try p.parseAuto(),
        .kw_extrn => try p.parseExtrn(),
        .kw_if => try p.parseIf(),
        .kw_while => try p.parseWhile(),
        else => try p.bump(),
    }
}

fn bump(p: *Parser) !void {
    while (!p.at(.eof)) {
        const token = p.tokens.get(p.index);
        try p.cst.token(token.kind, token.source.len);
        p.index += 1;
        if (token.kind != .trivia) break;
    }
}

fn startNode(p: *Parser, kind: SyntaxKind) !void {
    try p.skipTrivia();
    try p.cst.startNode(kind);
}

fn makeCheckpoint(p: *Parser) !Cst.Builder.Checkpoint {
    try p.skipTrivia();
    return p.cst.makeCheckpoint();
}

fn skipTrivia(p: *Parser) !void {
    while (p.index < p.tokens.len) : (p.index += 1) {
        const token = p.tokens.get(p.index);
        if (token.kind != .trivia) break;
        try p.cst.token(token.kind, token.source.len);
    }
}

fn eat(p: *Parser, kind: SyntaxKind) !bool {
    if (p.at(kind)) {
        try p.bump();
        return true;
    } else return false;
}

fn at(p: *Parser, kind: SyntaxKind) bool {
    return p.peek() == kind;
}

fn peek(p: Parser) SyntaxKind {
    const kinds = p.tokens.items(.kind);
    const index = std.mem.indexOfNonePos(SyntaxKind, kinds, p.index, &.{.trivia}) orelse return .eof;
    return kinds[index];
}

fn peekNth(p: Parser, n: usize) SyntaxKind {
    var i: usize = 0;
    return for (p.tokens.items(.kind)[p.index..]) |kind| {
        if (kind == .trivia) continue;
        if (i == n) break kind;
        i += 1;
    } else .eof;
}

test "fuzz parser" {
    try std.testing.fuzz({}, fuzzParser, .{});
}

fn fuzzParser(_: void, smith: *std.testing.Smith) !void {
    var buffer: [1024]u8 = undefined;
    const input_bytes = buffer[0..smith.slice(&buffer)];
    var lexer: @import("Lexer.zig") = .init(input_bytes);
    var tokens: std.MultiArrayList(Token) = .empty;
    defer tokens.deinit(std.testing.allocator);

    while (lexer.next()) |token| {
        try tokens.append(std.testing.allocator, token);
    }

    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();

    _ = try parse(input_bytes.ptr, tokens.slice(), arena.allocator());
}

const Parser = @This();

const Cst = @import("Cst.zig");
const std = @import("std");
const SyntaxKind = @import("syntax.zig").Kind;
const Token = @import("Lexer.zig").Token;
