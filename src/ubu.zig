const std = @import("std");

pub const string = @import("ubu/string.zig");
pub const allocators = @import("ubu/allocators.zig");
pub const constraint = @import("ubu/constraint.zig");
pub const image = @import("ubu/image.zig");
pub const fs = @import("ubu/fs.zig");
pub const io = @import("ubu/io.zig");
pub const complex = @import("ubu/complex.zig");

pub usingnamespace @import("ubu/indexed_pool.zig");
pub usingnamespace @import("ubu/range.zig");
pub usingnamespace @import("ubu/static_queue.zig");
pub usingnamespace @import("ubu/static_stack.zig");
pub usingnamespace @import("ubu/tuple.zig");
pub usingnamespace @import("ubu/print.zig");

test {
    std.testing.refAllDecls(@This());
}
