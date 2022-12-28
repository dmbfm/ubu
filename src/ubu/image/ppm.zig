const std = @import("std");
const image = @import("../image.zig");
const io = @import("../io.zig");
const range = @import("../range.zig").range;
const ubu = @import("../../ubu.zig");

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
};

pub fn parse_header(reader: anytype) !Header {
    var header = Header{};

    _ = try reader.read(&header.magic);

    var state: u8 = 0;

    while (true) {
        var ch = if (try reader.read_byte()) |val| val else break;

        std.log.info("ch = {}", .{ch});
        switch (ch) {
            '#' => {
                while (true) {
                    var _ch = (try reader.read_byte()).?;
                    if (_ch == '\n') {
                        break;
                    }
                }
            },
            ' ' => {},
            '\n' => {},
            '0'...'9' => {
                var buf: [64]u8 = undefined;
                var c: usize = 1;
                buf[0] = ch;
                while (true) {
                    var ch2 = (try reader.read_byte()).?;
                    if (std.ascii.isDigit(ch2)) {
                        buf[c] = ch2;
                        c += 1;
                    } else {
                        try reader.step_back();
                        break;
                    }
                }

                var num = try std.fmt.parseInt(usize, buf[0..c], 10);

                if (state == 0) {
                    header.width = num;
                    state = 1;
                } else if (state == 1) {
                    header.height = num;
                    state = 2;
                } else if (state == 2) {
                    header.max_color_value = num;
                    if (!std.math.isPowerOfTwo(header.max_color_value + 1)) {
                        return Error.InvalidHeader;
                    }
                    return header;
                } else {
                    return Error.InvalidHeader;
                }
            },
            else => {
                return Error.InvalidHeader;
            },
        }
    }

    return Error.InvalidHeader;
}

pub fn decode_p3(allocator: std.mem.Allocator, header: Header, peek_reader: anytype) !image.DecodeResult {
    var r = &peek_reader;
    var img = try image.Rgb.init_alloc(allocator, header.width, header.height);

    // TODO: change `read_byte` signature to match `peek_byte`'s signature (Error!?u8).
    var x: usize = 0;
    var y: usize = 0;
    var color: [3]u8 = [3]u8{ 0, 0, 0 };
    var idx: usize = 0;
    while (try r.peek_byte()) |ch| {
        switch (ch) {
            ' ', '\n' => {
                try r.skip_byte();
            },
            '0'...'9' => {
                var buf: [16]u8 = undefined;
                var cur: usize = 0;
                while (true) {
                    if (try r.read_byte()) |_ch| {
                        if (std.ascii.isDigit(_ch)) {
                            buf[cur] = _ch;
                            cur += 1;
                            continue;
                        }
                    }

                    break;
                }

                color[idx] = try std.fmt.parseInt(u8, buf[0..cur], 10);
                idx += 1;

                if (idx == 3) {
                    img.set(x, y, image.color.Rgb{ .r = color[0], .g = color[1], .b = color[2] });
                    idx = 0;
                    x += 1;
                }

                if (x >= img.width) {
                    x = 0;
                    y += 1;
                }
            },
            else => return error.DecodeError,
        }
    }

    return image.DecodeResult{ .rgb = img };
}

fn decode_p6(allocator: std.mem.Allocator, header: Header, reader: anytype) !image.DecodeResult {
    var img = try image.Rgb.init_alloc(allocator, header.width, header.height);
    var bytes = img.bytes();

    var sep = (try reader.read_byte()).?;
    switch (sep) {
        '\n', ' ' => {},
        else => return error.DecodeError,
    }

    _ = try reader.read(bytes);

    return .{ .rgb = img };
}

pub fn decode_buffer(allocator: std.mem.Allocator, data: []const u8) !image.DecodeResult {
    var r = ubu.io.new_buffer(data);
    return decode(allocator, r.stream());
}

pub fn decode(allocator: std.mem.Allocator, reader: anytype) !image.DecodeResult {
    var header = try parse_header(reader);

    switch (header.magic[1]) {
        '3' => return decode_p3(allocator, header, reader),
        '6' => return decode_p6(allocator, header, reader),
        else => return Error.InvalidHeader,
    }
}

pub fn write_header(header: Header, writer: anytype) !void {
    _ = try writer.write(&header.magic);
    try writer.write_byte('\n');
    try writer.print("{} {}\n", .{ header.width, header.height });
    try writer.print("{}\n", .{header.max_color_value});
}

pub fn encode(img: anytype, writer: anytype, plain_text: bool) !void {
    switch (img.pixel_format) {
        .Rgb => {
            var header = Header{
                .magic = if (plain_text) [_]u8{ 'P', '3' } else [_]u8{ 'P', '6' },
                .width = img.width,
                .height = img.height,
                .max_color_value = 255,
            };
            try write_header(header, writer);

            if (plain_text) {
                for (range(img.height)) |_, y| {
                    for (range(img.width)) |_, x| {
                        var color = img.get(x, y).?;
                        try writer.print("{} {} {} ", .{ color.r, color.g, color.b });
                    }
                    try writer.write_all("\n");
                }
            } else {
                try writer.write_all(img.bytes());
            }
        },
        .Gray => {},
        .Rgba => {},
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

        var buf = io.new_buffer(p3);
        var s = buf.stream();
        var header = try parse_header(&s);
        try expect(std.mem.eql(u8, &header.magic, "P3"));
        try expect(header.width == 3);
        try expect(header.height == 2);
        try expect(header.max_color_value == 1);
    }

    {
        const p6 = [_]u8{ 80, 54, 10, 53, 32, 53, 10, 50, 53, 53, 10, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 14, 12, 12, 14, 12, 12, 14, 12, 12, 255, 255, 255, 255, 255, 255, 14, 12, 12, 14, 12, 12, 14, 12, 12, 255, 255, 255, 255, 255, 255, 14, 12, 12, 14, 12, 12, 14, 12, 12, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255 };
        var buf = io.new_buffer(&p6);
        var s = buf.stream();
        var header = try parse_header(&s);
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

    var buffer = io.new_buffer(p3);
    var stream = buffer.stream();
    var result = try decode(std.testing.allocator_instance.allocator(), stream);
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

test "decode p6" {
    const p6 = [_]u8{ 80, 54, 10, 53, 32, 53, 10, 50, 53, 53, 10, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 14, 12, 12, 14, 12, 12, 14, 12, 12, 255, 255, 255, 255, 255, 255, 14, 12, 12, 14, 12, 12, 14, 12, 12, 255, 255, 255, 255, 255, 255, 14, 12, 12, 14, 12, 12, 14, 12, 12, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255 };
    var buf = io.new_buffer(&p6);
    var s = buf.stream();
    var result = try decode(std.testing.allocator_instance.allocator(), s);
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

    var expected_result =
        \\P3
        \\2 2
        \\255
        \\255 0 0 0 255 0 
        \\0 0 255 255 255 255 
        \\
    ;

    var buffer_data: [256]u8 = undefined;
    var buffer = io.new_buffer(&buffer_data);
    var s = buffer.stream();

    var img = try image.Rgb.init(&pixels, 2, 2);
    try encode(img, s, true);
    try std.testing.expect(std.mem.eql(u8, buffer_data[0..s.ctx.cur], expected_result));
}

test "encode p6" {}
