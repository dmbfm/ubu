const std = @import("std");

pub const SeekRelativeTo = enum {
    Start,
    Current,
    End,
};

pub fn SeekMixin(
    comptime Self: type,
    comptime ErrorType: type,
) type {
    return struct {
        // pub fn seek(self: Self, relative_to: SeekRelativeTo, offset: i64) ErrorType!usize {
        // return seek_fn(self.context, relative_to, offset);
        // }

        pub fn seek_to_start(self: Self) ErrorType!void {
            _ = try self.seek(.Start, 0);
        }

        pub fn seek_to_end(self: Self) ErrorType!usize {
            return try self.seek(.End, 0);
        }

        pub fn step_back(self: Self) ErrorType!void {
            _ = try self.seek(.Current, -1);
        }
    };
}

test "Seek Reader" {}
