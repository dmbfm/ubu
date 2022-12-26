const std = @import("std");
const reader = @import("reader.zig");
const ReaderMixin = reader.ReaderMixin;

pub fn PeekReaderMixin(
    comptime Self: type,
    comptime ContextType: type,
    comptime ErrorType: type,
    comptime peek_fn: fn (context: ContextType, buffer: []u8) ErrorType!usize,
) type {
    return struct {
        pub fn peek(self: Self, buffer: []u8) ErrorType!usize {
            return peek_fn(self.context, buffer);
        }

        pub fn peek_byte(self: Self) ErrorType!?u8 {
            var b: [1]u8 = undefined;
            var len = try self.peek(&b);
            if (len == 1) {
                return b[0];
            } else return null;
        }
    };
}

pub fn PeekReader(
    comptime ContextType: type,
    comptime ErrorType: type,
    comptime read_fn: fn (context: ContextType, buffer: []u8) ErrorType!usize,
    comptime peek_fn: fn (context: ContextType, buffer: []u8) ErrorType!usize,
) type {
    return struct {
        context: ContextType,
        const Self = @This();
        pub usingnamespace ReaderMixin(Self, ContextType, ErrorType, read_fn);
        pub usingnamespace PeekReaderMixin(Self, ContextType, ErrorType, peek_fn);
    };
}

pub fn file_peek(file: std.fs.File, buffer: []u8) (std.fs.File.ReadError || std.fs.File.SeekError)!usize {
    var len = try file.read(buffer);
    try file.seekBy(-@intCast(i64, len));
    return len;
}

const FilePeekReader = PeekReader(
    std.fs.File,
    std.fs.File.ReadError || std.fs.File.SeekError,
    std.fs.File.read,
    file_peek,
);

pub fn file_peek_reader(f: std.fs.File) FilePeekReader {
    return .{ .context = f };
}

const t = std.testing;

test "Peek Reader" {
    var f = try std.fs.cwd().openFile("build.zig", .{});
    var pr = file_peek_reader(f);
    var b: [1]u8 = undefined;
    var len = try pr.peek(&b);
    try t.expect(b[0] == 'c');
    try t.expect(len == 1);
}
