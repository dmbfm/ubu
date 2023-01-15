const std = @import("std");

pub fn PeekMixin(comptime T: type, comptime Error: type) type {
    _ = Error;
    return struct {
        pub fn peekByte(self: T) !u8 {
            var b: [1]u8 = undefined;
            var len = try self.peek(&b);
            if (len == 0) {
                return error.EndOfStream;
            }
            return b[0];
        }
    };
}
