const std = @import("std");

const stdout = std.io.getStdOut().writer();
const stderr = std.io.getStdErr().writer();

pub fn print(comptime format: []const u8, args: anytype) !void {
    return stdout.print(format, args);
}

pub fn println(comptime format: []const u8, args: anytype) !void {
    try stdout.print(format, args);
    try stdout.writeByte('\n');
}

pub fn printString(data: []const u8) !void {
    return stdout.writeAll(data);
}

pub fn eprint(comptime format: []const u8, args: anytype) !void {
    return stderr.print(format, args);
}

pub fn eprintString(data: []const u8) !void {
    return stderr.writeAll(data);
}

/// Prints the formatted string to `stderr`.
pub fn eprintln(comptime format: []const u8, args: anytype) !void {
    try stderr.print(format, args);
    try stderr.writeByte('\n');
}
