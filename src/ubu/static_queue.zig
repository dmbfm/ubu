const std = @import("std");
const ubu = @import("../ubu.zig");

fn StaticQueue(comptime T: type, comptime capacity: comptime_int) type {
    return struct {
        nodes: NodePool = NodePool{},
        first: ?*Node = null,
        last: ?*Node = null,

        const Self = @This();
        const NodePool = ubu.IndexedPool(Node, capacity);

        const Node = struct {
            value: T = undefined,
            handle: ?NodePool.Handle = null,
            next: ?*Node = null,
            prev: ?*Node = null,
        };

        const Error = error{QueueFull} || NodePool.Error;

        pub fn count(self: *Self) usize {
            _ = self;
            return 0;
        }

        pub fn enqueue(self: *Self, item: T) Error!void {
            var handle = try self.nodes.alloc();
            var node = try self.nodes.get(handle);
            node.handle = handle;
            node.value = item;

            if (self.last == null) {
                self.first = node;
                self.last = node;
                node.next = null;
                node.prev = null;
            } else {
                var old_first = self.first;
                node.next = old_first;
                node.prev = null;
                old_first.?.prev = node;
                self.first = node;
            }
        }

        pub fn dequeue(self: *Self) ?T {
            if (self.last) |last_node| {
                var result = last_node.value;

                if (last_node.prev) |prev_last_node| {
                    self.last = prev_last_node;
                    prev_last_node.next = null;
                } else {
                    self.last = null;
                    self.first = null;
                }

                self.nodes.free(last_node.handle.?);

                return result;
            }

            return null;
        }
    };
}

const expect = std.testing.expect;

test "Queue" {
    var q = StaticQueue(u8, 32){};
    try q.enqueue(1);
    try q.enqueue(2);
    try q.enqueue(3);
    try q.enqueue(4);

    try expect(q.dequeue().? == 1);
    try q.enqueue(10);
    try q.enqueue(11);
    try expect(q.dequeue().? == 2);
    try expect(q.dequeue().? == 3);
    try q.enqueue(12);
    try expect(q.dequeue().? == 4);
    try expect(q.dequeue().? == 10);
    try expect(q.dequeue().? == 11);
    try expect(q.dequeue().? == 12);
    try expect(q.dequeue() == null);
}
