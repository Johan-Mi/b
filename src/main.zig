pub fn main() !u8 {
    var arena: std.heap.ArenaAllocator = .init(std.heap.page_allocator);
    const allocator = arena.allocator();

    var diagnostics: Diagnostic.S = .init(allocator);

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
            try diagnostics.emit(.@"error"(
                if (args.len < 2) "no source file provided" else "too many command line arguments",
            ));
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

    diagnostics.source_code_start = source_code.ptr;

    var lexer: Lexer = .init(source_code);
    var tokens: std.MultiArrayList(Lexer.Token) = .{};
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

    const cst = try Parser.parse(tokens.slice(), allocator);

    if (std.process.hasEnvVarConstant("DUMP_CST")) cst.dump();

    const program = try @import("ir/lowering.zig").lower(cst, allocator, diagnostics);

    if (std.process.hasEnvVarConstant("DUMP_IR")) {
        std.log.info("{}", .{std.json.fmt(program, .{})});
    }

    const output_file = try std.fs.cwd().createFile("main.bc", .{});
    try @import("codegen.zig").compile(program, output_file, allocator);
}

test {
    std.testing.refAllDecls(@This());
}

const builtin = @import("builtin");
const Diagnostic = @import("Diagnostic.zig");
const Lexer = @import("Lexer.zig");
const Parser = @import("Parser.zig");
const std = @import("std");
