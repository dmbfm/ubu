const std = @import("std");
const fs = @import("../fs.zig");
const io = @import("../io.zig");

pub const FileMode = enum {
    read,
    write,
};

pub const File = BufferedFile(1024 * 1024);

pub fn BufferedFile(comptime buffer_len: comptime_int) type {
    return struct {
        file: std.fs.File,
        buf: [buffer_len]u8 = [_]u8{'@'} ** buffer_len,
        filled_slice: ?[]u8 = null,
        cur: usize = 0,
        mode: FileMode,

        const Self = @This();

        pub const WriteError = std.fs.File.WriteError || error{InvalidMode};
        pub const ReadError = std.fs.File.ReadError || error{InvalidMode};
        pub const Writer = std.io.Writer(*Self, WriteError, Self.write);
        pub const Reader = std.io.Reader(*Self, ReadError, Self.read);

        pub fn open(path: []const u8) !Self {
            var f = try fs.openFile(path);
            return .{ .file = f, .mode = .read };
        }

        pub fn create(path: []const u8) !Self {
            var f = try fs.createFile(path);
            return .{ .file = f, .mode = .write };
        }

        pub fn close(self: *Self) void {
            if (self.mode == .write) {
                self.flush() catch {};
            }
            return self.file.close();
        }

        pub fn fillBuffer(self: *Self) !void {
            if (self.mode != .read) {
                return error.InvalidMode;
            }

            var len = try self.file.read(&self.buf);
            self.filled_slice = self.buf[0..len];
            self.cur = 0;
        }

        pub fn read(self: *Self, buffer: []u8) !usize {
            if (self.mode != .read) {
                return error.InvalidMode;
            }

            if (self.filled_slice == null or self.cur >= self.filled_slice.?.len) {
                try self.fillBuffer();
            }

            var bytes_read: usize = 0;
            while (bytes_read < buffer.len) {
                if (self.cur >= self.filled_slice.?.len) {
                    try self.fillBuffer();
                }

                if (self.filled_slice.?.len == 0) {
                    break;
                }

                var remaining = buffer.len - bytes_read;
                var amount = @min(self.filled_slice.?.len - self.cur, remaining);
                @memcpy(buffer[bytes_read..].ptr, self.filled_slice.?[self.cur..].ptr, amount);
                self.cur += amount;
                bytes_read += amount;
            }

            return bytes_read;
        }

        pub fn flush(self: *Self) !void {
            if (self.mode != .write) {
                return error.InvalidMode;
            }

            if (self.cur == 0) {
                return;
            }

            try self.file.writeAll(self.buf[0..self.cur]);
            self.cur = 0;
        }

        pub fn write(self: *Self, data: []const u8) !usize {
            if (self.mode != .write) {
                return error.InvalidMode;
            }

            var bytes_written: usize = 0;
            while (bytes_written < data.len) {
                if (self.cur >= self.buf.len) {
                    try self.flush();
                }

                var amount = @min(self.buf.len - self.cur, data.len - bytes_written);
                @memcpy(self.buf[self.cur..].ptr, data[bytes_written..].ptr, amount);
                self.cur += amount;
                bytes_written += amount;
            }

            try self.flush();

            return bytes_written;
        }

        fn seekReadMode(self: *Self, relative_to: io.SeekRelativeTo, offset: i64) !void {
            switch (relative_to) {
                .start => {
                    try self.file.seekTo(@intCast(u64, offset));
                    try self.fillBuffer();
                },
                .current => {
                    if (@intCast(i64, self.cur) + offset >= 0 and @intCast(i64, self.cur) + offset < self.filled_slice.?.len) {
                        self.cur = @intCast(usize, @intCast(i64, self.cur) + offset);
                    } else {
                        var p = try self.getPos();
                        var pos = @intCast(u64, @intCast(i64, p - (self.filled_slice.?.len - self.cur)) + offset);
                        try self.file.seekTo(pos);
                        try self.fillBuffer();
                    }
                },
                .end => {
                    try self.file.seekFromEnd(offset);
                    try self.fillBuffer();
                },
            }
        }

        fn seekWriteMode(self: *Self, relative_to: io.SeekRelativeTo, offset: i64) !void {
            switch (relative_to) {
                .start => {
                    try self.flush();
                    try self.file.seekTo(@intCast(u64, offset));
                },
                .current => {
                    try self.flush();
                    try self.file.seekBy(offset);
                },
                .end => {
                    try self.flush();
                    try self.file.seekFromEnd(offset);
                },
            }
        }

        pub fn seek(self: *Self, relative_to: io.SeekRelativeTo, offset: i64) !void {
            if (self.mode == .read) {
                return self.seekReadMode(relative_to, offset);
            } else {
                return self.seekWriteMode(relative_to, offset);
            }
        }

        pub fn getPos(self: *Self) !u64 {
            return self.file.getPos();
        }

        pub fn peek(self: *Self, buffer: []u8) !usize {
            var len = try self.read(buffer);
            try self.seek(.current, -@intCast(i64, len));
            return len;
        }

        pub fn writeAll(self: *Self, data: []const u8) !void {
            _ = try self.write(data);
        }

        pub fn writer(self: *Self) Writer {
            return .{ .context = self };
        }

        pub usingnamespace io.ReaderMixin(*Self, ReadError);
        pub usingnamespace io.PeekMixin(*Self, error{});
        pub usingnamespace io.SkipMixin(*Self, error{});

        pub fn print(self: *Self, comptime format: []const u8, args: anytype) !void {
            return self.writer().print(format, args);
        }
    };
}

