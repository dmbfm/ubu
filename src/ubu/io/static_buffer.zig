const std = @import("std");
const io = @import("../io.zig");

pub fn StaticBuffer(comptime capacity: comptime_int) type {
    return io.Buffer([capacity]u8);
}

pub fn newStaticBuffer(comptime capacity: comptime_int) StaticBuffer(capacity) {
    return StaticBuffer(capacity){};
}

test "StaticBuffer" {
    var sb = StaticBuffer(10){};
    try sb.writeAll("Hello!");
    try sb.seekToStart();
    var b: [6]u8 = undefined;
    _ = try sb.read(&b);
    try std.testing.expect(std.mem.eql(u8, &b, "Hello!"));
}
