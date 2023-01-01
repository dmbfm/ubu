const std = @import("std");
const io = @import("../io.zig");

pub fn BufferedFile(comptime buffer_len: comptime_int) type {
    return struct {
        /// The std file object
        file: std.fs.File,
        /// The buffer used for reading. By default it is a view into
        /// `backing_buffer`.
        buffer: ?[]u8 = null,
        /// This is a slice of `buffer` which contains the filled data. This is
        /// because when we are near the end of the file this can have a length
        /// that is less than the length of `buffer`.
        filled_slice: []u8 = &[0]u8{},
        /// The default backing buffer.
        backing_buffer: [buffer_len]u8 = undefined,
        /// The mode for this file, either `read` or `write`.
        mode: Mode,
        /// The current read or write position inside the buffer.
        cur: usize = 0,

        const Mode = enum {
            read,
            write,
        };

        const Self = @This();

        pub const Error = error{InvalidMode} || std.fs.File.OpenError || std.fs.File.ReadError || std.fs.File.WriteError;

        pub fn open(path: []const u8) !Self {
            var file = try std.fs.cwd().openFile(path, .{});
            var result = Self{ .file = file, .mode = .read };
            return result;
        }

        pub fn create(path: []const u8) !Self {
            var file = try std.fs.cwd().createFile(path, .{});
            var result = Self{ .file = file, .mode = .write };
            return result;
        }

        pub fn fromStdFile(file: std.fs.File, mode: Mode) Self {
            var result = .{ .file = file, .mode = mode };
            return result;
        }

        pub fn close(self: *Self) void {
            if (self.mode == .write) {
                // TODO: Is there a better solution? I would not like to change
                // the signature of `close` to `!void`...
                self.flush() catch unreachable;
            }

            self.file.close();
        }

        pub fn fillBuffer(self: *Self) !void {
            if (self.mode != .read) {
                return error.InvalidMode;
            }

            if (self.buffer == null) {
                self.buffer = &self.backing_buffer;
            }

            var len = try self.file.read(self.buffer.?);
            self.filled_slice = self.buffer.?[0..len];
            self.cur = 0;
        }

        pub fn setBackingBuffer(self: *Self, buffer: []u8) void {
            self.buffer = buffer;
        }

        pub fn read(self: *Self, out: []u8) !usize {
            if (self.mode != .read) {
                return Error.InvalidMode;
            }

            if (self.buffer == null) {
                self.buffer = &self.backing_buffer;
            }

            var bytes_read: usize = 0;
            while (bytes_read < out.len) {
                if (self.cur >= self.filled_slice.len) {
                    try self.fillBuffer();
                }

                var avail = self.filled_slice.len - self.cur;
                var amount_to_copy = std.math.min(avail, out.len - bytes_read);
                if (amount_to_copy == 0) {
                    break;
                }

                @memcpy(out[bytes_read..].ptr, self.filled_slice[self.cur..].ptr, amount_to_copy);

                bytes_read += amount_to_copy;
                self.cur += amount_to_copy;
            }

            return bytes_read;
        }

        pub fn readLine(self: *Self, out: []u8) !usize {
            var bytes_written: usize = 0;
            while (bytes_written < out.len) {
                var ch = self.readByte() catch |err| switch (err) {
                    error.EndOfStream => break,
                    else => return err,
                };

                if (ch == '\n') {
                    break;
                }

                out[bytes_written] = ch;
                bytes_written += 1;
            }

            return bytes_written;
        }

        pub fn readByte(self: *Self) !u8 {
            var b: [1]u8 = undefined;
            var len = try self.read(&b);
            if (len == 0) {
                return error.EndOfStream;
            }
            return b[0];
        }

        pub fn flush(self: *Self) !void {
            try self.file.writeAll(self.buffer.?[0..self.cur]);
            self.cur = 0;
        }

        pub fn write(self: *Self, data: []const u8) !usize {
            if (self.mode != .write) {
                return Error.InvalidMode;
            }

            if (self.buffer == null) {
                self.buffer = &self.backing_buffer;
            }

            var bytes_written: usize = 0;
            while (bytes_written < data.len) {
                if (self.cur >= self.buffer.?.len) {
                    try self.flush();
                }

                var space_in_buffer = self.buffer.?.len - self.cur;
                var remaining = data.len - bytes_written;
                var amount = std.math.min(space_in_buffer, remaining);

                @memcpy(self.buffer.?[self.cur..].ptr, data[bytes_written..].ptr, amount);
                self.cur += amount;
                bytes_written += amount;
            }

            if (self.cur >= self.buffer.?.len) {
                try self.flush();
            }

            return bytes_written;
        }

        pub fn writeByte(self: *Self, byte: u8) !void {
            var b = [_]u8{byte};
            var len = try self.write(&b);
            if (len == 0) {
                return Error.WriteError;
            }
        }

        pub fn writeAllUnbuffered(self: *Self, data: []const u8) !void {
            try self.file.writeAll(data);
        }

        pub fn writeAll(self: *Self, data: []const u8) !void {
            _ = try self.write(data);
        }

        pub fn print(self: *Self, comptime format: []const u8, args: anytype) !void {
            try std.fmt.format(self.stdWriter(), format, args);
        }

        pub fn stdWriter(self: *Self) std.io.Writer(*Self, Error, Self.write) {
            return .{ .context = self };
        }

        pub fn stdReader(self: *Self) std.io.Reader(*Self, Error, Self.read) {
            return .{ .context = self };
        }

        pub fn stream(self: *Self) io.Stream {
            return switch (self.mode) {
                .read => io.Stream.init(self, .{
                    .read = Self.read,
                    // .peek = Self.peek,
                    // .seek = Self.seek,
                }),
                .write => io.Stream.init(self, .{
                    .write = Self.write,
                    // .seek = Self.seek,
                }),
            };
        }
    };
}

pub const File = BufferedFile(1024 * 4);

const t = std.testing;
const eql = std.mem.eql;

test "BufferedFile read" {
    var f = try BufferedFile(16).open("test_data/file.txt");
    defer f.close();

    var buf: [81]u8 = undefined;
    var len = try f.read(&buf);
    try t.expect(len == 81);
    try t.expect(eql(u8, buf[0..len], "I just need some random text to test my zig library with and I can go from there."));
}

test "BufferedFile write" {
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
    var len = try f.readLine(&buf);
    try t.expect(eql(u8, buf[0..len], "I just need some random text to test my zig library with and I can go from there."));
}
