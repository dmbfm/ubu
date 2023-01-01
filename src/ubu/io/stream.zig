const std = @import("std");
const io = @import("../io.zig");

pub const StreamError = error{
    ReadError,
    WriteError,
    SeekError,
    PeekError,
    EndOfStream,
    SkipError,
    OutOfMemory,
};

pub const SeekRelativeTo = enum {
    start,
    current,
    end,
};

const VTable = struct {
    read: ?*const fn (*anyopaque, []u8) StreamError!usize = null,
    write: ?*const fn (*anyopaque, []const u8) StreamError!usize = null,
    peek: ?*const fn (*anyopaque, []u8) StreamError!usize = null,
    seek: ?*const fn (*anyopaque, relative_to: SeekRelativeTo, offset: i64) StreamError!usize = null,
    skip: ?*const fn (*anyopaque, usize) StreamError!void = null,
};

// pub fn Stream(comptime ErrorType: type) type {
pub const Stream = struct {
    ptr: *anyopaque,
    vtable: VTable,

    pub const Error = StreamError;

    pub fn VTableDesc(comptime T: type) type {
        return struct {
            read: ?*const fn (T, []u8) StreamError!usize = null,
            write: ?*const fn (T, []const u8) StreamError!usize = null,
            peek: ?*const fn (T, []u8) StreamError!usize = null,
            seek: ?*const fn (T, relative_to: SeekRelativeTo, offset: i64) StreamError!usize = null,
            skip: ?*const fn (T, amount: usize) StreamError!void = null,
        };
    }

    pub fn init(ptr: anytype, comptime vtable_desc: VTableDesc(@TypeOf(ptr))) Stream {
        const Ptr = @TypeOf(ptr);
        const alignment = @typeInfo(Ptr).Pointer.alignment;

        const Gen = struct {
            fn read(pointer: *anyopaque, out: []u8) StreamError!usize {
                const self = @ptrCast(Ptr, @alignCast(alignment, pointer));
                if (vtable_desc.read) |f| {
                    return f(self, out);
                }

                @panic("Reader not implemented for stream!");
            }

            fn write(pointer: *anyopaque, data: []const u8) StreamError!usize {
                const self = @ptrCast(Ptr, @alignCast(alignment, pointer));
                if (vtable_desc.write) |f| {
                    return f(self, data);
                }

                @panic("Writer not implemented for stream!");
            }

            fn peek(pointer: *anyopaque, out: []u8) StreamError!usize {
                const self = @ptrCast(Ptr, @alignCast(alignment, pointer));
                if (vtable_desc.peek) |f| {
                    return f(self, out);
                }

                @panic("Peek not implemented for stream!");
            }

            fn seek(pointer: *anyopaque, relative_to: SeekRelativeTo, offset: i64) StreamError!usize {
                const self = @ptrCast(Ptr, @alignCast(alignment, pointer));
                if (vtable_desc.seek) |f| {
                    return f(self, relative_to, offset);
                }

                @panic("Seek not implemented for stream!");
            }

            fn skip(pointer: *anyopaque, amount: usize) StreamError!void {
                const self = @ptrCast(Ptr, @alignCast(alignment, pointer));
                if (vtable_desc.skip) |f| {
                    return f(self, amount);
                }

                @panic("Skip not implemented for stream!");
            }
        };

        return .{
            .ptr = ptr,
            .vtable = .{
                .read = if (vtable_desc.read != null) Gen.read else null,
                .write = if (vtable_desc.write != null) Gen.write else null,
                .peek = if (vtable_desc.peek != null) Gen.peek else null,
                .seek = if (vtable_desc.seek != null) Gen.seek else null,
                .skip = if (vtable_desc.skip != null) Gen.skip else null,
            },
        };
    }

    pub fn read(self: Stream, out: []u8) StreamError!usize {
        if (self.vtable.read) |f| {
            return f(self.ptr, out);
        }

        @panic("Reader not implemented for stream!");
    }

    pub fn write(self: Stream, out: []const u8) StreamError!usize {
        if (self.vtable.write) |f| {
            return f(self.ptr, out);
        }

        @panic("Writer not implemented for stream!");
    }

    pub fn peek(self: Stream, out: []u8) StreamError!usize {
        if (self.vtable.peek) |f| {
            return f(self.ptr, out);
        }

        @panic("Peek not implemented for stream!");
    }

    pub fn seek(self: Stream, relative_to: SeekRelativeTo, offset: i64) StreamError!usize {
        if (self.vtable.seek) |f| {
            return f(self.ptr, relative_to, offset);
        }

        @panic("Seek not implemented for stream!");
    }

    pub fn skip(self: Stream, amount: usize) StreamError!void {
        if (self.vtable.skip) |f| {
            return f(self.ptr, amount);
        }

        @panic("Skip not implemented for stream!");
    }

    pub fn print(self: Stream, comptime fmt: []const u8, args: anytype) !void {
        try std.fmt.format(self, fmt, args);
    }

    pub usingnamespace io.ReaderMixin(Stream, StreamError);
    pub usingnamespace io.WriterMixin(Stream, StreamError);
    pub usingnamespace io.SeekMixin(Stream, StreamError);
    pub usingnamespace io.PeekMixin(Stream, StreamError);
    pub usingnamespace io.SkipMixin(Stream, StreamError);
};

test "Stream/read" {
    const B = struct {
        const data = "Daniel Fortes";
        cur: usize = 0,
        const Self = @This();
        pub fn read(self: *Self, out: []u8) !usize {
            if (self.cur >= data.len) {
                return 0;
            }
            var amount = @min(data.len - self.cur, out.len);
            @memcpy(out.ptr, data[self.cur..].ptr, amount);
            self.cur += amount;
            return amount;
        }

        pub fn stream(self: *Self) Stream {
            return Stream.init(self, .{ .read = Self.read });
        }
    };

    var b = B{};
    var s = b.stream();
    var buf: [13]u8 = undefined;
    _ = try s.read(&buf);
    try std.testing.expect(std.mem.eql(u8, buf[0..], "Daniel Fortes"));
}
