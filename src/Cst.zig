const Cst = @This();
const std = @import("std");
const SyntaxKind = @import("syntax.zig").Kind;
const log = std.log.scoped(.cst);

nodes: std.MultiArrayList(struct {
    kind: SyntaxKind,
    /// Indices into `Cst.children`.
    children: struct { start: Start, count: usize },
}),
children: std.ArrayListUnmanaged(Node),

const Start = enum(usize) {
    token = std.math.maxInt(usize),
    _,
};

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

pub fn dump(self: @This()) void {
    const nodes = self.nodes.slice();
    for (0.., nodes.items(.kind), nodes.items(.children)) |i, kind, children| {
        if (children.start == .token) {
            log.info("{}: {s}", .{ i, @tagName(kind) });
        } else {
            const child_slice =
                self.children.items[@intFromEnum(children.start)..][0..children.count];
            log.info("{}: {s} {any}", .{ i, @tagName(kind), child_slice });
        }
    }
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

    pub fn finish(self: @This(), allocator: std.mem.Allocator) !Cst {
        var threaded_tree: ?*ThreadedNode = try self.intoThreadedTree();

        var cst: Cst = .{ .nodes = .{}, .children = .{} };
        errdefer cst.deinit(allocator);

        while (threaded_tree) |threaded_node| : (threaded_tree = threaded_node.next) {
            if (threaded_node.index) |index|
                cst.children.items[index] = @enumFromInt(cst.nodes.len);
            const start: Start = if (threaded_node.children) |_|
                @enumFromInt(cst.children.items.len)
            else
                .token;
            const count = if (threaded_node.children) |c| c.items.len else 0;
            try cst.nodes.append(allocator, .{
                .kind = threaded_node.kind,
                .children = .{ .start = start, .count = count },
            });
            _ = try cst.children.addManyAsSlice(allocator, count);
            if (threaded_node.children) |c| {
                for (c.items, @intFromEnum(start)..) |child, index|
                    child.index = index;
            }
        }

        return cst;
    }

    const ThreadedNode = struct {
        kind: SyntaxKind,
        /// Null iff this is a token.
        children: ?std.ArrayListUnmanaged(*@This()),
        next: ?*@This() = null,
        index: ?usize = null,
    };

    fn intoThreadedTree(self: @This()) !*ThreadedNode {
        var stack: std.ArrayListUnmanaged(*ThreadedNode) = .empty;
        var prev: ?*ThreadedNode = null;
        var events = self.events;
        std.debug.assert(events.pop() == .close);
        const arena = events.allocator;
        for (events.items) |event| {
            switch (event) {
                .open => |kind| {
                    const node = try arena.create(ThreadedNode);
                    node.* = .{ .kind = kind, .children = .empty };
                    try stack.append(arena, node);
                    if (prev) |p| p.next = node;
                    prev = node;
                },
                .token => |kind| {
                    const node = try arena.create(ThreadedNode);
                    node.* = .{ .kind = kind, .children = null };
                    if (prev) |p| p.next = node;
                    prev = node;
                    try stack.items[stack.items.len - 1].children.?.append(arena, node);
                },
                .close => {
                    const child = stack.pop();
                    try stack.items[stack.items.len - 1].children.?.append(arena, child);
                },
            }
        }
        std.debug.assert(stack.items.len == 1);
        return stack.items[0];
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
