const std = @import("std");

pub fn ReaderMixin(
    comptime T: type,
    comptime ErrorType: type,
) type {
    return struct {
        const Error = ErrorType || error{EndOfStream};

        const Self = T;

        pub fn read_byte(self: Self) Error!?u8 {
            var b: [1]u8 = undefined;
            var len = try self.read(&b);
            if (len == 0) {
                return null;
            }
            return b[0];
        }

        pub fn read_until_after(self: Self, delimiter: u8) Error!void {
            while (true) {
                var ch = try self.read_byte();
                if (ch == delimiter) {
                    break;
                }
            }
        }

        pub fn read_until_after_one_of(self: Self, delimiters: []const u8) Error!void {
            while (true) outer: {
                var ch = try self.read_byte();
                for (delimiters) |del| {
                    if (ch == del) {
                        break :outer;
                    }
                }
            }
        }

        pub fn skip(self: Self, num_bytes: usize) Error!void {
            var buffer: [512]u8 = undefined;
            var remaining = num_bytes;
            while (remaining > 0) {
                var max = std.math.min(remaining, buffer.len);
                var len = try self.read(buffer[0..max]);
                remaining -= len;
            }
        }

        pub fn skip_byte(self: Self) Error!void {
            return self.skip(1);
        }

        pub fn std_reader(self: Self) std.io.Reader(Self, Error, Self.read) {
            return .{ .context = self };
        }
    };
}

test "Simple Infinte Reader" {}

test "Simple Fixed Length Reader" {}

test "File Reader" {}
