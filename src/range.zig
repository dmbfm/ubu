/// A function that returns a comptime slice of `usize`, with values
/// ranging form 0 up to `limit - 1`. That is, the range [0, range).
///
/// Usage example:
///
///     for (srange(10)) |i| {
///         std.log.info("{}", .{ i });
///     }
///
pub fn srange(comptime limit: comptime_int) []const usize {
    comptime {
        var nums: [limit]usize = undefined;
        var i: usize = 0;
        inline while (i < limit) : (i += 1) {
            nums[i] = i;
        }

        return &nums;
    }
}

/// Returns a slice of a given len of a 0-sized arrays of `u0`s.j
///
/// Usage:
///     for (range(10)) |_, i| {
///         std.log.info("{}", .{i});
///     }
pub fn range(len: usize) []u0 {
    return @as([*]u0, undefined)[0..len];
}
