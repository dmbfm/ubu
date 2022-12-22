pub fn StaticStack(comptime T: type, comptime capacity: comptime_int) type {
    const Error = error{StackFull};

    return struct {
        items: [capacity]T = undefined,
        len: usize = 0,

        const Self = @This();

        pub fn push(self: *Self, item: T) Error!void {
            if (self.len >= capacity) {
                return error.StackFull;
            }

            defer self.len += 1;
            self.items[self.len] = item;
        }

        pub fn pop(self: *Self) ?T {
            if (self.len == 0) {
                return null;
            }

            defer self.len -= 1;
            return self.items[self.len - 1];
        }

        pub fn get_items(self: *Self) []T {
            return self.items[0..self.len];
        }
    };
}

const std = @import("std");
const expect = std.testing.expect;

test "FixedSizeStack" {
    var stack = StaticStack(u8, 5){};
    try stack.push(1);
    try stack.push(2);
    try stack.push(3);
    try stack.push(4);
    try stack.push(5);

    var failed = false;
    stack.push(6) catch {
        failed = true;
    };
    try expect(failed);

    try expect(stack.pop().? == 5);
    try expect(stack.pop().? == 4);
    try expect(stack.pop().? == 3);
    try expect(stack.pop().? == 2);
    try expect(stack.pop().? == 1);
    try expect(stack.pop() == null);
}
