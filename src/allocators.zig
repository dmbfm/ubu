const std = @import("std");
const Allocator = std.mem.Allocator;
const Error = std.mem.Allocator.Error;

pub const GlobalArena = struct {
    var arena: ?std.heap.ArenaAllocator = undefined;
    var arena_allocator: ?std.mem.Allocator = undefined;

    pub fn allocator() std.mem.Allocator {
        if (arena == null) {
            arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        }

        if (arena_allocator == null) {
            arena_allocator = arena.?.allocator();
        }

        return arena_allocator.?;
    }

    pub fn deinit() void {
        if (arena) |*a| {
            a.deinit();
        }
    }
};
