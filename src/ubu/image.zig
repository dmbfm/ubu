const std = @import("std");
pub const color = @import("image/color.zig");
// pub const ppm = @import("image/ppm.zig");
pub usingnamespace @import("image/image.zig");

test {
    std.testing.refAllDecls(@This());
}
