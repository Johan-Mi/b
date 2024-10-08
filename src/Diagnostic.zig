const std = @import("std");

const Diagnostic = @This();

level: Level,
message: []const u8,

pub const S = struct {
    diagnostics: std.MultiArrayList(Diagnostic) = .{},
    gpa: std.mem.Allocator,
    string_arena: std.mem.Allocator,
    config: std.io.tty.Config,

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

    pub fn note(self: *@This(), message: []const u8) !void {
        try self.diagnostics.append(self.gpa, .{ .level = .note, .message = message });
    }

    pub fn @"error"(self: *@This(), message: []const u8) !void {
        try self.diagnostics.append(self.gpa, .{ .level = .@"error", .message = message });
    }

    pub fn show(self: @This()) !void {
        const writer = std.io.getStdErr().writer();
        for (self.diagnostics.items(.level), self.diagnostics.items(.message)) |level, message| {
            try self.config.setColor(writer, .bold);
            try self.config.setColor(writer, switch (level) {
                .note => .green,
                .@"error" => .red,
            });
            try writer.print("{s}", .{@tagName(level)});
            try self.config.setColor(writer, .reset);
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
