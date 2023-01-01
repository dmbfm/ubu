const std = @import("std");
const io = @import("../io.zig");

pub fn Buffer(comptime T: type) type {
    return struct {
        buf: BufferType(T) = undefined,
        cur: usize = 0,
        const Self = @This();

        pub fn initWithBuffer(buffer: anytype) BufferType(@TypeOf(buffer)) {
            return switch (BufferType(@TypeOf(buffer))) {
                .Array => .{ .buf = buffer },
                .Pointer => .{ .buf = std.mem.span(buffer) },
                else => @compileError("yyy"),
            };
        }

        pub fn read(self: *Self, buffer: []u8) !usize {
            if (self.cur >= self.buf.len) {
                return 0;
            }

            var amount = @min(self.buf.len - self.cur, buffer.len);
            @memcpy(buffer.ptr, self.buf[self.cur..].ptr, amount);
            self.cur += amount;
            return amount;
        }

        pub fn peek(self: *Self, buffer: []u8) !usize {
            if (self.cur >= self.buf.len) {
                return 0;
            }

            var amount = @min(self.buf.len - self.cur, buffer.len);
            @memcpy(buffer.ptr, self.buf[self.cur..].ptr, amount);
            return amount;
        }

        pub fn seek(self: *Self, relative_to: io.SeekRelativeTo, offset: i64) !usize {
            switch (relative_to) {
                .start => {
                    var _offset = @intCast(usize, offset);
                    if (_offset >= self.buf.len) {
                        return error.SeekError;
                    } else {
                        self.cur = _offset;
                    }
                },
                .current => {
                    var pos = @intCast(i64, self.cur) + offset;
                    if (pos < 0 or pos >= self.buf.len) {
                        return error.SeekError;
                    } else {
                        self.cur = @intCast(usize, pos);
                    }
                },
                .end => {
                    var pos = @intCast(i64, self.buf.len) + offset - 1;
                    if (pos < 0 or pos >= self.buf.len) {
                        return error.SeekError;
                    } else {
                        self.cur = @intCast(usize, pos);
                    }
                },
            }
            return self.cur;
        }

        pub fn skip(self: *Self, amount: usize) !void {
            if (self.cur + amount >= self.buf.len) {
                return error.SkipError;
            }

            self.cur += amount;
        }

        pub usingnamespace if (isConstBuffer(BufferType(T)))
            struct {
                pub fn stream(self: *Self) io.Stream {
                    return io.Stream.init(self, .{
                        .read = Self.read,
                        .seek = Self.seek,
                        .peek = Self.peek,
                        .skip = Self.skip,
                    });
                }
            }
        else
            struct {
                pub fn stream(self: *Self) io.Stream {
                    return io.Stream.init(self, .{
                        .read = Self.read,
                        .write = Self.write,
                        .seek = Self.seek,
                        .peek = Self.peek,
                        .skip = Self.skip,
                    });
                }

                pub fn write(self: *Self, data: []const u8) !usize {
                    if (self.cur >= self.buf.len) {
                        return 0;
                    }

                    var amount = @min(self.buf.len - self.cur, data.len);
                    std.mem.copy(u8, self.buf[self.cur..], data);
                    @memcpy(self.buf[self.cur..].ptr, data.ptr, amount);
                    self.cur += amount;
                    return amount;
                }

                pub usingnamespace io.WriterMixin(*Self, io.StreamError);
            };

        pub fn stdReader(self: *Self) std.io.Reader(*Self, error{}, Self.read) {
            return .{ .context = self };
        }

        pub fn stdWriter(self: *Self) std.io.Writer(*Self, error{}, Self.write) {
            return .{ .context = self };
        }

        pub usingnamespace io.ReaderMixin(*Self, io.StreamError);
        pub usingnamespace io.PeekMixin(*Self, io.StreamError);
        pub usingnamespace io.SeekMixin(*Self, io.StreamError);
        pub usingnamespace io.SkipMixin(*Self, io.StreamError);
    };
}

fn NonSentinelSpan(comptime T: type) type {
    var ptr_info = @typeInfo(std.mem.Span(T)).Pointer;
    ptr_info.sentinel = null;
    return @Type(.{ .Pointer = ptr_info });
}

fn BufferType(comptime T: type) type {
    return switch (@typeInfo(T)) {
        .Array => T,
        .Pointer => NonSentinelSpan(T),
        else => @compileError("xxx"),
    };
}

fn isConstBuffer(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .Array => false,
        .Pointer => |p| p.is_const,
        else => @compileError("Invalid type!"),
    };
}

pub fn newBuffer(buffer: anytype) Buffer(BufferType(@TypeOf(buffer))) {
    return switch (@typeInfo(BufferType(@TypeOf(buffer)))) {
        .Array => .{ .buf = buffer },
        .Pointer => .{ .buf = std.mem.span(buffer) },
        else => @compileError("yyy"),
    };
}

test "BufferEx" {
    var b = Buffer([128]u8){};
    try b.writeAll("hello!");
    try b.seekToStart();
}
