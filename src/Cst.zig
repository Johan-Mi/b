nodes: std.MultiArrayList(struct {
    source: ?[]const u8,
    kind: SyntaxKind,
    parent: ?Node.Index,
    /// Indices into `Cst.children`.
    children: struct { start: Start, count: usize },
}),
children: std.ArrayListUnmanaged(Node.Index),

const Start = enum(usize) {
    token = std.math.maxInt(usize),
    _,
};

pub const Node = struct {
    index: Index,
    cst: Cst,

    pub fn source(node: Node) []const u8 {
        return node.cst.nodes.items(.source)[@intFromEnum(node.index)].?;
    }

    pub fn kind(node: Node) SyntaxKind {
        return node.cst.nodes.items(.kind)[@intFromEnum(node.index)];
    }

    pub fn parent(node: Node) ?Node {
        const index = node.cst.nodes.items(.parent)[@intFromEnum(node.index)] orelse return null;
        return .{ .index = index, .cst = node.cst };
    }

    pub fn children(node: Node) ChildIterator {
        const range = node.cst.nodes.items(.children)[@intFromEnum(node.index)];
        std.debug.assert(range.start != .token);
        const start = @intFromEnum(range.start);
        return .{ .start = start, .end = start + range.count, .cst = node.cst };
    }

    pub const ChildIterator = struct {
        start: usize,
        end: usize,
        cst: Cst,

        pub fn next(iter: *ChildIterator) ?Node {
            if (iter.start < iter.end) {
                defer iter.start += 1;
                return .{ .index = iter.cst.children.items[iter.start], .cst = iter.cst };
            } else return null;
        }
    };

    pub const Index = enum(usize) { root = 0, _ };
};

pub fn dump(cst: Cst) void {
    const nodes = cst.nodes.slice();
    for (0.., nodes.items(.kind), nodes.items(.children)) |i, kind, children| {
        if (children.start == .token) {
            log.info("{}: {s}", .{ i, @tagName(kind) });
        } else {
            const child_slice =
                cst.children.items[@intFromEnum(children.start)..][0..children.count];
            log.info("{}: {s} {any}", .{ i, @tagName(kind), child_slice });
        }
    }
}

pub const Builder = struct {
    events: std.ArrayListUnmanaged(Event) = .empty,
    arena: std.mem.Allocator,

    const Event = union(enum) {
        open: SyntaxKind,
        token: struct {
            source: []const u8,
            kind: SyntaxKind,
        },
        close,
    };

    pub fn init(arena: std.mem.Allocator) Builder {
        return .{ .arena = arena };
    }

    pub fn finish(builder: Builder, allocator: std.mem.Allocator) !Cst {
        var threaded_tree: ?*ThreadedNode = try builder.intoThreadedTree();

        var cst: Cst = .{ .nodes = .empty, .children = .empty };

        while (threaded_tree) |threaded_node| : (threaded_tree = threaded_node.next) {
            if (threaded_node.index) |index|
                cst.children.items[index] = @enumFromInt(cst.nodes.len);
            const start: Start = if (threaded_node.children) |_|
                @enumFromInt(cst.children.items.len)
            else
                .token;
            const count = if (threaded_node.children) |c| c.items.len else 0;
            const me = cst.nodes.len;
            try cst.nodes.append(allocator, .{
                .source = threaded_node.source,
                .kind = threaded_node.kind,
                .parent = threaded_node.parent,
                .children = .{ .start = start, .count = count },
            });
            _ = try cst.children.addManyAsSlice(allocator, count);
            if (threaded_node.children) |c| {
                for (c.items, @intFromEnum(start)..) |child, index| {
                    child.parent = @enumFromInt(me);
                    child.index = index;
                }
            }
        }

        return cst;
    }

    const ThreadedNode = struct {
        source: ?[]const u8,
        kind: SyntaxKind,
        parent: ?Node.Index = null,
        /// Null iff this is a token.
        children: ?std.ArrayListUnmanaged(*ThreadedNode),
        next: ?*ThreadedNode = null,
        index: ?usize = null,
    };

    fn intoThreadedTree(builder: Builder) !*ThreadedNode {
        var stack: std.ArrayListUnmanaged(*ThreadedNode) = .empty;
        var prev: ?*ThreadedNode = null;
        var events = builder.events;
        std.debug.assert(events.pop().? == .close);
        const arena = builder.arena;
        for (events.items) |event| {
            switch (event) {
                .open => |kind| {
                    const node = try arena.create(ThreadedNode);
                    node.* = .{ .source = null, .kind = kind, .children = .empty };
                    try stack.append(arena, node);
                    if (prev) |p| p.next = node;
                    prev = node;
                },
                .token => |it| {
                    const node = try arena.create(ThreadedNode);
                    node.* = .{ .source = it.source, .kind = it.kind, .children = null };
                    if (prev) |p| p.next = node;
                    prev = node;
                    try stack.items[stack.items.len - 1].children.?.append(arena, node);
                },
                .close => {
                    const child = stack.pop().?;
                    try stack.items[stack.items.len - 1].children.?.append(arena, child);
                },
            }
        }
        std.debug.assert(stack.items.len == 1);
        return stack.items[0];
    }

    pub fn startNode(builder: *Builder, kind: SyntaxKind) !void {
        try builder.events.append(builder.arena, .{ .open = kind });
    }

    pub fn finishNode(builder: *Builder) !void {
        try builder.events.append(builder.arena, .close);
    }

    pub fn token(builder: *Builder, kind: SyntaxKind, text: []const u8) !void {
        try builder.events.append(builder.arena, .{ .token = .{ .source = text, .kind = kind } });
    }

    pub const Checkpoint = enum(usize) { _ };

    pub fn makeCheckpoint(builder: Builder) Checkpoint {
        return @enumFromInt(builder.events.items.len);
    }

    pub fn startNodeAt(builder: *Builder, checkpoint: Checkpoint, kind: SyntaxKind) !void {
        try builder.events.insert(builder.arena, @intFromEnum(checkpoint), .{ .open = kind });
    }
};

const Cst = @This();

const std = @import("std");
const SyntaxKind = @import("syntax.zig").Kind;
const log = std.log.scoped(.cst);
