const std = @import("std");
const io = @import("../io.zig");

const GrowableBuffer = struct {
    buf: []u8 = undefined,
    allocator: std.mem.Allocator,
    cur: usize = 0,

    pub fn init(allocator: std.mem.Allocator) !GrowableBuffer {
        return initWithCapacity(allocator, 128);
    }

    pub fn initWithCapacity(allocator: std.mem.Allocator, cap: usize) !GrowableBuffer {
        return GrowableBuffer{
            .buf = try allocator.alloc(u8, cap),
            .allocator = allocator,
            .cur = 0,
        };
    }

    pub fn deinit(self: *GrowableBuffer) void {
        self.allocator.free(self.buf);
    }

    pub fn ensureCapacity(self: *GrowableBuffer, cap: usize) !void {
        if (cap > self.buf.len) {
            self.buf = try self.allocator.realloc(self.buf, @max(cap, 2 * self.buf.len));
        }
    }

    pub fn read(self: *GrowableBuffer, buffer: []u8) !usize {
        if (self.cur >= self.buf.len) {
            return 0;
        }

        var amount = @min(self.buf.len - self.cur, buffer.len);
        @memcpy(buffer.ptr, self.buf[self.cur..].ptr, amount);
        self.cur += amount;
        return amount;
    }

    pub fn write(self: *GrowableBuffer, data: []const u8) !usize {
        self.ensureCapacity(self.cur + data.len) catch return error.WriteError;
        @memcpy(self.buf[self.cur..].ptr, data.ptr, data.len);
        self.cur += data.len;
        return data.len;
    }

    pub fn peek(self: *GrowableBuffer, buffer: []u8) !usize {
        if (self.cur >= self.buf.len) {
            return 0;
        }

        var amount = @min(self.buf.len - self.cur, buffer.len);
        @memcpy(buffer.ptr, self.buf[self.cur..].ptr, amount);
        return amount;
    }

    pub fn seek(self: *GrowableBuffer, relative_to: io.SeekRelativeTo, offset: i64) !usize {
        switch (relative_to) {
            .start => {
                var _offset = @intCast(usize, offset);
                if (_offset >= self.buf.len) {
                    return error.SeekError;
                } else {
                    self.cur = _offset;
                }
            },
            .current => {
                var pos = @intCast(i64, self.cur) + offset;
                if (pos < 0 or pos >= self.buf.len) {
                    return error.SeekError;
                } else {
                    self.cur = @intCast(usize, pos);
                }
            },
            .end => {
                var pos = @intCast(i64, self.buf.len) + offset - 1;
                if (pos < 0 or pos >= self.buf.len) {
                    return error.SeekError;
                } else {
                    self.cur = @intCast(usize, pos);
                }
            },
        }
        return self.cur;
    }

    pub fn skip(self: *GrowableBuffer, amount: usize) !void {
        if (self.cur + amount >= self.buf.len) {
            return error.SkipError;
        }

        self.cur += amount;
    }

    pub fn stream(self: *GrowableBuffer) io.Stream {
        return io.Stream.init(self, .{
            .read = GrowableBuffer.read,
            .write = GrowableBuffer.write,
            .seek = GrowableBuffer.seek,
            .peek = GrowableBuffer.peek,
            .skip = GrowableBuffer.skip,
        });
    }
};

test "GrowableBuffer" {
    var g = try GrowableBuffer.init(std.testing.allocator);
    defer g.deinit();

    var s = g.stream();
    try s.writeAll("Hello!");
    try std.testing.expect(std.mem.eql(u8, g.buf[0..6], "Hello!"));
}
