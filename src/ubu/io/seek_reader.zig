const std = @import("std");
const ReaderMixin = @import("reader.zig").ReaderMixin;
const peek = @import("peek_reader.zig");
const PeekReaderMixin = peek.PeekReaderMixin;

pub const SeekRelativeTo = enum {
    Start,
    Current,
    End,
};

pub fn SeekReaderMixin(
    comptime Self: type,
    comptime ContextType: type,
    comptime ErrorType: type,
    comptime seek_fn: fn (context: ContextType, relative_to: SeekRelativeTo, offet: i64) ErrorType!usize,
) type {
    return struct {
        pub fn seek(self: Self, relative_to: SeekRelativeTo, offset: i64) ErrorType!usize {
            return seek_fn(self.context, relative_to, offset);
        }
    };
}

pub fn SeekReader(
    comptime ContextType: type,
    comptime ErrorType: type,
    comptime read_fn: fn (context: ContextType, buffer: []u8) ErrorType!usize,
    comptime peek_fn: fn (context: ContextType, buffer: []u8) ErrorType!usize,
    comptime seek_fn: fn (context: ContextType, relative_to: SeekRelativeTo, offset: i64) ErrorType!usize,
) type {
    return struct {
        context: ContextType,
        const Self = @This();
        pub usingnamespace ReaderMixin(Self, ContextType, ErrorType, read_fn);
        pub usingnamespace PeekReaderMixin(Self, ContextType, ErrorType, peek_fn);
        pub usingnamespace SeekReaderMixin(Self, ContextType, ErrorType, seek_fn);
    };
}

pub fn file_seek(f: std.fs.File, relative_to: SeekRelativeTo, offset: i64) (std.fs.File.GetSeekPosError || std.fs.File.SeekError)!usize {
    switch (relative_to) {
        .Start => {
            try f.seekTo(@intCast(u64, offset));
        },
        .Current => {
            try f.seekBy(offset);
        },
        .End => {
            try f.seekFromEnd(offset);
        },
    }

    return @intCast(usize, try f.getPos());
}

pub const FileSeekReader = SeekReader(
    std.fs.File,
    std.fs.File.ReadError || std.fs.File.SeekError || std.fs.File.GetSeekPosError,
    std.fs.File.read,
    peek.file_peek,
    file_seek,
);

pub fn file_seek_reader(f: std.fs.File) FileSeekReader {
    return .{ .context = f };
}

const t = std.testing;

test "Seek Reader" {
    var f = try std.fs.cwd().openFile("build.zig", .{});
    var r = file_seek_reader(f);
    _ = try r.seek(.Start, 1);
    var ch = try r.read_byte();
    try t.expect(ch == 'o');
}
