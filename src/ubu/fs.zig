const ubu = @import("../ubu.zig");
const std = @import("std");
const File = std.fs.File;

pub fn open_file(path: []const u8) !File {
    return std.fs.cwd().openFile(path, .{});
}

pub fn create_file(path: []const u8) !File {
    return std.fs.cwd().createFile(path, .{});
}

pub fn write_file(path: []const u8, data: []const u8) !void {
    var f = try create_file(path);
    try f.writeAll(data);
}

pub fn read_file(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    var f: File = try open_file(path);
    return f.readToEndAlloc(allocator, 1024 * 1024 * 1024);
}

pub fn open_file_buffered(path: []const u8) !ubu.io.BufferedStreamContainer(ubu.io.FileStream, 1024) {
    var f: File = try open_file(path);
    return ubu.io.new_buffered_stream_container_from_file(f, 1024);
}

test "fs" {}
