nodes: std.MultiArrayList(struct {
    source: []const u8,
    kind: SyntaxKind,
    size: usize,
    parent: Node.Index,
}),

pub const Node = struct {
    index: Index,
    cst: Cst,

    pub fn source(node: Node) []const u8 {
        return node.cst.nodes.items(.source)[@intFromEnum(node.index)];
    }

    pub fn kind(node: Node) SyntaxKind {
        return node.cst.nodes.items(.kind)[@intFromEnum(node.index)];
    }

    pub fn parent(node: Node) ?Node {
        if (node.index == .root) return null;
        const index = node.cst.nodes.items(.parent)[@intFromEnum(node.index)];
        return .{ .index = index, .cst = node.cst };
    }

    pub fn children(node: Node) ChildIterator {
        const start = @intFromEnum(node.index);
        const end = start + node.cst.nodes.items(.size)[@intFromEnum(node.index)];
        return .{ .current = start + 1, .end = end, .cst = node.cst };
    }

    pub const ChildIterator = struct {
        current: usize,
        end: usize,
        cst: Cst,

        pub fn next(iter: *ChildIterator) ?Node {
            if (iter.current == iter.end) return null;
            defer iter.current += iter.cst.nodes.items(.size)[iter.current];
            return .{ .index = @enumFromInt(iter.current), .cst = iter.cst };
        }
    };

    pub const Index = enum(usize) { root = 0, _ };
};

pub const Builder = struct {
    source: [*]const u8,
    stack: std.ArrayList(Node.Index),
    cst: Cst,
    allocator: std.mem.Allocator,

    pub fn init(source: [*]const u8, allocator: std.mem.Allocator) Builder {
        return .{
            .source = source,
            .stack = .empty,
            .cst = .{ .nodes = .empty },
            .allocator = allocator,
        };
    }

    pub fn finish(builder: Builder) Cst {
        std.debug.assert(builder.stack.items.len == 0);
        var cst = builder.cst;

        const sizes = cst.nodes.items(.size);
        for (0..cst.nodes.len) |i| {
            var iter = @as(Node, .{ .index = @enumFromInt(i), .cst = cst }).children();
            while (iter.next()) |child| sizes[@intFromEnum(child.index)] = i;
        }

        return cst;
    }

    pub fn startNode(builder: *Builder, kind: SyntaxKind) !void {
        try builder.stack.ensureUnusedCapacity(builder.allocator, 1);
        try builder.cst.nodes.ensureUnusedCapacity(builder.allocator, 1);
        errdefer comptime unreachable;

        builder.stack.appendAssumeCapacity(@enumFromInt(builder.cst.nodes.len));
        builder.cst.nodes.appendAssumeCapacity(.{
            .source = builder.source[0..0],
            .kind = kind,
            .size = undefined,
            .parent = undefined,
        });
    }

    pub fn finishNode(builder: *Builder) !void {
        const index = @intFromEnum(builder.stack.pop().?);
        const source = &builder.cst.nodes.items(.source)[index];
        source.len = builder.source - source.ptr;
        builder.cst.nodes.items(.size)[index] = builder.cst.nodes.len - index;
    }

    pub fn token(builder: *Builder, kind: SyntaxKind, source_size: usize) !void {
        try builder.cst.nodes.ensureUnusedCapacity(builder.allocator, 1);
        errdefer comptime unreachable;

        builder.cst.nodes.appendAssumeCapacity(.{
            .source = builder.source[0..source_size],
            .kind = kind,
            .size = 1,
            .parent = undefined,
        });
        builder.source += source_size;
    }

    pub const Checkpoint = struct {
        index: Node.Index,
        source_start: [*]const u8,
    };

    pub fn makeCheckpoint(builder: Builder) Checkpoint {
        return .{ .index = @enumFromInt(builder.cst.nodes.len), .source_start = builder.source };
    }

    pub fn finishNodeAt(builder: *Builder, checkpoint: Checkpoint, kind: SyntaxKind) !void {
        try builder.cst.nodes.ensureUnusedCapacity(builder.allocator, 1);
        errdefer comptime unreachable;

        const size = builder.cst.nodes.len - @intFromEnum(checkpoint.index) + 1;
        builder.cst.nodes.appendAssumeCapacity(.{
            .source = checkpoint.source_start[0 .. builder.source - checkpoint.source_start],
            .kind = kind,
            .size = size,
            .parent = undefined,
        });
    }
};

const Cst = @This();

const std = @import("std");
const SyntaxKind = @import("syntax.zig").Kind;
