const std = @import("std");

pub const string = @import("ubu/string.zig");
pub const allocators = @import("ubu/allocators.zig");
pub usingnamespace @import("ubu/pool.zig");
pub usingnamespace @import("ubu/range.zig");
pub usingnamespace @import("ubu/static_queue.zig");
pub usingnamespace @import("ubu/static_stack.zig");

test {
    _ = @import("ubu/pool.zig");
    _ = @import("ubu/string.zig");
    _ = @import("ubu/allocators.zig");
    _ = @import("ubu/static_queue.zig");
    _ = @import("ubu/static_stack.zig");
}
