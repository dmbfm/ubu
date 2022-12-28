const std = @import("std");
const ubu = @import("ubu");
const stdout = std.io.getStdOut().writer();

pub fn main() !void {
    const allocator = ubu.allocators.GlobalArena.allocator();
    defer ubu.allocators.GlobalArena.deinit();

    var args = try std.process.argsAlloc(allocator);
    defer allocator.free(args);
    if (args.len < 2) {
        try stdout.print("Usage: example-cat [file]\n", .{});
        return;
    }

    var filename = args[1];

    var f = try ubu.File.open(filename);
    defer f.close();

    while (true) {
        try f.fill_buffer();
        if (f.filled_slice.len == 0) break;
        try stdout.writeAll(f.filled_slice);
    }
}
