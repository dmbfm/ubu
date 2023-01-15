const std = @import("std");

pub fn ReaderMixin(comptime T: type, comptime Error: type) type {
    return struct {
        pub fn readByte(self: T) !u8 {
            var b: [1]u8 = undefined;
            var len = try self.read(&b);
            if (len == 0) {
                return error.EndOfStream;
            }
            return b[0];
        }

        pub fn readLine(self: T, buffer: []u8) ![]u8 {
            var cur: usize = 0;
            while (self.readByte()) |ch| {
                if (ch == '\n') {
                    break;
                } else {
                    if (cur >= buffer.len) {
                        return error.StreamTooLong;
                    }
                    buffer[cur] = ch;
                    cur += 1;
                }
            } else |_| {}

            return buffer[0..cur];
        }

        pub fn readLineAlloc(self: T, allocator: std.mem.Allocator) ![]u8 {
            var arr = try std.ArrayList(u8).initCapacity(allocator, 128);
            errdefer arr.deinit();

            while (self.readByte()) |ch| {
                if (ch == '\n') {
                    break;
                } else {
                    try arr.append(ch);
                }
            } else |err| {
                switch (err) {
                    error.EndOfStream => {
                        if (arr.items.len == 0) {
                            return err;
                        }
                    },
                    else => return err,
                }
            }

            return arr.toOwnedSlice();
        }

        pub fn readLinesAlloc(self: T, allocator: std.mem.Allocator) ![][]u8 {
            var lines = try std.ArrayList([]u8).initCapacity(allocator, 64);
            errdefer lines.deinit();
            while (true) {
                var line = self.readLineAlloc(allocator) catch |err| switch (err) {
                    error.EndOfStream => break,
                    else => return err,
                };

                try lines.append(line);
            }
            return lines.toOwnedSlice();
        }

        pub fn reader(self: T) std.io.Reader(T, Error, T.read) {
            return .{ .context = self };
        }
    };
}
