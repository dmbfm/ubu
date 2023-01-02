const std = @import("std");

// Read, Seek
pub fn SkipMixin(comptime T: type, comptime Error: type) type {
    _ = Error;
    return struct {
        pub fn skip(self: T, amount: usize) !void {
            var i: usize = 0;
            while (i < amount) {
                try self.skipByte();
                i += 1;
            }
        }

        pub fn skipByte(self: T) !void {
            _ = try self.readByte();
        }

        pub fn skipWhile(self: T, char: u8) !usize {
            var count: usize = 0;
            while (true) {
                var ch = try self.peekByte();
                if (ch != char) {
                    break;
                }

                try self.skipByte();
                count += 1;
            }
        }

        pub fn readWhile(self: T, buffer: []u8, char: u8) !usize {
            var count: usize = 0;
            while (true) {
                var ch = try self.peekByte();
                if (ch != char) {
                    break;
                }

                if (count >= buffer.len) {
                    return error.StreamTooLong;
                }

                buffer[count] = ch;
                try self.skipByte();
                count += 1;
            }
        }

        pub fn skipWhileOneOf(self: T, chars: []const u8) !usize {
            var count: usize = 0;
            while (true) {
                var ch = try self.peekByte();
                var found = false;
                for (chars) |char| {
                    if (ch == char) {
                        found = true;
                        break;
                    }
                }
                if (!found) {
                    break;
                }

                try self.skipByte();
                count += 1;
            }

            return count;
        }

        pub fn readWhileDigit(self: T, buffer: []u8) !usize {
            return self.readWhileOneOf(buffer, "0123456789");
        }

        pub fn readWhileOneOf(self: T, buffer: []u8, chars: []const u8) !usize {
            var count: usize = 0;
            while (true) {
                var ch = self.peekByte() catch |err| switch (err) {
                    error.EndOfStream => break,
                    else => return err,
                };

                var found = false;
                for (chars) |char| {
                    if (ch == char) {
                        found = true;
                        break;
                    }
                }

                if (!found) {
                    break;
                }

                if (count >= buffer.len) {
                    return error.StreamTooLong;
                }

                buffer[count] = ch;
                try self.skipByte();
                count += 1;
            }

            return count;
        }

        pub fn skipUntilAfterChar(self: T, char: u8) !usize {
            var count: usize = 0;
            while (true) {
                var ch = try self.readByte();
                if (ch == char) {
                    break;
                }

                count += 1;
            }

            return count;
        }

        pub fn skipLine(self: T) !void {
            _ = try self.skipUntilAfterChar('\n');
        }
    };
}
