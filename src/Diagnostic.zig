level: Level,
message: []const u8,
span: ?[]const u8 = null,

pub fn note(message: []const u8) Diagnostic {
    return .{ .level = .note, .message = message };
}

pub fn @"error"(message: []const u8) Diagnostic {
    return .{ .level = .@"error", .message = message };
}

pub const S = struct {
    items: std.MultiArrayList(Diagnostic) = .empty,
    allocator: std.mem.Allocator,
    mode: std.Io.Terminal.Mode,
    /// Must be assigned if any diagnostics have spans.
    source_code_start: [*]const u8 = undefined,

    pub fn init(allocator: std.mem.Allocator, io: std.Io, environ: std.process.Environ) !Diagnostic.S {
        return .{
            .allocator = allocator,
            .mode = try .detect(io, std.Io.File.stderr(), environ.containsUnemptyConstant("NO_COLOR"), environ.containsUnemptyConstant("CLICOLOR_FORCE")),
        };
    }

    pub fn format(diagnostics: *Diagnostic.S, comptime fmt: []const u8, args: anytype) ![]const u8 {
        return try std.fmt.allocPrint(diagnostics.allocator, fmt, args);
    }

    pub fn emit(diagnostics: *Diagnostic.S, diagnostic: Diagnostic) !void {
        try diagnostics.items.append(diagnostics.allocator, diagnostic);
    }

    pub fn show(diagnostics: Diagnostic.S, io: std.Io) !void {
        var buffer: [1024]u8 = undefined;
        var writer = std.Io.File.stderr().writer(io, &buffer);
        var terminal: std.Io.Terminal = .{ .writer = &writer.interface, .mode = diagnostics.mode };

        const slice = diagnostics.items.slice();
        for (
            slice.items(.level),
            slice.items(.message),
            slice.items(.span),
        ) |level, message, maybe_span| {
            try terminal.setColor(.bold);
            try terminal.setColor(switch (level) {
                .note => .green,
                .@"error" => .red,
            });
            try terminal.writer.print("{s}", .{@tagName(level)});
            try terminal.setColor(.reset);
            if (maybe_span) |span| {
                const start = span.ptr - diagnostics.source_code_start;
                try terminal.writer.print(" ({}..{})", .{ start, start + span.len });
            }
            try terminal.setColor(.bold);
            try terminal.writer.print(": {s}\n", .{message});
        }
        try terminal.setColor(.reset);
    }

    pub fn isOk(diagnostics: Diagnostic.S) bool {
        return std.mem.indexOfScalar(Level, diagnostics.items.items(.level), .@"error") == null;
    }
};

const Level = enum {
    note,
    @"error",
};

const Diagnostic = @This();

const std = @import("std");
