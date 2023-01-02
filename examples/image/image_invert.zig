const std = @import("std");
const ubu = @import("ubu");
const stdout = std.io.getStdOut().writer();
const image = ubu.image;
const color = ubu.image.color;
const File = ubu.io.File;

pub fn main() !void {
    var allocator = std.heap.page_allocator;
    var args = try std.process.argsAlloc(allocator);
    defer allocator.free(args);

    if (args.len < 2) {
        try stdout.print("Usage: image_invert [filename]\n", .{});
        return;
    }

    var filename: []const u8 = args[1];

    var result = try image.ppm.decodeFilePath(allocator, filename);
    var img = result.rgb;
    defer img.deinit();

    for (img.bytes()) |*value| {
        value.* = 255 - value.*;
    }

    try image.ppm.encodeToFilePath(img, "out.ppm", false);
}
