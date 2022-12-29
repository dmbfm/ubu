const std = @import("std");
// const image = @import("../image.zig");
const color = @import("color.zig");

pub const PixelFormat = enum {
    Rgb,
    Rgba,
    Gray,
    Other,
};

pub fn Image(comptime ColorType: type) type {
    return struct {
        data: []ColorType,
        width: usize,
        height: usize,
        allocator: ?std.mem.Allocator = null,
        pixel_format: PixelFormat = switch (ColorType) {
            color.Rgb => .Rgb,
            color.Rgba => .Rgba,
            u8 => .Gray,
            else => .Other,
        },

        const Error = error{DimensionMismatch};
        const Self = @This();

        pub fn init(data: []ColorType, width: usize, height: usize) !Self {
            if (data.len != width * height) {
                return Error.DimensionMismatch;
            }

            return Self{
                .data = data,
                .width = width,
                .height = height,
            };
        }

        pub fn init_alloc(allocator: std.mem.Allocator, width: usize, height: usize) !Self {
            return Self{
                .data = try allocator.alloc(ColorType, width * height),
                .width = width,
                .height = height,
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            if (self.allocator) |allocator| {
                allocator.free(self.data);
            }
        }

        pub fn get(self: Self, x: usize, y: usize) ?ColorType {
            if (x < 0 or x >= self.width or y < 0 or y >= self.height) {
                return null;
            }

            return self.data[y * self.width + x];
        }

        pub fn set(self: *Self, x: usize, y: usize, value: ColorType) void {
            if (x < 0 or x >= self.width or y < 0 or y >= self.height) {
                return;
            }

            self.data[y * self.width + x] = value;
        }

        pub fn bytes(self: Self) []u8 {
            return std.mem.sliceAsBytes(self.data);
        }
    };
}

pub const Rgb = Image(color.Rgb);
pub const Rgba = Image(color.Rgba);
pub const Gray = Image(u8);

pub const DecodeResult = union(enum) {
    rgb: Rgb,
    rgba: Rgba,
    gray: Gray,
};

const expect = std.testing.expect;

test "Rgb" {
    var data: [4]color.Rgb = [_]color.Rgb{.{ .r = 255, .g = 255, .b = 255 }} ** 4;
    var img = try Rgb.init(&data, 2, 2);
    var bytes = img.bytes();
    for (bytes) |*b| {
        b.* = 0;
    }
    for (img.data) |*c| {
        try expect(c.r == 0);
        try expect(c.g == 0);
        try expect(c.b == 0);
    }
}
