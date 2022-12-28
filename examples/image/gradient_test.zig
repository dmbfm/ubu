const std = @import("std");
const ubu = @import("ubu");
const image = ubu.image;
const color = ubu.image.color;

const width = 1000;
const height = 1000;

pub fn main() !void {
    var data: [width * height]color.Rgb = undefined;
    var img = try ubu.image.Rgb.init(&data, width, height);
    for (ubu.range(height)) |_, y| {
        for (ubu.range(width)) |_, x| {
            var r: u8 = @floatToInt(u8, (@intToFloat(f64, x + y) / (@as(f64, width + height))) * 255);
            img.set(x, y, color.Rgb{ .r = r, .g = 0, .b = 0 });
        }
    }

    var f = try std.fs.cwd().createFile("gradient.ppm", .{});
    try image.ppm.encode(img, ubu.io.new_file_stream(f), false);
}
