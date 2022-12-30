const std = @import("std");
const reader = @import("reader.zig");
const ReaderMixin = reader.ReaderMixin;

pub fn PeekMixin(
    comptime Self: type,
    comptime ErrorType: type,
) type {
    return struct {
        // pub fn peek(self: Self, buffer: []u8) ErrorType!usize {
        // return peek_fn(self.context, buffer);
        // }

        pub fn peekByte(self: Self) ErrorType!?u8 {
            var b: [1]u8 = undefined;
            var len = try self.peek(&b);
            if (len == 1) {
                return b[0];
            } else return null;
        }
    };
}

test "Peek Reader" {}
