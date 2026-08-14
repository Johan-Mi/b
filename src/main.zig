pub fn main(init: std.process.Init) !u8 {
    const allocator = init.arena.allocator();

    var diagnostics: Diagnostic.S = try .init(allocator, init.io, init.minimal.environ);

    realMain(init, &diagnostics) catch |err|
        try diagnostics.emit(.@"error"(@errorName(err)));

    try diagnostics.show(init.io);
    return @intFromBool(!diagnostics.isOk());
}

fn realMain(init: std.process.Init, diagnostics: *Diagnostic.S) !void {
    const source_code = blk: {
        var iter = init.minimal.args.iterate();
        const me = iter.next() orelse "b";
        const source_path = iter.next() orelse {
            try diagnostics.emit(.@"error"("no source file provided"));
            const usage = try diagnostics.format("usage: {s} SOURCE.b", .{me});
            return try diagnostics.emit(.note(usage));
        };
        if (iter.next()) |_| {
            try diagnostics.emit(.@"error"("too many command line arguments"));
            const usage = try diagnostics.format("usage: {s} SOURCE.b", .{me});
            return try diagnostics.emit(.note(usage));
        }

        break :blk std.Io.Dir.cwd().readFileAlloc(init.io, source_path, init.arena.allocator(), .unlimited) catch |err| {
            try diagnostics.emit(.@"error"("failed to read source code"));
            try diagnostics.emit(.note(@errorName(err)));
            return;
        };
    };

    diagnostics.source_code_start = source_code.ptr;

    var lexer: Lexer = .init(source_code);
    var tokens: std.MultiArrayList(Lexer.Token) = .empty;
    while (lexer.next()) |token| {
        try tokens.append(init.arena.allocator(), token);
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

    const cst = try Parser.parse(source_code.ptr, tokens.slice(), init.arena.allocator());

    const program = try @import("ir/lowering.zig").lower(cst, init.arena.allocator(), diagnostics);

    if (init.minimal.environ.containsConstant("DUMP_IR")) {
        std.log.info("{}", .{std.json.fmt(program, .{})});
    }

    const output_file = try std.Io.Dir.cwd().createFile(init.io, "main.bc", .{});
    try @import("codegen.zig").compile(program, output_file, init.arena.allocator(), init.io);
}

test {
    std.testing.refAllDecls(@This());
}

const builtin = @import("builtin");
const Diagnostic = @import("Diagnostic.zig");
const Lexer = @import("Lexer.zig");
const Parser = @import("Parser.zig");
const std = @import("std");
