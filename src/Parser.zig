const Cst = @import("Cst.zig");
const std = @import("std");
const SyntaxKind = @import("syntax.zig").Kind;
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
    if (!self.at(.identifier))
        self.@"error"()
    else switch (self.peekNth(1)) {
        .@"(" => self.parseFunction(),
        .@";", .@"{", .@"[" => self.parseGlobalDeclaration(),
        else => self.@"error"(),
    }
}

fn parseGlobalDeclaration(self: *@This()) void {
    std.debug.assert(self.at(.identifier));
    self.startNode(.global_declaration);
    defer self.cst.finishNode();

    self.bump();

    if (self.at(.@"[")) {
        self.startNode(.vector_size);
        defer self.cst.finishNode();

        self.bump();

        if (!self.eat(.@"]")) {
            self.parseExpression();
            _ = self.eat(.@"]");
        }
    }

    if (self.at(.@"{")) {
        self.startNode(.vector_initializer);
        defer self.cst.finishNode();

        self.bump();

        while (!self.at(.eof) and !self.eat(.@"}")) {
            switch (self.peek()) {
                .@";" => break,
                .@"," => self.bump(),
                else => self.parseExpression(),
            }
        }
    }

    _ = self.eat(.@";");
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
        .@";" => self.parseNullStatement(),
        .@"{" => self.parseCompoundStatement(),
        .kw_auto => self.parseAuto(),
        .kw_extrn => self.parseExtrn(),
        .kw_if => self.parseIf(),
        .kw_while => self.parseWhile(),
        else => self.parseExpressionStatement(),
    }
}

fn parseNullStatement(self: *@This()) void {
    std.debug.assert(self.at(.@";"));
    self.startNode(.null_statement);
    defer self.cst.finishNode();

    self.bump();
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

fn parseExpressionStatement(self: *@This()) void {
    self.startNode(.expression_statement);
    defer self.cst.finishNode();

    self.parseExpression();
    _ = self.eat(.@";");
}

fn parseExpression(self: *@This()) void {
    self.parseExpressionRecursively(0);
}

fn parseAtom(self: *@This()) void {
    switch (self.peek()) {
        .identifier => if (self.peekNth(1) == .@"(")
            self.parseFunctionCall()
        else
            self.parseVariable(),
        .number, .string_literal, .character_literal, .bcd_literal => {
            self.startNode(.literal);
            defer self.cst.finishNode();
            self.bump();
        },
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

fn parseFunctionCall(self: *@This()) void {
    std.debug.assert(self.at(.identifier));
    self.startNode(.function_call);
    defer self.cst.finishNode();

    self.bump();

    std.debug.assert(self.at(.@"("));
    self.startNode(.arguments);
    defer self.cst.finishNode();

    self.bump();
    while (!self.at(.eof) and !self.eat(.@")")) {
        switch (self.peek()) {
            .@"," => self.bump(),
            else => self.parseExpression(),
        }
    }
}

fn parseExpressionRecursively(self: *@This(), bp_min: BindingPower) void {
    const checkpoint = self.makeCheckpoint();

    if (prefixBindingPower(self.peek())) |bp_right| {
        self.startNode(.prefix_operation);
        defer self.cst.finishNode();
        self.bump();
        self.parseExpressionRecursively(bp_right);
    } else self.parseAtom();

    while (true) {
        const op = self.peek();
        if (postfixBindingPower(op)) |bp_left| {
            if (bp_left < bp_min) break;

            self.cst.startNodeAt(checkpoint, .postfix_operation);
            defer self.cst.finishNode();

            self.bump();
            if (op == .@"[") {
                self.parseExpression();
                _ = self.eat(.@"]");
            }
        } else if (infixBindingPower(op)) |bp| {
            if (bp.left < bp_min) break;

            self.cst.startNodeAt(checkpoint, .infix_operation);
            defer self.cst.finishNode();

            self.bump();
            if (op == .@"?") {
                self.parseExpression();
                _ = self.eat(.@":");
            }
            self.parseExpressionRecursively(bp.right);
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
        .@";" => self.parseNullStatement(),
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

fn makeCheckpoint(self: *@This()) Cst.Checkpoint {
    self.skipTrivia();
    return self.cst.makeCheckpoint();
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
