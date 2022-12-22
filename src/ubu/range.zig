/// A function that returns a comptime slice of `usize`, with values
/// ranging form 0 up to `limit - 1`. That is, the range [0, range).
///
/// Usage example:
///
///     for (range(10)) |i| {
///         std.log.info("{}", .{ i });
///     }
///
pub fn range(comptime limit: comptime_int) []const usize {
    comptime {
        var nums: [limit]usize = undefined;
        var i: usize = 0;
        inline while (i < limit) : (i += 1) {
            nums[i] = i;
        }

        return &nums;
    }
}
