const std = @import("std");
const image = @import("../image.zig");
const io = @import("../io.zig");
const range = @import("../range.zig").range;
const ubu = @import("../../ubu.zig");

pub const DecodeOptions = struct {
    scale_to_max_value: bool = true,
};

const Error = error{
    InvalidHeader,
    DecodeError,
    StringBufferOverflow,
};

const Header = struct {
    magic: [2]u8 = undefined,
    width: usize = 0,
    height: usize = 0,
    max_color_value: usize = 0,

    pub fn colorValue(self: Header, val: u8) u8 {
        if (self.max_color_value == 255) {
            return val;
        } else {
            return @floatToInt(u8, 255.0 * @intToFloat(f64, val) / @intToFloat(f64, self.max_color_value));
        }
    }
};

pub fn decodeFilePath(allocator: std.mem.Allocator, path: []const u8, options: DecodeOptions) !image.DecodeResult {
    var f = try std.fs.cwd().openFile(path, .{});
    defer f.close();
    return decodeFile(allocator, f, options);
}

pub fn decodeFile(allocator: std.mem.Allocator, file: std.fs.File, options: DecodeOptions) !image.DecodeResult {
    var buffer = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
    return decodeBuffer(allocator, buffer, options);
}

pub fn decodeBuffer(allocator: std.mem.Allocator, data: []const u8, options: DecodeOptions) !image.DecodeResult {
    // _ = options;
    var byteReader = io.ByteReader.init(data);
    var header = try decodeHeader(&byteReader);
    switch (header.magic[1]) {
        '1' => {
            @panic("Not implemented");
        },
        '2' => {
            return decodeBodyPlainText(image.Gray, allocator, header, &byteReader, options);
        },
        '3' => {
            return decodeBodyPlainText(image.Rgb, allocator, header, &byteReader, options);
        },
        '4' => {
            @panic("Not implemented");
        },
        '5' => {
            return decodeBodyBinary(image.Gray, allocator, header, &byteReader, options);
        },
        '6' => {
            return decodeBodyBinary(image.Rgb, allocator, header, &byteReader, options);
        },
        else => unreachable,
    }
}

fn decodeBodyBinary(
    comptime T: type,
    allocator: std.mem.Allocator,
    header: Header,
    br: *io.ByteReader,
    options: DecodeOptions,
) !image.DecodeResult {
    var img = switch (T) {
        image.Gray => try image.Gray.initAlloc(allocator, header.width, header.height),
        image.Rgb => try image.Rgb.initAlloc(allocator, header.width, header.height),
        else => @compileError("Invalid type!"),
    };

    var ch = try br.readByte();
    if (ch != '\n') {
        return error.DecodeError;
    }

    var bytes = img.bytes();
    var src = br.buf[br.cur..];

    if (header.max_color_value != 255 and options.scale_to_max_value) {
        for (bytes) |*b| {
            b.* = header.colorValue(b.*);
        }
    }

    if (bytes.len != src.len) {
        return error.DecodeError;
    }

    @memcpy(bytes.ptr, src.ptr, src.len);

    return switch (T) {
        image.Gray => image.DecodeResult{ .gray = img },
        image.Rgb => image.DecodeResult{ .rgb = img },
        else => @compileError("Invalid type!"),
    };
}

fn decodeBodyPlainText(
    comptime T: type,
    allocator: std.mem.Allocator,
    header: Header,
    br: *io.ByteReader,
    options: DecodeOptions,
) !image.DecodeResult {
    var img = switch (T) {
        image.Gray => try image.Gray.initAlloc(allocator, header.width, header.height),
        image.Rgb => try image.Rgb.initAlloc(allocator, header.width, header.height),
        else => @compileError("Invalid type!"),
    };

    var bytes = img.bytes();
    var count: usize = 0;

    while (true) {
        var ch = br.peekByte() catch |err| switch (err) {
            error.EndOfStream => break,
            else => return err,
        };

        switch (ch) {
            '#' => {
                try br.skipLine();
            },
            '\n' => {
                try br.skipByte();
            },
            ' ' => {
                try br.skipByte();
            },
            '0'...'9' => {
                var buf: [16]u8 = undefined;
                var len = try br.readWhileDigit(&buf);
                var num = try std.fmt.parseInt(u8, buf[0..len], 10);
                if (count >= bytes.len) {
                    return error.DecodeError;
                }

                bytes[count] = if (options.scale_to_max_value) header.colorValue(num) else num;
                count += 1;
            },
            else => {
                return error.DecodeError;
            },
        }
    }

    return switch (T) {
        image.Gray => image.DecodeResult{ .gray = img },
        image.Rgb => image.DecodeResult{ .rgb = img },
        else => @compileError("Invalid type!"),
    };
}

