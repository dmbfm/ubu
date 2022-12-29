const std = @import("std");

pub fn Complex(comptime T: type) type {
    return struct {
        im: T,
        re: T,

        const Self = @This();

        pub fn init(re: T, im: T) Self {
            return .{ .re = re, .im = im };
        }

        pub fn add(lhs: Complex, rhs: Complex) Complex {
            return .{
                .re = lhs.re + rhs.re,
                .re = lhs.re + rhs.re,
            };
        }

        pub fn sub(lhs: Complex, rhs: Complex) Complex {
            return .{
                .re = lhs.re - rhs.re,
                .re = lhs.re - rhs.re,
            };
        }

        pub fn norm_sq(self: Self) T {
            return self.re * self.re + self.im * self.im;
        }

        pub fn norm(self: Self) T {
            return std.math.sqrt(self.norm_sq());
        }

        pub fn format(
            self: Self,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = fmt;
            try std.fmt.formatFloatDecimal(self.re, options, writer);
            try writer.writeAll(" + ");
            try std.fmt.formatFloatDecimal(self.im, options, writer);
            try writer.writeAll("i");
        }
    };
}

const t = std.testing;
const expect = t.expect;

test "Complex norm" {
    var z = Complex(f32).init(1, 3);
    try t.expectApproxEqAbs(@as(f32, 10.0), z.norm_sq(), 0.00001);
    try t.expectApproxEqAbs(std.math.sqrt(@as(f32, 10)), z.norm(), 0.00001);
}
