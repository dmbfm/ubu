const std = @import("std");

pub const ByteWriter = struct {
    buf: []u8,
    cur: usize = 0,

    const Self = @This();

    pub fn init(buffer: []u8) Self {
        return .{ .buf = buffer };
    }

    pub fn write(self: *Self, data: []const u8) !usize {
        if (self.cur >= self.buf.len) {
            return 0;
        }

        var amount = @min(self.buf.len - self.cur, data.len);
        @memcpy(self.buf[self.cur..].ptr, data.ptr, amount);
        self.cur += amount;
        return amount;
    }

    pub fn writer(self: *Self) std.io.Writer(*Self, error{}, Self.write) {
        return .{ .context = self };
    }
};
