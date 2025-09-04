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
    diagnostics: std.MultiArrayList(Diagnostic) = .{},
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

    pub fn format(self: *Diagnostic.S, comptime fmt: []const u8, args: anytype) ![]const u8 {
        return try std.fmt.allocPrint(self.allocator, fmt, args);
    }

    pub fn emit(self: *Diagnostic.S, diagnostic: Diagnostic) !void {
        try self.diagnostics.append(self.allocator, diagnostic);
    }

    pub fn show(self: Diagnostic.S) !void {
        const writer = std.io.getStdErr().writer();
        const slice = self.diagnostics.slice();
        for (
            slice.items(.level),
            slice.items(.message),
            slice.items(.span),
        ) |level, message, maybe_span| {
            try self.config.setColor(writer, .bold);
            try self.config.setColor(writer, switch (level) {
                .note => .green,
                .@"error" => .red,
            });
            try writer.print("{s}", .{@tagName(level)});
            try self.config.setColor(writer, .reset);
            if (maybe_span) |span| {
                const start = span.ptr - self.source_code_start;
                try writer.print(" ({}..{})", .{ start, start + span.len });
            }
            try self.config.setColor(writer, .bold);
            try writer.print(": {s}\n", .{message});
        }
        try self.config.setColor(writer, .reset);
    }

    pub fn isOk(self: Diagnostic.S) bool {
        return std.mem.indexOfScalar(Level, self.diagnostics.items(.level), .@"error") == null;
    }
};

const Level = enum {
    note,
    @"error",
};

const Diagnostic = @This();

const std = @import("std");
