const std = @import("std");

pub usingnamespace @import("io/reader.zig");
pub usingnamespace @import("io/peek_reader.zig");
pub usingnamespace @import("io/seek_reader.zig");
pub usingnamespace @import("io/buffered_reader.zig");
pub usingnamespace @import("io/buffer_reader.zig");

test {
    _ = @import("io/reader.zig");
    _ = @import("io/peek_reader.zig");
    _ = @import("io/seek_reader.zig");
    _ = @import("io/buffered_reader.zig");
}
