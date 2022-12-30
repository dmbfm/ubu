const std = @import("std");

pub fn WriterMixin(comptime T: type, comptime ErrorType: type) type {
    return struct {
        // pub fn write(self: T, data: []const u8) ErrorType!usize {}

        const Self = T;

        pub fn writeByte(self: Self, byte: u8) ErrorType!void {
            var b: [1]u8 = [1]u8{byte};
            _ = try self.write(&b);
        }

        pub fn writeAll(self: Self, data: []const u8) ErrorType!void {
            _ = try self.write(data);
        }

        pub fn writeByteNTimes(self: Self, byte: u8, amount: usize) ErrorType!void {
            var buf: [256]u8 = undefined;
            @memset(&buf, byte, 256);
            var rem = amount;
            while (rem > 0) {
                var len = std.math.min(256, rem);
                try self.writeAll(buf[0..len]);
                rem -= len;
            }
        }

        pub fn print(self: Self, comptime format: []const u8, args: anytype) ErrorType!void {
            return std.fmt.format(self.stdWriter(), format, args);
        }

        pub fn stdWriter(self: Self) std.io.Writer(Self, ErrorType, Self.write) {
            return .{ .context = self };
        }
    };
}
