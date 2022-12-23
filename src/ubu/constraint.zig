const std = @import("std");

pub fn Value(comptime T: type, comptime domain: []const T, comptime index_for_value_fn: *const fn (val: T) anyerror!usize) type {
    return struct {
        const Self = @This();
        value: [domain.len]bool = [_]bool{false} ** domain.len,

        pub fn init(values: []const T) !Self {
            var result = Self{};
            for (values) |value| {
                try result.set(value);
            }
            return result;
        }

        pub fn init_full() Self {
            var result = Self{};
            for (result.value) |*v| {
                v.* = true;
            }
            return result;
        }

        pub fn init_single_value(value: T) !Self {
            var result = Self{};
            try result.set(value);
            return result;
        }

        pub fn len(self: *Self) usize {
            var c: usize = 0;
            for (self.value) |v| {
                if (v) {
                    c += 1;
                }
            }

            return c;
        }

        pub fn set_single_value(self: *Self, value: T) !void {
            var idx = try index_for_value_fn(value);
            var i: usize = 0;
            while (i < domain.len) : (i += 1) {
                self.value[i] = i == idx;
            }
        }

        pub fn get_single_value_index(self: *Self) !usize {
            if (self.len() == 1) {
                var idx: usize = 0;
                for (self.value) |v| {
                    if (v) {
                        return idx;
                    }
                    idx += 1;
                }
            }

            return error.NotSingleValued;
        }

        pub fn get_single_value(self: *Self) !T {
            if (self.len() == 1) {
                var idx: usize = 0;
                for (self.value) |v| {
                    if (v) {
                        return domain[idx];
                    }
                    idx += 1;
                }
            }

            return error.NotSingleValued;
        }

        pub fn set(self: *Self, value: T) !void {
            var idx = try index_for_value_fn(value);
            self.value[idx] = true;
        }

        pub fn unset(self: *Self, value: T) void {
            var idx = index_for_value_fn(value) catch unreachable;

            if (self.value[idx]) {
                self.value[idx] = false;
            }
        }

        pub fn has_value(self: *Self, value: T) bool {
            var idx = index_for_value_fn(value) catch return false;
            return self.value[idx];
        }

        pub fn collapse_random(self: *Self, random: std.rand.Random) u8 {
            var val = random.intRangeLessThan(usize, 0, self.len());
            var i: usize = 0;
            var value: u8 = 0;
            for (self.value) |*v, k| {
                if (v.*) {
                    v.* = (i == val);
                    if (v.*) value = domain[k];
                    i += 1;
                }
            }

            return value;
        }

        pub fn print(self: *Self, w: anytype) !void {
            try w.print("[", .{});
            var idx: usize = 0;
            for (self.value) |v| {
                if (v) {
                    try w.print("{}", .{domain[idx]});
                } else {
                    try w.print("-", .{});
                }
                idx += 1;
            }
            try w.print("]", .{});
        }
    };
}
