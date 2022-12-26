const std = @import("std");
const image = @import("../image.zig");

const DecodeOptions = struct {
    force_rgb: bool = false,
};

const Error = error{
    InvalidHeader,
    DecodeError,
    StringBufferOverflow,
};

const DecoderState = enum {
    Idle,
    ParsingDimensions,
    ParsingData,
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
        var ch = try reader.readByte();

        switch (ch) {
            '#' => {
                while (true) {
                    var _ch = try reader.readByte();
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
                    var ch2 = try reader.readByte();
                    if (std.ascii.isDigit(ch2)) {
                        buf[c] = ch2;
                        c += 1;
                    } else {
                        break;
                    }
                }
                // var r = try reader.readUntilDelimiter(buf[1..], ' ');
                var num = try std.fmt.parseInt(usize, buf[0..c], 10);

                if (state == 0) {
                    header.width = num;
                    state = 1;
                } else if (state == 1) {
                    header.height = num;
                    state = 2;
                } else if (state == 2) {
                    header.max_color_value = num;
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

pub fn decode(reader: anytype) !image.DecodeResult {
    var header = try parse_header(reader);

    switch (header.magic[1]) {
        '3' => {},
        '6' => {},
        else => return Error.InvalidHeader,
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

        var s = std.io.fixedBufferStream(p3);
        var header = try parse_header(s.reader());
        try expect(std.mem.eql(u8, &header.magic, "P3"));
        try expect(header.width == 3);
        try expect(header.height == 2);
        try expect(header.max_color_value == 1);
    }

    {
        const p6 = [_]u8{ 80, 54, 10, 53, 32, 53, 10, 50, 53, 53, 10, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 14, 12, 12, 14, 12, 12, 14, 12, 12, 255, 255, 255, 255, 255, 255, 14, 12, 12, 14, 12, 12, 14, 12, 12, 255, 255, 255, 255, 255, 255, 14, 12, 12, 14, 12, 12, 14, 12, 12, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255 };
        var s = std.io.fixedBufferStream(&p6);
        var header = try parse_header(s.reader());
        try expect(std.mem.eql(u8, &header.magic, "P6"));
        try expect(header.width == 5);
        try expect(header.height == 5);
        try expect(header.max_color_value == 255);
    }
}
