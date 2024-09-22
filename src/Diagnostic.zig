const std = @import("std");

const Diagnostic = @This();

level: Level,
message: []const u8,

const S = struct {
    diagnostics: std.MultiArrayList(Diagnostic) = .{},
    gpa: std.mem.Allocator,

    pub fn init(gpa: std.mem.Allocator) @This() {
        return .{ .gpa = gpa };
    }

    pub fn @"error"(self: *@This(), message: []const u8) !void {
        try self.diagnostics.append(self.gpa, .{ .level = .@"error", .message = message });
    }

    pub fn show(self: @This()) !void {
        const writer = std.io.getStdErr().writer();
        for (self.diagnostics.items(.level), self.diagnostics.items(.message)) |level, message| {
            try writer.print("{}: {s}\n", .{ level, message });
        }
    }

    pub fn deinit(self: @This()) void {
        self.diagnostics.deinit(self.gpa);
    }
};

const Level = enum {
    @"error",
};
