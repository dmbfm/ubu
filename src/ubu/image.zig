const std = @import("std");
pub const color = @import("image/color.zig");
pub const ppm = @import("image/ppm.zig");
pub usingnamespace @import("image/image.zig");

test {
    _ = @import("image/color.zig");
    _ = @import("image/image.zig");
    _ = @import("image/ppm.zig");
}
