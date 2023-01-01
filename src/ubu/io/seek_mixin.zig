const std = @import("std");

pub fn SeekMixin(comptime T: type, comptime E: type) type {
    return struct {
        pub fn seekFromStart(self: T, offset: usize) E!void {
            _ = try self.seek(.start, @intCast(i64, offset));
        }

        pub fn seekFromEnd(self: T, offset: i64) E!usize {
            return self.seek(.end, offset);
        }

        pub fn seekToStart(self: T) E!void {
            _ = try self.seek(.start, 0);
        }

        pub fn seekFromCurrent(self: T, offset: i64) E!usize {
            return self.seek(.current, offset);
        }

        pub fn stepBack(self: T) E!void {
            _ = try self.seekFromCurrent(-1);
        }
    };
}
