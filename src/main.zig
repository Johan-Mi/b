const Diagnostic = @import("Diagnostic.zig");
const Lexer = @import("Lexer.zig");
const Parser = @import("Parser.zig");
const std = @import("std");

pub fn main() !u8 {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    var string_arena: std.heap.ArenaAllocator = .init(allocator);
    defer string_arena.deinit();
    var diagnostics: Diagnostic.S = .init(allocator, string_arena.allocator());
    defer diagnostics.deinit();

    realMain(allocator, &diagnostics) catch |err| try diagnostics.emit(.@"error"(@errorName(err)));

    try diagnostics.show();
    return @intFromBool(!diagnostics.isOk());
}

fn realMain(allocator: std.mem.Allocator, diagnostics: *Diagnostic.S) !void {
    const source_code = blk: {
        const args = try std.process.argsAlloc(allocator);
        defer std.process.argsFree(allocator, args);

        const me = if (1 <= args.len) args[0] else "b";
        if (args.len != 2) {
            if (args.len < 2)
                try diagnostics.emit(.@"error"("no source file provided"));
            if (3 <= args.len)
                try diagnostics.emit(.@"error"("too many command line arguments"));
            const usage = try diagnostics.format("usage: {s} SOURCE.b", .{me});
            return try diagnostics.emit(.note(usage));
        }
        const source_path = args[1];

        break :blk std.fs.cwd().readFileAlloc(allocator, source_path, std.math.maxInt(usize)) catch |err| {
            try diagnostics.emit(.@"error"("failed to read source code"));
            try diagnostics.emit(.note(@errorName(err)));
            return;
        };
    };
    defer allocator.free(source_code);

    diagnostics.source_code_start = source_code.ptr;

    var lexer: Lexer = .init(source_code);
    var tokens: std.MultiArrayList(Lexer.Token) = .{};
    defer tokens.deinit(allocator);
    while (lexer.next()) |token| {
        try tokens.append(allocator, token);
        switch (token.kind) {
            .@"error" => try diagnostics.emit(.{
                .level = .@"error",
                .message = if (token.source.len == 1) "invalid byte" else "invalid bytes",
                .span = token.source,
            }),
            .string_literal => if (!std.mem.endsWith(u8, token.source, "\"")) try diagnostics.emit(.{
                .level = .@"error",
                .message = "unterminated string literal",
                .span = token.source,
            }),
            .character_literal => if (!std.mem.endsWith(u8, token.source, "'")) try diagnostics.emit(.{
                .level = .@"error",
                .message = "unterminated character literal",
                .span = token.source,
            }),
            .bcd_literal => if (!std.mem.endsWith(u8, token.source, "`")) try diagnostics.emit(.{
                .level = .@"error",
                .message = "unterminated BCD literal",
                .span = token.source,
            }),
            else => {},
        }
    }

    const cst = blk: {
        var arena: std.heap.ArenaAllocator = .init(allocator);
        defer arena.deinit();
        break :blk try Parser.parse(tokens.slice(), arena.allocator(), allocator);
    };
    defer cst.deinit(allocator);
    cst.dump();

    try @import("codegen.zig").compile("main.bc");
}

test {
    std.testing.refAllDecls(@This());
}
