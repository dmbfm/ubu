const std = @import("std");
const ubu = @import("ubu");
const stdout = std.io.getStdOut().writer();
const image = ubu.image;
const color = ubu.image.color;

pub fn main() !void {
    var allocator = std.heap.page_allocator;
    var args = try std.process.argsAlloc(allocator);
    defer allocator.free(args);

    if (args.len < 2) {
        try stdout.print("Usage: image_invert [filename]\n", .{});
        return;
    }

    var filename: []const u8 = args[1];
    var buffered = try ubu.fs.openFileBuffered(filename);
    defer buffered.close();

    var result = try image.ppm.decode(allocator, buffered.stream());
    var img = result.rgb;
    defer img.deinit();

    for (img.bytes()) |*value| {
        value.* = 255 - value.*;
    }

    var out_file = try ubu.fs.createFile("out.ppm");
    defer out_file.close();
    try image.ppm.encode(img, ubu.io.newFileStream(out_file), false);
}
