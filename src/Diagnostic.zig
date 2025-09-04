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
    items: std.MultiArrayList(Diagnostic) = .{},
    allocator: std.mem.Allocator,
    config: std.io.tty.Config,
    /// Must be assigned if any diagnostics have spans.
    source_code_start: [*]const u8 = undefined,

    pub fn init(allocator: std.mem.Allocator) Diagnostic.S {
        return .{
            .allocator = allocator,
            .config = std.io.tty.detectConfig(std.io.getStdErr()),
        };
    }

    pub fn format(diagnostics: *Diagnostic.S, comptime fmt: []const u8, args: anytype) ![]const u8 {
        return try std.fmt.allocPrint(diagnostics.allocator, fmt, args);
    }

    pub fn emit(diagnostics: *Diagnostic.S, diagnostic: Diagnostic) !void {
        try diagnostics.items.append(diagnostics.allocator, diagnostic);
    }

    pub fn show(diagnostics: Diagnostic.S) !void {
        const writer = std.io.getStdErr().writer();
        const slice = diagnostics.items.slice();
        for (
            slice.items(.level),
            slice.items(.message),
            slice.items(.span),
        ) |level, message, maybe_span| {
            try diagnostics.config.setColor(writer, .bold);
            try diagnostics.config.setColor(writer, switch (level) {
                .note => .green,
                .@"error" => .red,
            });
            try writer.print("{s}", .{@tagName(level)});
            try diagnostics.config.setColor(writer, .reset);
            if (maybe_span) |span| {
                const start = span.ptr - diagnostics.source_code_start;
                try writer.print(" ({}..{})", .{ start, start + span.len });
            }
            try diagnostics.config.setColor(writer, .bold);
            try writer.print(": {s}\n", .{message});
        }
        try diagnostics.config.setColor(writer, .reset);
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
