const std = @import("std");
const io = @import("../io.zig");

pub const FileStream = struct {
    context: std.fs.File,

    const Self = @This();
    pub const Error = std.fs.File.ReadError || std.fs.File.SeekError || std.fs.File.GetSeekPosError || std.fs.File.WriteFileError;

    pub fn init(file: std.fs.File) FileStream {
        return .{ .context = file };
    }

    pub fn read(self: Self, buf: []u8) Error!usize {
        return self.context.read(buf);
    }

    pub fn peek(self: Self, buf: []u8) Error!usize {
        var len = try self.read(buf);
        _ = try self.seek(.Current, -@intCast(i64, len));
        return len;
    }

    pub fn seek(self: Self, relative_to: io.SeekRelativeTo, amount: i64) Error!usize {
        switch (relative_to) {
            .Start => {
                try self.context.seekTo(@intCast(u64, amount));
            },
            .Current => {
                try self.context.seekBy(amount);
            },
            .End => {
                try self.context.seekFromEnd(amount);
            },
        }

        return @intCast(usize, try self.context.getPos());
    }

    pub fn write(self: Self, data: []const u8) Error!usize {
        return self.context.write(data);
    }

    pub usingnamespace io.ReaderMixin(Self, Error);
    pub usingnamespace io.SeekMixin(Self, Error);
    pub usingnamespace io.PeekMixin(Self, Error);
    pub usingnamespace io.WriterMixin(Self, Error);
};

test "FileStream" {
    var f = try std.fs.cwd().openFile("test_data/file.txt", .{});
    var stream = FileStream.init(f);
    var b = (try stream.read_byte()).?;
    try std.testing.expect(b == 'I');
    b = (try stream.peek_byte()).?;
    try std.testing.expect(b == ' ');
    var buf: [4]u8 = undefined;
    var len = try stream.peek(&buf);
    try std.testing.expect(len == 4);
    try std.testing.expect(std.mem.eql(u8, &buf, " jus"));
    _ = try stream.seek(.End, -6);
    var buf2: [6]u8 = undefined;
    len = try stream.read(&buf2);
    try std.testing.expect(len == 6);
    try std.testing.expect(std.mem.eql(u8, &buf2, "still\n"));
}
