const std = @import("std");

pub fn StaticByteWriter(comptime capacity: comptime_int) type {
    return struct {
        buf: [capacity]u8 = undefined,
        cur: usize = 0,

        const Self = @This();

        pub fn write(self: *Self, data: []const u8) !usize {
            if (self.cur >= capacity) {
                return 0;
            }

            var amount = @min(capacity - self.cur, data.len);
            @memcpy(self.buf[self.cur..].ptr, data.ptr, amount);
            self.cur += amount;
            return amount;
        }

        pub fn writer(self: *Self) std.io.Writer(*Self, error{}, Self.write) {
            return .{ .context = self };
        }
    };
}
