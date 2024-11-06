const Cst = @import("Cst.zig");
const std = @import("std");
const SyntaxKind = @import("syntax.zig").Kind;
const Token = @import("Lexer.zig").Token;

tokens: std.MultiArrayList(Token).Slice,
index: usize = 0,
cst: Cst.Builder,

pub fn parse(tokens: std.MultiArrayList(Token).Slice, arena: std.mem.Allocator) !Cst {
    var self = @This(){ .tokens = tokens, .cst = .init(arena) };
    try self.cst.startNode(.document);
    while (!self.at(.eof))
        try self.parseTopLevelItem();
    try self.cst.finishNode();
    return self.cst.finish();
}

fn parseTopLevelItem(self: *@This()) !void {
    if (!self.at(.identifier))
        try self.@"error"()
    else switch (self.peekNth(1)) {
        .@"(" => try self.parseFunction(),
        .@";", .@"{", .@"[" => try self.parseGlobalDeclaration(),
        else => try self.@"error"(),
    }
}

fn parseGlobalDeclaration(self: *@This()) !void {
    std.debug.assert(self.at(.identifier));
    try self.startNode(.global_declaration);

    try self.bump();

    if (self.at(.@"[")) {
        try self.startNode(.vector_size);

        try self.bump();

        if (!try self.eat(.@"]")) {
            try self.parseExpression();
            _ = try self.eat(.@"]");
        }

        try self.cst.finishNode();
    }

    if (self.at(.@"{")) {
        try self.startNode(.vector_initializer);

        try self.bump();

        while (!self.at(.eof) and !try self.eat(.@"}")) {
            switch (self.peek()) {
                .@";" => break,
                .@"," => try self.bump(),
                else => try self.parseExpression(),
            }
        }

        try self.cst.finishNode();
    }

    _ = try self.eat(.@";");

    try self.cst.finishNode();
}

fn parseFunction(self: *@This()) !void {
    std.debug.assert(self.at(.identifier));
    try self.startNode(.function);

    try self.bump();
    try self.parseFunctionParameters();
    try self.parseStatement();

    try self.cst.finishNode();
}

fn parseFunctionParameters(self: *@This()) !void {
    std.debug.assert(self.at(.@"("));
    try self.startNode(.function_parameters);

    try self.bump();
    while (!self.at(.eof) and !try self.eat(.@")"))
        try self.@"error"();

    try self.cst.finishNode();
}

fn parseStatement(self: *@This()) error{OutOfMemory}!void {
    switch (self.peek()) {
        .@";" => try self.parseNullStatement(),
        .@"{" => try self.parseCompoundStatement(),
        .kw_auto => try self.parseAuto(),
        .kw_extrn => try self.parseExtrn(),
        .kw_if => try self.parseIf(),
        .kw_while => try self.parseWhile(),
        else => try self.parseExpressionStatement(),
    }
}

fn parseNullStatement(self: *@This()) !void {
    std.debug.assert(self.at(.@";"));
    try self.startNode(.null_statement);

    try self.bump();

    try self.cst.finishNode();
}

fn parseCompoundStatement(self: *@This()) !void {
    std.debug.assert(self.at(.@"{"));
    try self.startNode(.compound_statement);

    try self.bump();
    while (!self.at(.eof) and !try self.eat(.@"}"))
        try self.parseStatement();

    try self.cst.finishNode();
}

fn parseAuto(self: *@This()) !void {
    std.debug.assert(self.at(.kw_auto));
    try self.startNode(.auto);

    try self.bump();
    while (true) {
        switch (self.peek()) {
            .identifier, .@"," => try self.bump(),
            .@";" => {
                try self.bump();
                break;
            },
            else => break,
        }
    }

    try self.cst.finishNode();
}

fn parseExtrn(self: *@This()) !void {
    std.debug.assert(self.at(.kw_extrn));
    try self.startNode(.extrn);

    try self.bump();
    while (true) {
        switch (self.peek()) {
            .identifier, .@"," => try self.bump(),
            .@";" => {
                try self.bump();
                break;
            },
            else => break,
        }
    }

    try self.cst.finishNode();
}

fn parseIf(self: *@This()) !void {
    std.debug.assert(self.at(.kw_if));
    try self.startNode(.@"if");

    try self.bump();
    _ = try self.eat(.@"(");
    try self.parseExpression();
    _ = try self.eat(.@")");
    try self.parseStatement();

    try self.cst.finishNode();
}

fn parseWhile(self: *@This()) !void {
    std.debug.assert(self.at(.kw_while));
    try self.startNode(.@"while");

    try self.bump();
    _ = try self.eat(.@"(");
    try self.parseExpression();
    _ = try self.eat(.@")");
    try self.parseStatement();

    try self.cst.finishNode();
}

fn parseExpressionStatement(self: *@This()) !void {
    try self.startNode(.expression_statement);

    try self.parseExpression();
    _ = try self.eat(.@";");

    try self.cst.finishNode();
}

fn parseExpression(self: *@This()) error{OutOfMemory}!void {
    try self.parseExpressionRecursively(0);
}

fn parseAtom(self: *@This()) !void {
    switch (self.peek()) {
        .identifier => if (self.peekNth(1) == .@"(")
            try self.parseFunctionCall()
        else
            try self.parseVariable(),
        .number, .string_literal, .character_literal, .bcd_literal => {
            try self.startNode(.literal);
            try self.bump();
            try self.cst.finishNode();
        },
        .@"(" => try self.parseParenthesizedExpression(),
        else => try self.@"error"(),
    }
}

fn parseVariable(self: *@This()) !void {
    std.debug.assert(self.at(.identifier));
    try self.startNode(.variable);

    try self.bump();

    try self.cst.finishNode();
}

