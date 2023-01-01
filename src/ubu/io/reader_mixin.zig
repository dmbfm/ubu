const std = @import("std");

pub fn ReaderMixin(comptime T: type, comptime E: type) type {
    return struct {
        pub fn readByte(self: T) E!u8 {
            var b: [1]u8 = undefined;
            var len = try self.read(&b);
            if (len == 0) {
                return error.EndOfStream;
            }

            return b[0];
        }

        pub fn stdReader(self: T) std.io.Reader(T, E, T.read) {
            return .{ .context = self };
        }
    };
}
