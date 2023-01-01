const std = @import("std");

pub fn PeekMixin(comptime T: type, comptime E: type) type {
    return struct {
        pub fn peekByte(self: T) E!u8 {
            var b: [1]u8 = undefined;
            var len = try self.peek(&b);
            if (len == 0) {
                return error.EndOfStream;
            }

            return b[0];
        }
    };
}
