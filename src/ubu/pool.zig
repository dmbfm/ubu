const std = @import("std");

pub fn Pool(comptime T: type, comptime N: usize) type {
    const Error = error{
        AllocationError,
        IndexError,
    };

    return struct {
        pool: [N]?T = undefined,
        free_handles: [N]usize = blk: {
            comptime var result: [N]usize = undefined;
            comptime var i: usize = 0;
            inline while (i < N) : (i += 1) {
                result[i] = i + 1;
            }
            break :blk result;
        },
        num_free_handles: usize = N,

        const Self = @This();

        pub fn alloc(self: *Self) Error!usize {
            if (self.num_free_handles <= 0) {
                return error.AllocationError;
            } else {
                defer self.num_free_handles -= 1;
                var handle = self.free_handles[self.num_free_handles - 1];

                if (self.pool[handle - 1] != null) {
                    @panic("allocating used slot!");
                }

                self.pool[handle - 1] = undefined;

                return handle;
            }
        }

        pub fn free(self: *Self, handle: usize) void {
            if (self.pool[handle - 1] != null) {
                self.pool[handle - 1] = null;

                if (self.num_free_handles >= N) {
                    @panic("Inconsistend number of free handles!");
                }

                self.free_handles[self.num_free_handles] = handle;
                self.num_free_handles += 1;
            }
        }

        pub fn getPtr(self: *Self, handle: usize) !*T {
            if (self.pool[handle - 1]) |*obj| {
                return obj;
            }

            return Error.IndexError;
        }

        pub fn get(self: *Self, handle: usize) !T {
            if (self.pool[handle - 1]) |obj| {
                return obj;
            }

            return Error.IndexError;
        }

        pub fn set(self: *Self, handle: usize, val: T) void {
            if (self.pool[handle - 1]) |*obj| {
                obj.* = val;
            }
        }
    };
}

test "Pool" {
    var p = Pool(i32, 100){};
    var x = try p.alloc();
    var ptr = try p.getPtr(x);
    ptr.* = 12;

    var y = try p.get(x);

    try std.testing.expect(y == 12);
}
