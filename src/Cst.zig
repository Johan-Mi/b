const SyntaxKind = @import("Lexer.zig").SyntaxKind;
const log = @import("std").log.scoped(.cst);

indent: usize = 0,

const indent_width = 2;

pub const Node = struct {};

pub const Token = struct {};

pub fn init() @This() {
    return .{};
}

pub fn startNode(self: *@This(), kind: SyntaxKind) void {
    log.debug("{s:[2]}start node: {s}", .{ "", @tagName(kind), self.indent * indent_width });
    self.indent += 1;
}

pub fn finishNode(self: *@This()) void {
    log.debug("{s:[1]}finish node", .{ "", self.indent * indent_width });
    self.indent -= 1;
}

pub fn token(self: *@This(), kind: SyntaxKind, text: []const u8) void {
    _ = text; // autofix
    log.debug("{s:[2]}token: {s}", .{ "", @tagName(kind), self.indent * indent_width });
}
