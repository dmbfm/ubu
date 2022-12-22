fn StaticQueue(comptime T: type, comptime capacity: comptime_int) type {
    const Error = error{QueueFull};

    return struct {
        items: [capacity]T = undefined,
        tail: usize = 0,
        head: usize = 0,

        const Self = @This();

        fn enqueue_head(self: *Self, item: T) Error!void {
            if (self.head >= capacity) {
                return error.QueueFull;
            }

            defer self.head += 1;
            self.items[self.head] = item;
        }

        fn enqueue_tail(self: *Self, item: T) Error!void {
            if (self.tail == 0) {
                return error.QueueFull;
            }

            self.tail -= 1;
            self.items[self.tail] = item;
        }

        pub fn count(self: *Self) usize {
            return self.head - self.tail;
        }

        pub fn enqueue(self: *Self, item: T) Error!void {
            if (self.tail == 0) {
                return self.enqueue_head(item);
            } else {
                return self.enqueue_tail(item);
            }
        }

        pub fn dequeue(self: *Self) ?T {
            if (self.tail == self.head) {
                return null;
            }

            defer self.tail += 1;
            return self.items[self.tail];
        }
    };
}

const std = @import("std");
const expect = std.testing.expect;

test "Queue" {
    var q = StaticQueue(u8, 10){};
    try q.enqueue(1);
    try q.enqueue(2);
    try q.enqueue(3);
    try q.enqueue(4);

    try expect(q.dequeue().? == 1);
    try expect(q.dequeue().? == 2);
    try expect(q.dequeue().? == 3);
    try expect(q.dequeue().? == 4);
    try expect(q.dequeue() == null);
}