fn decodeHeaderBuffer(data: []const u8) !Header {
    var byteReader = io.ByteReader.init(data);
    return try decodeHeader(&byteReader);
}

fn decodeHeader(br: *io.ByteReader) !Header {
    var header = Header{};

    _ = try br.read(&header.magic);

    if (header.magic[0] != 'P') {
        return error.InvalidHeader;
    }

    if (std.mem.indexOf(u8, "123456", header.magic[1..]) == null) {
        return error.InvalidHeader;
    }

    var state: u8 = 0;

    while (true) {
        var ch = try br.peekByte();

        switch (ch) {
            '#' => {
                _ = try br.skipUntilAfterChar('\n');
            },
            ' ', '\n' => {
                try br.skipByte();
            },
            '0'...'9' => {
                var buf: [16]u8 = undefined;
                var len = try br.readWhileDigit(&buf);
                var num = try std.fmt.parseInt(usize, buf[0..len], 10);

                switch (state) {
                    0 => {
                        header.width = num;
                        state = 1;
                    },
                    1 => {
                        header.height = num;
                        state = 2;
                    },
                    2 => {
                        header.max_color_value = num;
                        state = 3;
                        break;
                    },
                    else => unreachable,
                }
            },
            else => return error.InvalidHeader,
        }
    }

    if (state != 3) {
        return error.InvalidHeader;
    }

    return header;
}

fn writeHeader(header: Header, writer: anytype) !void {
    _ = try writer.write(&header.magic);
    try writer.writeByte('\n');
    try writer.print("{} {}\n", .{ header.width, header.height });
    try writer.print("{}\n", .{header.max_color_value});
}

pub fn encodeToFile(img: anytype, file: std.fs.File, plain_text: bool) !void {
    var bw = std.io.bufferedWriter(file.writer());
    try encode(img, bw.writer(), plain_text);
    try bw.flush();
}

pub fn encodeToFilePath(img: anytype, path: []const u8, plain_text: bool) !void {
    var file = try std.fs.cwd().createFile(path, .{});
    defer file.close();
    return encodeToFile(img, file, plain_text);
}

pub fn encodeToBuffer(img: anytype, buffer: []u8, plain_text: bool) !void {
    var bw = io.ByteWriter.init(buffer);
    return encode(img, bw.writer(), plain_text);
}

pub fn encodeToBufferAlloc(img: anytype, allocator: std.mem.Allocator, plain_text: bool) ![]u8 {
    _ = plain_text;
    _ = allocator;
    _ = img;
}

pub fn encode(img: anytype, writer: anytype, plain_text: bool) !void {
    switch (@TypeOf(img)) {
        image.Rgb => {
            var header = Header{
                .magic = if (plain_text) [_]u8{ 'P', '3' } else [_]u8{ 'P', '6' },
                .width = img.width,
                .height = img.height,
                .max_color_value = 255,
            };
            try writeHeader(header, writer);

            if (plain_text) {
                for (range(img.height)) |_, y| {
                    for (range(img.width)) |_, x| {
                        var color = img.get(x, y).?;
                        try writer.print("{} {} {} ", .{ color.r, color.g, color.b });
                    }
                    try writer.writeAll("\n");
                }
            } else {
                try writer.writeAll(img.bytes());
            }
        },
        image.Gray => {
            var header = Header{
                .magic = if (plain_text) [_]u8{ 'P', '2' } else [_]u8{ 'P', '5' },
                .width = img.width,
                .height = img.height,
                .max_color_value = 255,
            };

            try writeHeader(header, writer);

            if (plain_text) {
                for (range(img.height)) |_, y| {
                    for (range(img.width)) |_, x| {
                        var color = img.get(x, y).?;
                        try writer.print("{} ", .{color});
                    }
                    try writer.writeAll("\n");
                }
            } else {
                try writer.writeAll(img.bytes());
            }
        },
        image.Rgba => {},
        else => return error.UnsupportedPixelFormat,
    }
}

const expect = std.testing.expect;

