const std = @import("std");
const io = @import("../io.zig");

pub fn Buffer(comptime BufferType: type) type {
    return struct {
        context: Context,

        pub const Context = struct {
            buf: BufferType,
            cur: usize = 0,
        };

        const Self = @This();

        pub fn init(buffer: BufferType) Self {
            return .{ .context = .{ .buf = buffer } };
        }

        pub fn stream(self: *Self) BufferStream(BufferType) {
            return .{ .ctx = &self.context };
        }
    };
}

pub fn BufferStream(comptime BufferType: type) type {
    return struct {
        ctx: *Buffer(BufferType).Context,

        const Self = @This();
        pub const Error = error{ NoError, SeekError, WriteError };

        pub fn read(self: Self, out: []u8) Error!usize {
            if (self.ctx.cur >= self.ctx.buf.len) {
                return 0;
            }

            var avail = self.ctx.buf.len - self.ctx.cur;
            var amount = std.math.min(avail, out.len);

            if (amount == 0) {
                return 0;
            }

            @memcpy(out.ptr, self.ctx.buf[self.ctx.cur..].ptr, amount);
            self.ctx.cur += amount;
            return amount;
        }

        pub fn peek(self: Self, out: []u8) Error!usize {
            var len = try self.read(out);

            if (len == 0) {
                return 0;
            }
            _ = try self.seek(.Current, -@intCast(i64, len));
            return len;
        }

        pub fn seek(self: Self, relative_to: io.SeekRelativeTo, amount: i64) Error!usize {
            if (amount == 0) {
                return self.ctx.cur;
            }

            switch (relative_to) {
                .Start => {
                    if (amount < 0 or amount >= self.ctx.buf.len) {
                        return Error.SeekError;
                    }

                    self.ctx.cur = @intCast(usize, amount);
                },
                .Current => {
                    var new = @intCast(i64, self.ctx.cur) + amount;
                    if (new < 0 or new >= self.ctx.buf.len) {
                        return Error.SeekError;
                    }
                    self.ctx.cur = @intCast(usize, new);
                },
                .End => {
                    var new = @intCast(i64, self.ctx.buf.len) + amount;
                    if (new < 0 or new >= self.ctx.buf.len) {
                        return Error.SeekError;
                    }
                    self.ctx.cur = @intCast(usize, new);
                },
            }

            return self.ctx.cur;
        }

        pub fn write(self: Self, data: []const u8) Error!usize {
            var ctx = self.ctx;
            var avail = ctx.buf.len - ctx.cur;
            var amount = std.math.min(avail, data.len);
            @memcpy(ctx.buf[ctx.cur..].ptr, data.ptr, amount);
            ctx.cur += amount;
            return amount;
        }

        pub usingnamespace io.ReaderMixin(Self, Error);
        pub usingnamespace io.SeekMixin(Self, Error);
        pub usingnamespace io.PeekMixin(Self, Error);
        pub usingnamespace io.WriterMixin(Self, Error);
    };
}

pub fn new_buffer(buf: anytype) Buffer(non_sentinel_span(@TypeOf(buf))) {
    return .{ .context = .{ .buf = std.mem.span(buf) } };
}

pub fn non_sentinel_span(comptime T: type) type {
    var ptr_info = @typeInfo(std.mem.Span(T)).Pointer;
    ptr_info.sentinel = null;
    return @Type(.{ .Pointer = ptr_info });
}

test "Buffer Stream" {
    var data: []const u8 = "aaaa bb ccccc dd e fff gggggg hhh";
    var buf = new_buffer(data);
    var s = buf.stream();
    var b = (try s.read_byte()).?;
    try std.testing.expect(b == 'a');
}

test "Buffer print" {
    var data: [3]u8 = undefined;
    var buf = new_buffer(&data);
    var s = buf.stream();
    try s.print("{}", .{255});
    try std.testing.expect(std.mem.eql(u8, &data, "255"));
}