const t = std.testing;
const eql = std.mem.eql;

test "BufferedFile/read" {
    var f = try BufferedFile(16).open("test_data/file.txt");
    defer f.close();

    var buf: [81]u8 = undefined;
    var len = try f.read(&buf);
    try t.expect(len == 81);
    try t.expect(eql(u8, buf[0..len], "I just need some random text to test my zig library with and I can go from there."));
}

test "BufferedFile/write" {
    var f = try BufferedFile(16).create("test_data/buffered_file_write.txt");
    try f.writeAll("hello!");
    try f.print("  x = {}", .{10});
    f.close();

    f = try BufferedFile(16).open("test_data/buffered_file_write.txt");
    defer f.close();

    var b: [128]u8 = undefined;
    var len = try f.read(&b);
    try t.expect(eql(u8, b[0..len], "hello!  x = 10"));
}

test "BufferedFile readLine" {
    var f = try BufferedFile(4).open("test_data/file.txt");
    var buf: [128]u8 = undefined;
    var s = try f.readLine(&buf);
    try t.expect(eql(u8, s, "I just need some random text to test my zig library with and I can go from there."));
    s = try f.readLine(&buf);
    try t.expect(s.len == 0);
    s = try f.readLine(&buf);
    try t.expect(eql(u8, s, "Of course, if anyone wants to send me some random text, I am willing to get it out of the way!"));
    s = try f.readLine(&buf);
    try t.expect(s.len == 0);
    s = try f.readLine(&buf);
    try t.expect(eql(u8, s, "I was finally able to test out one of the pieces of the Zinfandel Beer Bread recipe."));
    s = try f.readLine(&buf);
    var buf2: [6]u8 = undefined;
    try t.expectError(error.StreamTooLong, f.readLine(&buf2));
}

test "BufferedFile readLineAlloc" {
    var allocator = t.allocator;

    var f = try BufferedFile(4).open("test_data/file.txt");
    var buf = try f.readLineAlloc(allocator);
    try t.expect(eql(u8, buf[0..], "I just need some random text to test my zig library with and I can go from there."));
    allocator.free(buf);

    buf = try f.readLineAlloc(allocator);
    try t.expect(buf.len == 0);
    allocator.free(buf);

    buf = try f.readLineAlloc(allocator);
    try t.expect(eql(u8, buf[0..], "Of course, if anyone wants to send me some random text, I am willing to get it out of the way!"));
    allocator.free(buf);

    buf = try f.readLineAlloc(allocator);
    try t.expect(buf.len == 0);
    allocator.free(buf);

    buf = try f.readLineAlloc(allocator);
    try t.expect(eql(u8, buf[0..], "I was finally able to test out one of the pieces of the Zinfandel Beer Bread recipe."));
    allocator.free(buf);
}

test "BufferedFile readLinesAlloc" {
    var allocator = t.allocator;
    var f = try BufferedFile(4).open("test_data/file.txt");
    var lines = try f.readLinesAlloc(allocator);

    try t.expect(lines.len == 35);
    try t.expect(eql(u8, lines[0], "I just need some random text to test my zig library with and I can go from there."));
    try t.expect(eql(u8, lines[1], ""));
    try t.expect(eql(u8, lines[28], "This bread was awesome because the crust was so crusty!"));

    defer {
        for (lines) |line| {
            allocator.free(line);
        }
        allocator.free(lines);
    }
}

test "BufferedFile peek" {
    var f = try BufferedFile(16).open("test_data/file.txt");
    defer f.close();

    var buf: [81]u8 = undefined;
    var len = try f.peek(&buf);
    try t.expect(len == 81);
    try t.expect(eql(u8, buf[0..len], "I just need some random text to test my zig library with and I can go from there."));

    len = try f.peek(&buf);
    try t.expect(len == 81);
    // std.log.err("'{s}'", .{buf[0..len]});
    try t.expect(eql(u8, buf[0..len], "I just need some random text to test my zig library with and I can go from there."));
}

test "BufferedFile skip" {
    var f = try BufferedFile(16).open("test_data/file.txt");
    defer f.close();

    try f.skip(4);
    var buf: [77]u8 = undefined;
    var len = try f.peek(&buf);
    try t.expect(len == 77);
    try t.expect(eql(u8, buf[0..len], "st need some random text to test my zig library with and I can go from there."));
    // try f.skip();
}

test "BufferedFile/skipWhileOneOf" {
    var f = try BufferedFile(16).open("test_data/file.txt");
    defer f.close();

    _ = try f.skipWhileOneOf("I justend");
    var buf: [68]u8 = undefined;
    var len = try f.peek(&buf);
    try t.expect(eql(u8, buf[0..len], "ome random text to test my zig library with and I can go from there."));
}