test "parse_header" {
    {
        const p3 =
            \\P3
            \\# The same image with width 3 and height 2,
            \\# using 0 or 1 per color (red, green, blue)
            \\3 2 1
            \\1 0 0   0 1 0   0 0 1
            \\1 1 0   1 1 1   0 0 0
        ;

        var header = try decodeHeaderBuffer(p3);
        try expect(std.mem.eql(u8, &header.magic, "P3"));
        try expect(header.width == 3);
        try expect(header.height == 2);
        try expect(header.max_color_value == 1);
    }

    {
        const p6 = [_]u8{ 80, 54, 10, 53, 32, 53, 10, 50, 53, 53, 10, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 14, 12, 12, 14, 12, 12, 14, 12, 12, 255, 255, 255, 255, 255, 255, 14, 12, 12, 14, 12, 12, 14, 12, 12, 255, 255, 255, 255, 255, 255, 14, 12, 12, 14, 12, 12, 14, 12, 12, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255 };
        var header = try decodeHeaderBuffer(&p6);
        try expect(std.mem.eql(u8, &header.magic, "P6"));
        try expect(header.width == 5);
        try expect(header.height == 5);
        try expect(header.max_color_value == 255);
    }
}

test "decode p3" {
    const p3 =
        \\P3
        \\# The same image with width 3 and height 2,
        \\# using 0 or 1 per color (red, green, blue)
        \\3 2 1
        \\1 0 0   0 1 0   0 0 1
        \\1 1 0   1 1 1   0 0 0
    ;

    {
        var result = try decodeBuffer(std.testing.allocator, p3, .{});
        defer result.rgb.deinit();

        try expect(result.rgb.get(0, 0).?.r == 255);
        try expect(result.rgb.get(0, 0).?.g == 0);
        try expect(result.rgb.get(0, 0).?.b == 0);

        try expect(result.rgb.get(1, 0).?.r == 0);
        try expect(result.rgb.get(1, 0).?.g == 255);
        try expect(result.rgb.get(1, 0).?.b == 0);

        try expect(result.rgb.get(1, 1).?.r == 255);
        try expect(result.rgb.get(1, 1).?.g == 255);
        try expect(result.rgb.get(1, 1).?.b == 255);
    }
    {
        var result = try decodeBuffer(std.testing.allocator, p3, .{ .scale_to_max_value = false });
        defer result.rgb.deinit();

        try expect(result.rgb.get(0, 0).?.r == 1);
        try expect(result.rgb.get(0, 0).?.g == 0);
        try expect(result.rgb.get(0, 0).?.b == 0);

        try expect(result.rgb.get(1, 0).?.r == 0);
        try expect(result.rgb.get(1, 0).?.g == 1);
        try expect(result.rgb.get(1, 0).?.b == 0);

        try expect(result.rgb.get(1, 1).?.r == 1);
        try expect(result.rgb.get(1, 1).?.g == 1);
        try expect(result.rgb.get(1, 1).?.b == 1);
    }
}

test "decode p6" {
    const p6 = [_]u8{ 80, 54, 10, 53, 32, 53, 10, 50, 53, 53, 10, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 14, 12, 12, 14, 12, 12, 14, 12, 12, 255, 255, 255, 255, 255, 255, 14, 12, 12, 14, 12, 12, 14, 12, 12, 255, 255, 255, 255, 255, 255, 14, 12, 12, 14, 12, 12, 14, 12, 12, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255 };
    var result = try decodeBuffer(std.testing.allocator, &p6, .{});
    defer result.rgb.deinit();
    var img = result.rgb;

    try expect(img.get(0, 0).?.r == 255);
    try expect(img.get(0, 0).?.g == 255);
    try expect(img.get(0, 0).?.b == 255);

    try expect(img.get(1, 1).?.r == 14);
    try expect(img.get(1, 1).?.g == 12);
    try expect(img.get(1, 1).?.b == 12);

    try expect(img.get(4, 4).?.r == 255);
    try expect(img.get(4, 4).?.g == 255);
    try expect(img.get(4, 4).?.b == 255);
}

test "encode p3" {
    var pixels: [4]image.color.Rgb = [_]image.color.Rgb{
        .{ .r = 255, .g = 0, .b = 0 },
        .{ .r = 0, .g = 255, .b = 0 },
        .{ .r = 0, .g = 0, .b = 255 },
        .{ .r = 255, .g = 255, .b = 255 },
    };

    var expected_result: []const u8 =
        \\P3
        \\2 2
        \\255
        \\255 0 0 0 255 0 
        \\0 0 255 255 255 255 
        \\
    ;

    var buffer = io.StaticByteWriter(256){};
    var img = try image.Rgb.init(&pixels, 2, 2);
    try encode(img, buffer.writer(), true);
    try std.testing.expect(std.mem.eql(u8, buffer.buf[0..buffer.cur], expected_result));
}

test "encode p6" {}
