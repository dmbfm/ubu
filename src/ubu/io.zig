const std = @import("std");

pub usingnamespace @import("io/reader.zig");
pub usingnamespace @import("io/seek.zig");
pub usingnamespace @import("io/peek.zig");
pub usingnamespace @import("io/file_stream.zig");
pub usingnamespace @import("io/buffer_stream.zig");
pub usingnamespace @import("io/buffered_stream.zig");
pub usingnamespace @import("io/writer.zig");

test {
    _ = @import("io/reader.zig");
    _ = @import("io/seek.zig");
    _ = @import("io/peek.zig");
    _ = @import("io/buffer_stream.zig");
    _ = @import("io/buffered_stream.zig");
    _ = @import("io/file_stream.zig");
}
