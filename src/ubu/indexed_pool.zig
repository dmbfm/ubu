const std = @import("std");

/// An object pool with generational-indices.
///
/// Usage example:
///
///   var pool = IndexedPool(u32, 128){};
///   var handle = try pool.alloc();
///   var ptr = try pool.get(handle);
///   ptr.* = 10;
///   // ... do stuff
///   pool.free(handle);
///
///
pub fn IndexedPool(comptime T: type, comptime capacity: usize) type {
    return struct {
        pool: [capacity]T = undefined,
        gen: [capacity]usize = [_]usize{0} ** capacity,
        free_handles: [capacity]usize = blk: {
            comptime var result: [capacity]usize = undefined;
            comptime var i: usize = 0;
            @setEvalBranchQuota(capacity);
            inline while (i < capacity) : (i += 1) {
                result[i] = i + 1;
            }
            break :blk result;
        },
        num_free_handles: usize = capacity,

        pub const Handle = struct {
            id: usize,
            gen: usize,
        };

        const Self = @This();

        pub const Error = error{ PoolFull, GenerationMismatch };

        pub fn alloc(self: *Self) Error!Handle {
            if (self.num_free_handles == 0) {
                return Error.PoolFull;
            }

            self.num_free_handles -= 1;
            var id = self.free_handles[self.num_free_handles];
            var gen = self.gen[id - 1];

            return .{ .id = id, .gen = gen };
        }

        pub fn free(self: *Self, handle: Handle) void {
            if (self.num_free_handles < capacity) {
                defer self.num_free_handles += 1;
                self.free_handles[self.num_free_handles] = handle.id;
                self.gen[handle.id - 1] += 1;
            }
        }

        pub fn get(self: *Self, handle: Handle) !*T {
            var gen = self.gen[handle.id - 1];

            if (gen != handle.gen) {
                return Error.GenerationMismatch;
            }

            return &self.pool[handle.id - 1];
        }
    };
}

test {
    var p = IndexedPool(i32, 100){};
    var xhandle = try p.alloc();
    var x = try p.get(xhandle);
    x.* = 12;
    try std.testing.expect((try p.get(xhandle)).* == 12);

    p.free(xhandle);

    var failed = false;
    _ = p.get(xhandle) catch {
        failed = true;
    };

    try std.testing.expect(failed);
}

test {
    var p = IndexedPool(i32, 2){};
    var hx = try p.alloc();
    _ = try p.alloc();

    var failed = false;
    _ = p.alloc() catch {
        failed = true;
    };

    try std.testing.expect(failed);

    p.free(hx);
    _ = try p.alloc();
}
