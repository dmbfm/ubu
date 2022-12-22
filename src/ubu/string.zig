const std = @import("std");

pub const Error = error{
    DecodingError,
};

/// Returns the size for the utf8 character given the value of its first byte.
pub fn codepointByteSize(first_byte: u8) usize {
    if ((first_byte & 0b1000_0000) == 0) {
        return 1;
    } else if (((first_byte >> 5) ^ 0b0000_0110) == 0) {
        return 2;
    } else if (((first_byte >> 4) ^ 0b0000_1110) == 0) {
        return 3;
    } else if (((first_byte >> 3) ^ 0b0001_1110) == 0) {
        return 4;
    }

    unreachable;
}

/// Given a string/slice, returns the codepoint value for the first character
/// it encounters.
pub fn codepoint(slice: []const u8) Error!u32 {
    if (slice.len == 0) {
        return Error.DecodingError;
    }

    var byte_size = codepointByteSize(slice[0]);

    switch (byte_size) {
        1 => return @intCast(u32, slice[0]),
        2 => {
            if (byte_size < 2) {
                return Error.DecodingError;
            } else {
                var first_byte = slice[0];
                var second_byte = slice[1];
                var result: u32 = 0;

                if ((second_byte >> 6) ^ 0b10 == 0) {
                    result = second_byte & 0b0011_1111;
                    result |= (@intCast(u32, first_byte & 0b0001_1111) << 6);
                    return result;
                } else {
                    return Error.DecodingError;
                }
            }
        },
        3 => {
            if (byte_size < 3) {
                return Error.DecodingError;
            } else {
                var first_byte = slice[0];
                var second_byte = slice[1];
                var third_byte = slice[2];

                if (((second_byte >> 6) ^ 0b10 != 0) or ((third_byte >> 6) ^ 0b10 != 0)) {
                    return Error.DecodingError;
                } else {
                    var result: u32 = 0;

                    result = third_byte & 0b0011_1111;
                    result |= (@intCast(u32, second_byte & 0b0011_1111) << 6);
                    result |= (@intCast(u32, first_byte & 0b0000_1111) << 12);

                    return result;
                }
            }
        },
        4 => {
            if (byte_size < 4) {
                return Error.DecodingError;
            } else {
                var first_byte = slice[0];
                var second_byte = slice[1];
                var third_byte = slice[2];
                var fourth_byte = slice[3];

                if (((second_byte >> 6) ^ 0b10 != 0) or ((third_byte >> 6) ^ 0b10 != 0) or ((fourth_byte >> 6) ^ 0b10 != 0)) {
                    return Error.DecodingError;
                } else {
                    var result: u32 = 0;

                    result = fourth_byte & 0b0011_1111;
                    result |= (@intCast(u32, third_byte & 0b0011_1111) << 6);
                    result |= (@intCast(u32, second_byte & 0b0011_1111) << 12);
                    result |= (@intCast(u32, first_byte & 0b0000_1111) << 18);

                    return result;
                }
            }
        },
        else => unreachable,
    }
}

/// Iterates through unicode charaters in the input string. Each call to `nextSlice` will
/// return a slice of the original string containing the next character.
pub const SliceIterator = struct {
    string: []const u8,
    cur: usize = 0,
    pub fn init(str: []const u8) SliceIterator {
        return .{ .string = str };
    }

    pub fn nextSlice(self: *SliceIterator) !?[]const u8 {
        if (self.cur >= self.string.len) {
            return null;
        } else {
            var byte_size = codepointByteSize(self.string[self.cur]);

            if (self.cur + byte_size > self.string.len) {
                return Error.DecodingError;
            } else {
                defer self.cur += byte_size;
                return self.string[self.cur..(self.cur + byte_size)];
            }
        }
    }
};

const testing = std.testing;
const expect = testing.expect;

test "codepointByteSize" {
    const str = "a£ह𐍈";

    try expect(codepointByteSize(str[0]) == 1);
    try expect(codepointByteSize(str[1]) == 2);
    try expect(codepointByteSize(str[3]) == 3);
    try expect(codepointByteSize(str[6]) == 4);
}

test "codepoint" {
    const str = "a£ह𐍈";

    try expect(try codepoint(str[0..]) == 0x61);
    try expect(try codepoint(str[1..]) == 0xA3);
    try expect(try codepoint(str[3..]) == 0x939);
    try expect(try codepoint(str[6..]) == 0x10348);
}

test "SliceIterator" {
    const str = "a£ह𐍈";

    var iter = SliceIterator.init(str);

    try expect(std.mem.eql(u8, (try iter.nextSlice()).?, "a"));
    try expect(std.mem.eql(u8, (try iter.nextSlice()).?, "£"));
    try expect(std.mem.eql(u8, (try iter.nextSlice()).?, "ह"));
    try expect(std.mem.eql(u8, (try iter.nextSlice()).?, "𐍈"));
    try expect(try iter.nextSlice() == null);
}
