const ubu = @import("../ubu.zig");
const std = @import("std");
const File = std.fs.File;

pub fn openFile(path: []const u8) !File {
    return std.fs.cwd().openFile(path, .{});
}

pub fn createFile(path: []const u8) !File {
    return std.fs.cwd().createFile(path, .{});
}

pub fn writeFile(path: []const u8, data: []const u8) !void {
    var f = try createFile(path);
    defer f.close();

    try f.writeAll(data);
}

pub fn readFile(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    var f: File = try openFile(path);
    defer f.close();

    return f.readToEndAlloc(allocator, 1024 * 1024 * 1024);
}

test "fs" {}
