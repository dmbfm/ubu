const std = @import("std");

pub fn ReaderMixin(
    comptime T: type,
    comptime ContextType: type,
    comptime ErrorType: type,
    comptime read_fn: fn (context: ContextType, buffer: []u8) ErrorType!usize,
) type {
    return struct {
        pub const Error = ErrorType || error{EndOfStream};

        const Self = T;

        pub fn read(self: Self, buffer: []u8) ErrorType!usize {
            return read_fn(self.context, buffer);
        }

        pub fn read_byte(self: Self) Error!u8 {
            var b: [1]u8 = undefined;
            var len = try self.read(&b);
            if (len == 0) {
                return error.EndOfStream;
            }
            return b[0];
        }

        pub fn read_until_after(self: Self, delimiter: u8) Error!void {
            while (true) {
                var ch = try self.read_byte();
                if (ch == delimiter) {
                    break;
                }
            }
        }

        pub fn read_until_after_one_of(self: Self, delimiters: []const u8) Error!void {
            while (true) outer: {
                var ch = try self.read_byte();
                for (delimiters) |del| {
                    if (ch == del) {
                        break :outer;
                    }
                }
            }
        }

        pub fn skip(self: Self, num_bytes: usize) Error!void {
            var buffer: [512]u8 = undefined;
            var remaining = num_bytes;
            while (remaining > 0) {
                var max = std.math.min(remaining, buffer.len);
                var len = try self.read(buffer[0..max]);
                remaining -= len;
            }
        }

        pub fn skip_byte(self: Self) Error!void {
            return self.skip(1);
        }
    };
}

pub fn Reader(
    comptime ContextType: type,
    comptime ErrorType: type,
    comptime read_fn: fn (context: ContextType, buffer: []u8) ErrorType!usize,
) type {
    return struct {
        context: ContextType,
        pub usingnamespace ReaderMixin(@This(), ContextType, ErrorType, read_fn);
    };
}

pub const FileReader = Reader(std.fs.File, std.fs.File.ReadError, std.fs.File.read);

pub fn file_reader(file: std.fs.File) FileReader {
    return .{ .context = file };
}

const expect = std.testing.expect;

test "Simple Infinte Reader" {
    const Context = struct {
        pub const Error = error{NoError};
        const Self = @This();
        pub fn read(_: Self, buf: []u8) Error!usize {
            for (buf) |*b| {
                b.* = 255;
            }
            return buf.len;
        }
    };

    var r = Reader(Context, Context.Error, Context.read){ .context = .{} };
    var b: [4]u8 = undefined;

    try expect(try r.read_byte() == 255);
    var len = try r.read(&b);
    try expect(std.mem.eql(u8, b[0..len], &[_]u8{ 255, 255, 255, 255 }));
}

test "Simple Fixed Length Reader" {
    const Context = struct {
        count: usize = 0,
        pub const Error = error{NoError};
        const Self = @This();
        pub fn read(self: *Self, buf: []u8) Error!usize {
            var len: usize = 0;
            for (buf) |*b| {
                if (self.count >= 10) {
                    break;
                }
                b.* = 255;
                self.count += 1;
                len += 1;
            }
            return len;
        }
    };

    var ctx = Context{};
    const CtxReader = Reader(*Context, Context.Error, Context.read);
    var r = CtxReader{ .context = &ctx };
    var b: [10]u8 = undefined;
    var len = try r.read(&b);
    try expect(std.mem.eql(u8, b[0..len], &[_]u8{255} ** 10));
    try std.testing.expectError(CtxReader.Error.EndOfStream, r.read_byte());
    len = try r.read(&b);
    try expect(len == 0);
}

test "File Reader" {
    var f = try std.fs.cwd().openFile("build.zig", .{});
    var r = file_reader(f);
    try expect(try r.read_byte() == 'c');
}
