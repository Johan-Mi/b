const std = @import("std");

const Diagnostic = @This();

level: Level,
message: []const u8,
span: ?[]const u8 = null,

pub fn note(message: []const u8) @This() {
    return .{ .level = .note, .message = message };
}

pub fn @"error"(message: []const u8) @This() {
    return .{ .level = .@"error", .message = message };
}

pub const S = struct {
    diagnostics: std.MultiArrayList(Diagnostic) = .{},
    gpa: std.mem.Allocator,
    string_arena: std.mem.Allocator,
    config: std.io.tty.Config,
    /// Must be assigned if any diagnostics have spans.
    source_code_start: [*]const u8 = undefined,

    pub fn init(gpa: std.mem.Allocator, string_arena: std.mem.Allocator) @This() {
        return .{
            .gpa = gpa,
            .string_arena = string_arena,
            .config = std.io.tty.detectConfig(std.io.getStdErr()),
        };
    }

    pub fn format(self: *@This(), comptime fmt: []const u8, args: anytype) ![]const u8 {
        return try std.fmt.allocPrint(self.string_arena, fmt, args);
    }

    pub fn emit(self: *@This(), diagnostic: Diagnostic) !void {
        try self.diagnostics.append(self.gpa, diagnostic);
    }

    pub fn show(self: @This()) !void {
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

    pub fn is_ok(self: @This()) bool {
        return std.mem.indexOfScalar(Level, self.diagnostics.items(.level), .@"error") == null;
    }

    pub fn deinit(self: @This()) void {
        var diagnostics = self.diagnostics;
        diagnostics.deinit(self.gpa);
    }
};

const Level = enum {
    note,
    @"error",
};
