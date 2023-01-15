const std = @import("std");

pub fn Complex(comptime T: type) type {
    return struct {
        im: T,
        re: T,

        const Self = @This();

        pub fn init(re: T, im: T) Self {
            return .{ .re = re, .im = im };
        }

        pub fn add(lhs: Self, rhs: Self) Self {
            return .{
                .re = lhs.re + rhs.re,
                .im = lhs.im + rhs.im,
            };
        }

        pub fn sub(lhs: Self, rhs: Self) Self {
            return .{
                .re = lhs.re - rhs.re,
                .im = lhs.im - rhs.im,
            };
        }

        pub fn mul(self: Self, other: Self) Self {
            return .{
                .re = self.re * other.re - self.im * other.im,
                .im = self.re * other.im + self.im * other.re,
            };
        }

        pub fn normSquared(self: Self) T {
            return self.re * self.re + self.im * self.im;
        }

        pub fn norm(self: Self) T {
            return std.math.sqrt(self.normSquared());
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

fn eps(comptime T: type) T {
    return @as(T, 0.00001);
}

test "Complex norm" {
    var z = Complex(f32).init(1, 3);
    try t.expectApproxEqAbs(@as(f32, 10.0), z.normSquared(), 0.00001);
    try t.expectApproxEqAbs(std.math.sqrt(@as(f32, 10)), z.norm(), 0.00001);
}

test "Complex mul" {
    var z1 = Complex(f64).init(3.0, 2.0);
    var z2 = Complex(f64).init(1.0, 7.0);
    var y = z1.mul(z2);

    try t.expectApproxEqAbs(@as(f64, -11), y.re, eps(f64));
    try t.expectApproxEqAbs(@as(f64, 23), y.im, eps(f64));
}

test "Complex add" {
    var z1 = Complex(f64).init(3.0, 2.0);
    var z2 = Complex(f64).init(1.0, 7.0);
    var y = z1.add(z2);

    try t.expectApproxEqAbs(@as(f64, 4), y.re, eps(f64));
    try t.expectApproxEqAbs(@as(f64, 9), y.im, eps(f64));
}

test "Complex sub" {
    var z1 = Complex(f64).init(3.0, 2.0);
    var z2 = Complex(f64).init(1.0, 7.0);
    var y = z1.sub(z2);

    try t.expectApproxEqAbs(@as(f64, 2), y.re, eps(f64));
    try t.expectApproxEqAbs(@as(f64, -5), y.im, eps(f64));
}
