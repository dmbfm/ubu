const std = @import("std");
const io = @import("../io.zig");

pub fn BufferedStreamContainer(comptime ReaderStream: type, comptime buffer_len: comptime_int) type {
    return struct {
        context: Context,

        pub const Context = struct {
            stream: ReaderStream,
            buffer: [buffer_len]u8 = undefined,
            scratch_buffer: [buffer_len]u8 = undefined,
            cur: usize = 0,
            len: usize = 0,
        };

        pub const Self = @This();

        pub fn init(s: ReaderStream) Self {
            return .{ .context = .{ .stream = s } };
        }

        pub fn init_from_file(f: std.fs.File) Self {
            return .{ .context = .{ .stream = io.FileStream.init(f) } };
        }

        pub fn stream(self: *Self) BufferedStream(ReaderStream, buffer_len) {
            return .{ .ctx = &self.context };
        }

        pub fn close(self: *Self) void {
            if (std.meta.trait.hasFn("close")(ReaderStream)) {
                const decl_type = @TypeOf(@field(ReaderStream, "close"));
                if (decl_type == fn (ReaderStream) void or decl_type == fn (*ReaderStream) void) {
                    self.context.stream.close();
                }
            }
        }
    };
}

pub fn BufferedStream(comptime ReaderStream: type, comptime buffer_len: comptime_int) type {
    return struct {
        ctx: *BufferedStreamContainer(ReaderStream, buffer_len).Context,

        const Self = @This();
        pub const Error = error{PeekError} || if (@hasDecl(ReaderStream, "Error")) ReaderStream.Error else error{};

        pub fn refill(self: Self) Error!void {
            var ctx = self.ctx;
            ctx.len = try ctx.stream.read(&ctx.buffer);
            ctx.cur = 0;
        }

        pub fn read(self: Self, buf: []u8) Error!usize {
            var ctx = self.ctx;
            var bytes_read: usize = 0;

            while (bytes_read < buf.len) {
                var avail = ctx.len - ctx.cur;
                if (avail == 0) {
                    try self.refill();
                    avail = ctx.len;
                }

                var amount = std.math.min(avail, buf.len - bytes_read);

                if (amount == 0) break;

                @memcpy(buf[bytes_read..].ptr, ctx.buffer[ctx.cur..].ptr, amount);
                ctx.cur += amount;
                bytes_read += amount;
            }

            return bytes_read;
        }

        pub fn peek(self: Self, buf: []u8) Error!usize {
            var ctx = self.ctx;

            if (ctx.len == ctx.cur) {
                try self.refill();
            }

            var bytes_ahead = ctx.len - ctx.cur;

            if (buf.len <= bytes_ahead) {
                var amount = std.math.min(bytes_ahead, buf.len);
                @memcpy(buf.ptr, ctx.buffer[ctx.cur..].ptr, amount);
                return amount;
            } else {
                @memcpy(&ctx.scratch_buffer, ctx.buffer[ctx.cur..].ptr, bytes_ahead);
                ctx.cur = 0;
                ctx.len = bytes_ahead;
                ctx.len += try self.read(ctx.scratch_buffer[bytes_ahead..]);
                ctx.buffer = ctx.scratch_buffer;

                var amount = std.math.min(ctx.len, buf.len);
                @memcpy(buf.ptr, &ctx.buffer, amount);
                return amount;
            }
        }

        pub fn seek(self: Self, relative_to: io.SeekRelativeTo, amount: i64) Error!usize {
            var ctx = self.ctx;
            var offset = @intCast(i64, ctx.len - ctx.cur);
            var result = try ctx.stream.seek(relative_to, amount - offset);
            try self.refill();
            return result;
        }

        pub usingnamespace io.ReaderMixin(Self, Error);
        pub usingnamespace io.PeekMixin(Self, Error);
        pub usingnamespace io.SeekMixin(Self, Error);
    };
}

pub fn new_buffered_stream_container(stream: anytype, comptime buffer_len: comptime_int) BufferedStreamContainer(@TypeOf(stream), buffer_len) {
    return BufferedStreamContainer(@TypeOf(stream), buffer_len).init(stream);
}

pub fn new_buffered_stream_container_from_file(f: std.fs.File, comptime buffer_len: comptime_int) BufferedStreamContainer(io.FileStream, buffer_len) {
    return BufferedStreamContainer(io.FileStream, buffer_len).init_from_file(f);
}

test "Buffered Stream" {
    var f = try std.fs.cwd().openFile("test_data/file.txt", .{});
    // var s = io.FileStream.init(f);
    // var bsc = new_buffered_stream_container(s, 128);
    var bsc = new_buffered_stream_container_from_file(f, 128);
    var stream = bsc.stream();
    var ch = (try stream.read_byte()).?;
    try std.testing.expect(ch == 'I');
    ch = (try stream.peek_byte()).?;
    try std.testing.expect(ch == ' ');
    try stream.skip_byte();
    var b: [4]u8 = undefined;
    _ = try stream.read(&b);
    try std.testing.expect(std.mem.eql(u8, &b, "just"));
}
