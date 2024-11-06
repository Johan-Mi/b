const Cst = @This();
const std = @import("std");
const SyntaxKind = @import("syntax.zig").Kind;
const log = std.log.scoped(.cst);

nodes: std.MultiArrayList(struct {
    kind: SyntaxKind,
    /// Indices into `Cst.children`.
    children: struct { start: usize, count: usize },
}),
children: std.ArrayListUnmanaged(Node),

pub const Node = enum(usize) {
    _,

    pub fn kind(self: @This(), cst: Cst) SyntaxKind {
        return cst.nodes.items(.kind)[@intFromEnum(self)];
    }

    pub fn children(self: @This(), cst: Cst) ChildIterator {
        const start, const count = cst.nodes.items(.children)[@intFromEnum(self)];
        return .{ .start = start, .end = start + count };
    }

    pub const ChildIterator = struct {
        start: usize,
        end: usize,

        pub fn next(self: *@This(), cst: Cst) ?Node {
            if (self.start < self.end) {
                defer self.start += 1;
                return cst.children[self.start];
            } else return null;
        }
    };
};

pub const Token = enum(usize) { _ };

pub fn deinit(self: @This(), allocator: std.mem.Allocator) void {
    var nodes = self.nodes;
    nodes.deinit(allocator);
    var children = self.children;
    children.deinit(allocator);
}

pub const Builder = struct {
    events: std.ArrayList(Event),

    const Event = union(enum) {
        open: SyntaxKind,
        token: SyntaxKind,
        close,
    };

    pub fn init(arena: std.mem.Allocator) @This() {
        return .{ .events = .init(arena) };
    }

    pub fn finish(self: @This()) Cst {
        var indent: usize = 0;
        const indent_width = 2;
        for (self.events.items) |event| {
            switch (event) {
                .open => |kind| {
                    log.debug(
                        "{s:[2]}start node: {s}",
                        .{ "", @tagName(kind), indent * indent_width },
                    );
                    indent += 1;
                },
                .token => |kind| log.debug(
                    "{s:[2]}token: {s}",
                    .{ "", @tagName(kind), indent * indent_width },
                ),
                .close => {
                    log.debug(
                        "{s:[1]}finish node",
                        .{ "", indent * indent_width },
                    );
                    indent -= 1;
                },
            }
        }
        return .{ .nodes = .{}, .children = .{} };
    }

    pub fn startNode(self: *@This(), kind: SyntaxKind) !void {
        try self.events.append(.{ .open = kind });
    }

    pub fn finishNode(self: *@This()) !void {
        try self.events.append(.close);
    }

    pub fn token(self: *@This(), kind: SyntaxKind, text: []const u8) !void {
        _ = text; // autofix
        try self.events.append(.{ .token = kind });
    }

    pub const Checkpoint = enum(usize) { _ };

    pub fn makeCheckpoint(self: @This()) Checkpoint {
        return @enumFromInt(self.events.items.len);
    }

    pub fn startNodeAt(self: *@This(), checkpoint: Checkpoint, kind: SyntaxKind) !void {
        try self.events.insert(@intFromEnum(checkpoint), .{ .open = kind });
    }
};
