const std = @import("std");

pub usingnamespace @import("fs/file.zig");

pub fn openFile(path: []const u8) !std.fs.File {
    return std.fs.cwd().openFile(path, .{});
}

pub fn createFile(path: []const u8) !std.fs.File {
    return std.fs.cwd().createFile(path, .{});
}

test {
    std.testing.refAllDecls(@This());
}
