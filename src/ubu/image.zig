const std = @import("std");
const color = @import("color.zig");

const Rgb = struct {
    data: []color.Rgb,
    width: usize,
    height: usize,
    allocator: ?std.mem.Allocator,

    const Error = error{DimensionMismatch};

    pub fn init(data: []color.Rgb, width: usize, height: usize) !Rgb {
        if (data.len != width * height) {
            return Error.DimensionMismatch;
        }

        return .{
            .data = data,
            .width = width,
            .height = height,
        };
    }

    pub fn init_alloc(allocator: std.mem.Allocator, width: usize, height: usize) !Rgb {
        return Rgb{
            .data = try allocator.alloc(Rgb, width * height),
            .width = width,
            .height = height,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Rgb) void {
        if (self.allocator) |allocator| {
            allocator.free(self.data);
        }
    }

    pub fn get(self: *Rgb, x: usize, y: usize) ?Rgb {
        if (x < 0 or x >= self.width or y < 0 or y >= self.height) {
            return null;
        }

        return self.data[y * self.width + x];
    }

    pub fn set(self: *Rgb, x: usize, y: usize, value: Rgb) void {
        if (x < 0 or x >= self.width or y < 0 or y >= self.height) {
            return;
        }

        self.data[y * self.width + x] = value;
    }

    pub fn bytes(self: *Rgb) []u8 {
        return std.mem.sliceAsBytes(self.data);
    }
};
