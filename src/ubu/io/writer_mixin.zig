const std = @import("std");

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

        pub fn stdWriter(self: T) std.io.Writer(T, E, T.write) {
            return .{ .context = self };
        }
    };
}
