const std = @import("std");
const io = @import("../io.zig");

pub const ByteReader = struct {
    buf: []const u8,
    cur: usize = 0,

    const Self = @This();

    pub const Error = error{SeekError};

    pub fn init(data: []const u8) Self {
        return .{ .buf = data };
    }

    pub fn read(self: *Self, buffer: []u8) !usize {
        if (self.cur >= self.buf.len) {
            return 0;
        }

        var amount = @min(self.buf.len - self.cur, buffer.len);
        @memcpy(buffer.ptr, self.buf[self.cur..].ptr, amount);
        self.cur += amount;
        return amount;
    }

    pub fn peek(self: *Self, buffer: []u8) !usize {
        if (self.cur >= self.buf.len) {
            return 0;
        }

        var amount = @min(self.buf.len - self.cur, buffer.len);
        @memcpy(buffer.ptr, self.buf[self.cur..].ptr, amount);
        return amount;
    }

    pub fn seek(self: *Self, relative_to: io.SeekRelativeTo, offset: i64) !void {
        switch (relative_to) {
            .start => {
                var final = offset;
                if (final < 0 or final >= self.buf.len) {
                    return error.SeekError;
                }

                self.cur = @intCast(usize, offset);
            },
            .current => {
                var final = @intCast(i64, self.cur) + offset;
                if (final < 0 or final >= self.buf.len) {
                    return error.SeekError;
                }

                self.cur = @intCast(usize, offset);
            },
            .end => {
                var final = @intCast(i64, self.buf.len - 1) + offset;
                if (final < 0 or final >= self.buf.len) {
                    return error.SeekError;
                }

                self.cur = @intCast(usize, offset);
            },
        }
    }

    pub usingnamespace io.ReaderMixin(*Self, Error);
    pub usingnamespace io.PeekMixin(*Self, Error);
    pub usingnamespace io.SkipMixin(*Self, Error);
};

const expect = std.testing.expect;

test "ByteReader/read" {
    var b = ByteReader.init("pub fn main() !void {}");
    {
        var ch = try b.readByte();
        try expect(ch == 'p');
    }
    {
        var buf: [6]u8 = undefined;
        var len = try b.read(&buf);
        try expect(std.mem.eql(u8, buf[0..len], "ub fn "));
    }
    {
        var buf: [18]u8 = undefined;
        var line = try b.readLine(&buf);
        try expect(std.mem.eql(u8, line, "main() !void {}"));
    }
}
