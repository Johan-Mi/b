const Diagnostic = @import("Diagnostic.zig");
const Lexer = @import("Lexer.zig");
const std = @import("std");

pub fn main() !u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    var string_arena = std.heap.ArenaAllocator.init(allocator);
    defer string_arena.deinit();
    var diagnostics = Diagnostic.S.init(allocator, string_arena.allocator());
    defer diagnostics.deinit();

    realMain(allocator, &diagnostics) catch |err| try diagnostics.@"error"(@errorName(err));

    try diagnostics.show();
    return @intFromBool(!diagnostics.is_ok());
}

fn realMain(allocator: std.mem.Allocator, diagnostics: *Diagnostic.S) !void {
    const source_code = blk: {
        const args = try std.process.argsAlloc(allocator);
        defer std.process.argsFree(allocator, args);

        // TODO: print usage information
        if (args.len < 2)
            return try diagnostics.@"error"("no source file provided");
        if (3 <= args.len)
            return try diagnostics.@"error"("too many command line arguments");
        const source_path = args[1];

        break :blk std.fs.cwd().readFileAlloc(allocator, source_path, std.math.maxInt(usize)) catch |err| {
            try diagnostics.@"error"("failed to read source code");
            try diagnostics.note(@errorName(err));
            return;
        };
    };
    defer allocator.free(source_code);

    const token_stream = try Lexer.lex(source_code, diagnostics, allocator);
    defer token_stream.deinit(allocator);

    for (token_stream.tokens.items(.kind), token_stream.tokens.items(.source)) |kind, source| {
        std.log.debug("{s} «{s}»", .{ @tagName(kind), source });
    }
}

test {
    std.testing.refAllDecls(@This());
}
