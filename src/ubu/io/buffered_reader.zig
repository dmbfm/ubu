const std = @import("std");
const peek_reader = @import("peek_reader.zig");
const PeekReader = peek_reader.PeekReader;
const Reader = @import("reader.zig").Reader;
const file_reader = @import("reader.zig").file_reader;
const FileReader = @import("reader.zig").FileReader;

//
pub fn BufferedReader(
    comptime ReaderType: anytype,
    comptime buffer_len: comptime_int,
) type {
    return struct {
        buf: [buffer_len]u8 = undefined,
        scratch: [buffer_len]u8 = undefined,
        len: usize = 0,
        cur: usize = 0,
        reader: ReaderType,

        const Self = @This();

        pub const Error = ReaderType.Error || error{PeekError};

        fn refill(self: *Self) Error!void {
            self.len = try self.reader.read(&self.buf);
            self.cur = 0;
        }

        pub fn read(self: *Self, buffer: []u8) Error!usize {
            var i: usize = 0;

            if (self.cur + buffer_len <= self.len) {
                @memcpy(buffer.ptr, self.buf[self.cur..].ptr, buffer.len);
                self.cur += buffer.len;
                return buffer.len;
            }

            while (i < buffer.len) {
                if (self.cur >= self.len) {
                    try self.refill();
                }

                if (self.len == 0) {
                    break;
                }

                buffer[i] = self.buf[self.cur];
                self.cur += 1;
                i += 1;
            }

            return i;
        }

        pub fn peek(self: *Self, out: []u8) Error!usize {
            if (self.cur >= self.len) {
                try self.refill();
            }

            var amount_to_peek = std.math.min(out.len, buffer_len);

            if (self.cur + amount_to_peek <= self.len) {
                @memcpy(out.ptr, self.buf[self.cur..].ptr, amount_to_peek);
                return amount_to_peek;
            }

            var amount_to_copy = self.len - self.cur;
            @memcpy(&self.scratch, self.buf[self.cur..].ptr, amount_to_copy);
            @memcpy(&self.buf, &self.scratch, amount_to_copy);
            self.len = amount_to_copy;
            self.len += try self.reader.read(self.buf[amount_to_copy..]);
            self.cur = 0;

            @memcpy(&self.buf, out.ptr, amount_to_peek);

            return amount_to_peek;
        }

        pub fn peek_reader(self: *Self) PeekReader(*Self, Error, read, peek) {
            return .{ .context = self };
        }

        pub fn reader(self: *Self) Reader(*Self, Error, read) {
            return .{ .context = self };
        }
    };
}

pub fn file_buffered_reader(f: std.fs.File, comptime buffer_len: comptime_int) BufferedReader(FileReader, buffer_len) {
    return .{ .reader = file_reader(f) };
}

const t = std.testing;

test "Buffered Peek Reader" {
    var f = try std.fs.cwd().openFile("test_data/file.txt", .{});
    var br = file_buffered_reader(f, 10);
    var r = br.peek_reader();
    // var ch = try r.read_byte();
    var ch = (try r.peek_byte()).?;
    try t.expect(ch == 'I');

    var b: [10]u8 = undefined;
    var len = try r.peek(&b);
    try t.expect(len == 10);
    try t.expect(std.mem.eql(u8, &b, "I just nee"));

    var b2: [20]u8 = undefined;
    len = try r.peek(&b2);
    try t.expect(len == 10);
    try t.expect(std.mem.eql(u8, b2[0..len], "I just nee"));
}
