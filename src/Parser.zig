const Cst = @import("Cst.zig");
const std = @import("std");
const SyntaxKind = @import("Lexer.zig").SyntaxKind;
const Token = @import("Lexer.zig").Token;

tokens: std.MultiArrayList(Token).Slice,
index: usize = 0,
cst: Cst,

pub fn parse(tokens: std.MultiArrayList(Token).Slice) Cst {
    var self = @This(){ .tokens = tokens, .cst = Cst.init() };
    self.cst.startNode(.document);
    while (!self.at(.eof))
        self.parseTopLevelItem();
    self.cst.finishNode();
    return self.cst;
}

fn parseTopLevelItem(self: *@This()) void {
    if (self.at(.identifier) and self.peekNth(1) == .@"(")
        self.parseFunction()
    else
        self.@"error"();
}

fn parseFunction(self: *@This()) void {
    std.debug.assert(self.at(.identifier));
    self.startNode(.function);
    defer self.cst.finishNode();

    self.bump();
    self.parseFunctionParameters();
    self.parseStatement();
}

fn parseFunctionParameters(self: *@This()) void {
    std.debug.assert(self.at(.@"("));
    self.startNode(.function_parameters);
    defer self.cst.finishNode();

    self.bump();
    while (!self.at(.eof) and !self.eat(.@")"))
        self.@"error"();
}

fn parseStatement(self: *@This()) void {
    switch (self.peek()) {
        .@"{" => self.parseCompoundStatement(),
        .kw_auto => self.parseAuto(),
        .kw_extrn => self.parseExtrn(),
        .kw_if => self.parseIf(),
        .kw_while => self.parseWhile(),
        else => self.@"error"(),
    }
}

fn parseCompoundStatement(self: *@This()) void {
    std.debug.assert(self.at(.@"{"));
    self.startNode(.compound_statement);
    defer self.cst.finishNode();

    self.bump();
    while (!self.at(.eof) and !self.eat(.@"}"))
        self.parseStatement();
}

fn parseAuto(self: *@This()) void {
    std.debug.assert(self.at(.kw_auto));
    self.startNode(.auto);
    defer self.cst.finishNode();

    self.bump();
    while (true) {
        switch (self.peek()) {
            .identifier, .@"," => self.bump(),
            .@";" => {
                self.bump();
                break;
            },
            else => break,
        }
    }
}

fn parseExtrn(self: *@This()) void {
    std.debug.assert(self.at(.kw_extrn));
    self.startNode(.extrn);
    defer self.cst.finishNode();

    self.bump();
    while (true) {
        switch (self.peek()) {
            .identifier, .@"," => self.bump(),
            .@";" => {
                self.bump();
                break;
            },
            else => break,
        }
    }
}

fn parseIf(self: *@This()) void {
    std.debug.assert(self.at(.kw_if));
    self.startNode(.@"if");
    defer self.cst.finishNode();

    self.bump();
    _ = self.eat(.@"(");
    self.parseExpression();
    _ = self.eat(.@")");
    self.parseStatement();
}

fn parseWhile(self: *@This()) void {
    std.debug.assert(self.at(.kw_while));
    self.startNode(.@"while");
    defer self.cst.finishNode();

    self.bump();
    _ = self.eat(.@"(");
    self.parseExpression();
    _ = self.eat(.@")");
    self.parseStatement();
}

fn parseExpression(self: *@This()) void {
    self.parseExpressionRecursively(0);
}

fn parseAtom(self: *@This()) void {
    switch (self.peek()) {
        .identifier => self.parseVariable(),
        .@"(" => self.parseParenthesizedExpression(),
        else => self.@"error"(),
    }
}

fn parseVariable(self: *@This()) void {
    std.debug.assert(self.at(.identifier));
    self.startNode(.variable);
    defer self.cst.finishNode();

    self.bump();
}

fn parseParenthesizedExpression(self: *@This()) void {
    std.debug.assert(self.at(.@"("));
    self.startNode(.parenthesized_expression);
    defer self.cst.finishNode();

    self.bump();
    self.parseExpression();
    _ = self.eat(.@")");
}

fn parseExpressionRecursively(self: *@This(), bp_min: BindingPower) void {
    if (prefixBindingPower(self.peek())) |bp_right| {
        self.startNode(.prefix_operation);
        defer self.cst.finishNode();
        self.bump();
        self.parseExpressionRecursively(bp_right);
    } else {
        self.parseAtom();
        while (true) {
            const op = self.peek();
            if (postfixBindingPower(op)) |bp_left| {
                if (bp_left < bp_min) break;
                self.bump();
            } else if (infixBindingPower(op)) |bp| {
                if (bp.left < bp_min) break;
                self.bump();
                self.parseExpressionRecursively(bp.right);
            } else {
                break;
            }
        }
    }
}

const BindingPower = u2;

fn prefixBindingPower(kind: SyntaxKind) ?BindingPower {
    return switch (kind) {
        .@"#", .@"##", .@"~", .@"-", .@"#-", .@"!", .@"*", .@"&", .@"++", .@"--", .@"@" => 1,
        else => null,
    };
}

fn postfixBindingPower(kind: SyntaxKind) ?BindingPower {
    return switch (kind) {
        .@"++", .@"--" => 1,
        else => null,
    };
}

fn infixBindingPower(kind: SyntaxKind) ?struct { left: BindingPower, right: BindingPower } {
    return switch (kind) {
        .@"<<",
        .@">>",
        .@"&",
        .@"|",
        .@"^",
        .@"*",
        .@"/",
        .@"%",
        .@"#*",
        .@"#/",
        .@"+",
        .@"-",
        .@"#+",
        .@"#-",
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
        .@"&&",
        .@"||",
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
        => .{ .left = 1, .right = 2 },
        else => null,
    };
}

fn @"error"(self: *@This()) void {
    self.startNode(.@"error");
    defer self.cst.finishNode();
    self.parseAnything();
}

fn parseAnything(self: *@This()) void {
    switch (self.peek()) {
        .@"(" => {
            self.bump();
            while (!self.at(.eof) and !self.eat(.@")"))
                self.parseAnything();
        },
        .@"{" => {
            self.bump();
            while (!self.at(.eof) and !self.eat(.@"}"))
                self.parseAnything();
        },
        .@"[" => {
            self.bump();
            while (!self.at(.eof) and !self.eat(.@"]"))
                self.parseAnything();
        },
        .kw_auto => self.parseAuto(),
        .kw_extrn => self.parseExtrn(),
        .kw_if => self.parseIf(),
        .kw_while => self.parseWhile(),
        else => self.bump(),
    }
}

fn bump(self: *@This()) void {
    while (!self.at(.eof)) {
        const token = self.tokens.get(self.index);
        self.cst.token(token.kind, token.source);
        self.index += 1;
        if (token.kind != .trivia) break;
    }
}

fn startNode(self: *@This(), kind: SyntaxKind) void {
    self.skipTrivia();
    self.cst.startNode(kind);
}

fn skipTrivia(self: *@This()) void {
    while (self.index < self.tokens.len) : (self.index += 1) {
        const token = self.tokens.get(self.index);
        if (token.kind != .trivia) break;
        self.cst.token(token.kind, token.source);
    }
}

fn eat(self: *@This(), kind: SyntaxKind) bool {
    if (self.at(kind)) {
        self.bump();
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

    _ = parse(tokens.slice());
}