fn parseParenthesizedExpression(self: *@This()) !void {
    std.debug.assert(self.at(.@"("));
    try self.startNode(.parenthesized_expression);

    try self.bump();
    try self.parseExpression();
    _ = try self.eat(.@")");

    try self.cst.finishNode();
}

fn parseFunctionCall(self: *@This()) !void {
    std.debug.assert(self.at(.identifier));
    try self.startNode(.function_call);

    try self.bump();

    std.debug.assert(self.at(.@"("));
    try self.startNode(.arguments);

    try self.bump();
    while (!self.at(.eof) and !try self.eat(.@")")) {
        switch (self.peek()) {
            .@"," => try self.bump(),
            else => try self.parseExpression(),
        }
    }

    try self.cst.finishNode();
    try self.cst.finishNode();
}

fn parseExpressionRecursively(self: *@This(), bp_min: BindingPower) !void {
    const checkpoint = try self.makeCheckpoint();

    if (prefixBindingPower(self.peek())) |bp_right| {
        try self.startNode(.prefix_operation);
        try self.bump();
        try self.parseExpressionRecursively(bp_right);
        try self.cst.finishNode();
    } else try self.parseAtom();

    while (true) {
        const op = self.peek();
        if (postfixBindingPower(op)) |bp_left| {
            if (bp_left < bp_min) break;

            try self.cst.startNodeAt(checkpoint, .postfix_operation);

            try self.bump();
            if (op == .@"[") {
                try self.parseExpression();
                _ = try self.eat(.@"]");
            }

            try self.cst.finishNode();
        } else if (infixBindingPower(op)) |bp| {
            if (bp.left < bp_min) break;

            try self.cst.startNodeAt(checkpoint, .infix_operation);

            try self.bump();
            if (op == .@"?") {
                try self.parseExpression();
                _ = try self.eat(.@":");
            }
            try self.parseExpressionRecursively(bp.right);

            try self.cst.finishNode();
        } else {
            break;
        }
    }
}

const BindingPower = u5;

fn prefixBindingPower(kind: SyntaxKind) ?BindingPower {
    return switch (kind) {
        .@"#", .@"##", .@"~", .@"-", .@"#-", .@"!", .@"*", .@"&", .@"++", .@"--", .@"@" => 23,
        else => null,
    };
}

fn postfixBindingPower(kind: SyntaxKind) ?BindingPower {
    return switch (kind) {
        .@"++", .@"--" => 23,
        .@"[" => 25,
        else => null,
    };
}

fn infixBindingPower(kind: SyntaxKind) ?struct { left: BindingPower, right: BindingPower } {
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

fn @"error"(self: *@This()) !void {
    try self.startNode(.@"error");
    try self.parseAnything();
    try self.cst.finishNode();
}

fn parseAnything(self: *@This()) !void {
    switch (self.peek()) {
        .@"(" => {
            try self.bump();
            while (!self.at(.eof) and !try self.eat(.@")"))
                try self.parseAnything();
        },
        .@"{" => {
            try self.bump();
            while (!self.at(.eof) and !try self.eat(.@"}"))
                try self.parseAnything();
        },
        .@"[" => {
            try self.bump();
            while (!self.at(.eof) and !try self.eat(.@"]"))
                try self.parseAnything();
        },
        .@";" => try self.parseNullStatement(),
        .kw_auto => try self.parseAuto(),
        .kw_extrn => try self.parseExtrn(),
        .kw_if => try self.parseIf(),
        .kw_while => try self.parseWhile(),
        else => try self.bump(),
    }
}

fn bump(self: *@This()) !void {
    while (!self.at(.eof)) {
        const token = self.tokens.get(self.index);
        try self.cst.token(token.kind, token.source);
        self.index += 1;
        if (token.kind != .trivia) break;
    }
}

fn startNode(self: *@This(), kind: SyntaxKind) !void {
    try self.skipTrivia();
    try self.cst.startNode(kind);
}

fn makeCheckpoint(self: *@This()) !Cst.Builder.Checkpoint {
    try self.skipTrivia();
    return self.cst.makeCheckpoint();
}

fn skipTrivia(self: *@This()) !void {
    while (self.index < self.tokens.len) : (self.index += 1) {
        const token = self.tokens.get(self.index);
        if (token.kind != .trivia) break;
        try self.cst.token(token.kind, token.source);
    }
}

fn eat(self: *@This(), kind: SyntaxKind) !bool {
    if (self.at(kind)) {
        try self.bump();
        return true;
    } else return false;
}

fn at(self: *@This(), kind: SyntaxKind) bool {
    return self.peek() == kind;
}

fn peek(self: @This()) SyntaxKind {
    const kinds = self.tokens.items(.kind);
    const index = std.mem.indexOfNonePos(SyntaxKind, kinds, self.index, &.{.trivia}) orelse return .eof;
    return kinds[index];
}

fn peekNth(self: @This(), n: usize) SyntaxKind {
    var i: usize = 0;
    return for (self.tokens.items(.kind)[self.index..]) |kind| {
        if (kind == .trivia) continue;
        if (i == n) break kind;
        i += 1;
    } else .eof;
}

test "fuzz parser" {
    const input_bytes = std.testing.fuzzInput(.{});
    var lexer = @import("Lexer.zig").init(input_bytes);
    var tokens = std.MultiArrayList(Token){};
    defer tokens.deinit(std.testing.allocator);

    while (lexer.next()) |token| {
        try tokens.append(std.testing.allocator, token);
    }

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const cst = try parse(tokens.slice(), arena.allocator());
    defer cst.deinit(std.testing.allocator);
}
