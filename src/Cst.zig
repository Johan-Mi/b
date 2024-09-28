const SyntaxKind = @import("Lexer.zig").SyntaxKind;
const log = @import("std").log.scoped(.cst);

pub const Node = struct {};

pub const Token = struct {};

pub fn init() @This() {
    return .{};
}

pub fn startNode(self: *@This(), kind: SyntaxKind) void {
    _ = self; // autofix
    log.debug("start node: {s}", .{@tagName(kind)});
}

pub fn finishNode(self: *@This()) void {
    _ = self; // autofix
    log.debug("finish node", .{});
}

pub fn token(self: *@This(), kind: SyntaxKind, text: []const u8) void {
    _ = text; // autofix
    _ = self; // autofix
    log.debug("token: {s}", .{@tagName(kind)});
}
