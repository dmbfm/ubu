const std = @import("std");
const expect = std.testing.expect;

pub fn WriterMixin(comptime T: type, comptime E: type) type {
    return struct {
        pub fn writeByte(self: T, byte: u8) E!void {
            var b = [_]u8{byte};
            _ = try self.write(&b);
        }

        pub fn writeAll(self: T, data: []const u8) E!void {
            var bytes_written: usize = 0;
            while (bytes_written != data.len) {
                bytes_written += try self.write(data[bytes_written..]);
            }
        }

        pub fn writeByteNTimes(self: T, byte: u8, n: usize) E!void {
            var buf: [128]u8 = undefined;
            @memset(buf[0..], byte, 128);
            var bytes_written: usize = 0;
            while (bytes_written < n) {
                var amount = std.math.min(n - bytes_written, 128);
                try self.writeAll(buf[0..amount]);
                bytes_written += amount;
            }
        }

        pub fn stdWriter(self: T) std.io.Writer(T, E, T.write) {
            return .{ .context = self };
        }
    };
}

test "writeByteNTimes" {
    const Counter = struct {
        count: usize = 0,

        const Self = @This();
        pub fn write(self: *Self, data: []const u8) !usize {
            self.count += data.len;
            return data.len;
        }
        pub usingnamespace WriterMixin(*Self, error{});
    };
    var c = Counter{};
    try c.writeByteNTimes(0, 10);
    try expect(c.count == 10);
}
