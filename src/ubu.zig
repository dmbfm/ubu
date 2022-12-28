const std = @import("std");

pub const string = @import("ubu/string.zig");
pub const allocators = @import("ubu/allocators.zig");
pub usingnamespace @import("ubu/indexed_pool.zig");
pub usingnamespace @import("ubu/range.zig");
pub usingnamespace @import("ubu/static_queue.zig");
pub usingnamespace @import("ubu/static_stack.zig");
pub const constraint = @import("ubu/constraint.zig");
pub const image = @import("ubu/image.zig");
pub const io = @import("ubu/io.zig");
pub const fs = @import("ubu/fs.zig");

test {
    _ = @import("ubu/indexed_pool.zig");
    _ = @import("ubu/string.zig");
    _ = @import("ubu/allocators.zig");
    _ = @import("ubu/static_queue.zig");
    _ = @import("ubu/static_stack.zig");
    _ = @import("ubu/image.zig");
    _ = @import("ubu/io.zig");
}
