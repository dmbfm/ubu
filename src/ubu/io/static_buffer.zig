const std = @import("std");
const io = @import("../io.zig");

pub fn StaticBuffer(comptime capacity: comptime_int) type {
    return struct {
        buffer: ?io.Buffer([]u8) = null,
        bytes: [capacity]u8 = undefined,

        const Self = @This();

        pub fn stream(self: *Self) io.Stream {
            if (self.buffer == null) {
                self.buffer = io.newBuffer(&self.bytes);
            }

            return self.buffer.?.stream();
        }

        pub fn read(self: *Self, buffer: []u8) !usize {
            if (self.buffer == null) {
                self.buffer = io.newBuffer(&self.bytes);
            }

            return self.buffer.?.read(buffer);
        }

        pub fn write(self: *Self, buffer: []const u8) !usize {
            if (self.buffer == null) {
                self.buffer = io.newBuffer(&self.bytes);
            }

            return self.buffer.?.write(buffer);
        }

        pub fn seek(self: *Self, relative_to: io.SeekRelativeTo, offset: i64) !usize {
            if (self.buffer == null) {
                self.buffer = io.newBuffer(&self.bytes);
            }

            return self.buffer.?.seek(relative_to, offset);
        }

        pub fn peek(self: *Self, buffer: []u8) !usize {
            if (self.buffer == null) {
                self.buffer = io.newBuffer(&self.bytes);
            }

            return self.buffer.?.peek(buffer);
        }

        pub fn skeip(self: *Self, amount: usize) !void {
            if (self.buffer == null) {
                self.buffer = io.newBuffer(&self.bytes);
            }

            return self.buffer.?.skip(amount);
        }

        pub usingnamespace io.ReaderMixin(*Self, io.StreamError);
        pub usingnamespace io.WriterMixin(*Self, io.StreamError);
        pub usingnamespace io.SeekMixin(*Self, io.StreamError);
        pub usingnamespace io.PeekMixin(*Self, io.StreamError);
        pub usingnamespace io.SkipMixin(*Self, io.StreamError);
    };
}

test "StaticBuffer" {
    var sb = StaticBuffer(10){};
    // var s = sb.stream();
    try sb.writeAll("Hello!");
    try sb.seekToStart();
    var b: [6]u8 = undefined;
    _ = try sb.read(&b);
    try std.testing.expect(std.mem.eql(u8, &b, "Hello!"));
}
