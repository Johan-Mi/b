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
    self.@"error"();
}

fn parseStatement(self: *@This()) void {
    switch (self.peek()) {
        .kw_while => self.parseWhile(),
        else => self.@"error"(),
    }
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
    self.@"error"();
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

fn peek(self: *@This()) SyntaxKind {
    self.skipTrivia();
    return if (self.index < self.tokens.len) self.tokens.get(self.index).kind else .eof;
}
