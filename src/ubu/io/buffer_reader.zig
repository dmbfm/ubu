const std = @import("std");
const io = @import("../io.zig");

const Context = struct {
    buffer: []const u8 = undefined,
    cur: usize = 0,

    pub const Error = error{ NoError, SeekOutOfRange };

    pub fn read(ctx: *Context, buf: []u8) Error!usize {
        var avail = ctx.buffer.len - ctx.cur;
        var amount = std.math.min(avail, buf.len);

        if (amount == 0) {
            return 0;
        }

        @memcpy(buf.ptr, ctx.buffer[ctx.cur..].ptr, amount);
        ctx.cur += amount;

        return amount;
    }

    fn seekFromStart(ctx: *Context, amount: i64) Error!usize {
        if (amount >= ctx.buffer.len or amount < 0) {
            return error.SeekOutOfRange;
        }

        ctx.cur = @intCast(usize, amount);
        return ctx.cur;
    }

    pub fn seek(ctx: *Context, relative_to: io.SeekRelativeTo, amount: i64) Error!usize {
        switch (relative_to) {
            .Start => {
                return ctx.seekFromStart(amount);
            },
            .Current => {
                var pos: i64 = @intCast(i64, ctx.cur) + amount;
                return ctx.seekFromStart(pos);
            },
            .End => {
                var pos: i64 = @intCast(i64, ctx.buffer.len) - amount - 1;
                return ctx.seekFromStart(pos);
            },
        }
    }

    pub fn peek(ctx: *Context, buf: []u8) Error!usize {
        var old = ctx.cur;
        var len = try ctx.read(buf);
        ctx.cur = old;
        return len;
    }
};

pub const BufferStream = struct {
    ctx: Context,

    pub fn init(buffer: []const u8) BufferStream {
        return .{ .ctx = .{ .buffer = buffer } };
    }

    pub fn seek_reader(self: *BufferStream) io.SeekReader(*Context, Context.Error, Context.read, Context.peek, Context.seek) {
        return .{ .context = &self.ctx };
    }

    pub fn peek_reader(self: *BufferStream) io.PeekReader(*Context, Context.Error, Context.read, Context.peek) {
        return .{ .context = &self.ctx };
    }

    pub fn reader(self: *BufferStream) io.Reader(*Context, Context.Error, Context.read) {
        return .{ .context = &self.ctx };
    }
};

const t = std.testing;

test "BufferStream" {
    var buffer: []const u8 = "aaaaa bb cc dd 2222 uu kk";
    var br = BufferStream.init(buffer);
    var sr = br.seek_reader();
    var ch = try sr.read_byte();
    try t.expect(ch == 'a');
    var x = try sr.seek(.End, 0);
    try t.expect(x == 24);
    ch = try sr.read_byte();
    try t.expect(ch == 'k');
    x = try sr.seek(.Start, 0);
    try t.expect(x == 0);
    var b: [25]u8 = undefined;
    x = try sr.read(&b);
    try t.expect(x == 25);
    try t.expect(std.mem.eql(u8, &b, buffer));
}
