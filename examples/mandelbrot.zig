const std = @import("std");
const ubu = @import("ubu");
const ppm = ubu.image.ppm;
const range = ubu.range;
const expect = std.testing.expect;
const expectError = std.testing.expectError;
const expectEqual = std.testing.expectEqual;
const eql = std.mem.eql;
const Tuple = ubu.Tuple;
const Complex = ubu.complex.Complex;

const Point = Tuple(.{ f32, f32 });

pub fn parse_pair(comptime T: type, string: []const u8, sep: u8) !Tuple(.{ T, T }) {
    var i: usize = 0;
    while (i < string.len) {
        if (string[i] == sep) {
            break;
        }
        i += 1;
    }

    const type_info = @typeInfo(T);

    switch (type_info) {
        .Int => {
            return .{
                try std.fmt.parseInt(T, string[0..i], 0),
                try std.fmt.parseInt(T, string[(i + 1)..], 0),
            };
        },
        .Float => {
            return .{
                try std.fmt.parseFloat(T, string[0..i]),
                try std.fmt.parseFloat(T, string[(i + 1)..]),
            };
        },
        else => @compileError("parse_pair: invalid type."),
    }
}

test "parse_pair" {
    try expectError(error.InvalidCharacter, parse_pair(u32, "", ','));
    try expectError(error.InvalidCharacter, parse_pair(u32, "1,", ','));
    try expectEqual(@as(Tuple(.{ u32, u32 }), .{ 1, 1 }), try parse_pair(u32, "1,1", ','));
    try expectEqual(@as(Tuple(.{ u32, u32 }), .{ 100, 200 }), try parse_pair(u32, "100x200", 'x'));
    try expectEqual(@as(Tuple(.{ f64, f64 }), .{ 1.2, 3.234 }), try parse_pair(f64, "1.2,3.234", ','));
}

pub fn get_point_for_pixel(
    pixel: Tuple(.{ usize, usize }),
    dim: Tuple(.{ usize, usize }),
    upper_left: Complex(f64),
    lower_right: Complex(f64),
) Complex(f64) {
    const x: f64 = @intToFloat(f64, pixel[0]);
    const y: f64 = @intToFloat(f64, pixel[1]);
    const w: f64 = @intToFloat(f64, dim[0]);
    const h: f64 = @intToFloat(f64, dim[1]);
    return .{
        .re = (lower_right.re * x + upper_left.re * (w - x)) / w,
        .im = (lower_right.im * y + upper_left.im * (h - y)) / h,
    };
}

test "get_point_for_pixel" {
    try expectEqual(
        Complex(f64).init(-0.5, -0.75),
        get_point_for_pixel(.{ 25, 175 }, .{ 100, 200 }, Complex(f64).init(-1.0, 1.0), Complex(f64).init(1.0, -1.0)),
    );
}

pub fn render(
    image: []u8,
    dim: Tuple(.{ usize, usize }),
    upper_left: Complex(f64),
    lower_right: Complex(f64),
    limit: usize,
) void {
    for (range(dim[1])) |_, row| {
        render_row(image, row, dim, upper_left, lower_right, limit);
    }
}

pub fn render_row(
    image: []u8,
    row: usize,
    dim: Tuple(.{ usize, usize }),
    upper_left: Complex(f64),
    lower_right: Complex(f64),
    limit: usize,
) void {
    for (range(dim[0])) |_, col| {
        var point = get_point_for_pixel(.{ col, row }, dim, upper_left, lower_right);
        var i: usize = 0;
        var z = Complex(f64).init(0, 0);
        while (i < std.math.min(limit, 255) and z.norm_sq() <= 4) {
            z = z.mul(z).add(point);
            i += 1;
        }

        image[row * dim[0] + col] = @intCast(u8, 255 - i);
    }
}

pub fn render_thread_fn(ctx: *ThreadContext) void {
    while (true) {
        ctx.mutex.lock();
        var row = ctx.current_row;
        ctx.current_row += 1;
        ctx.mutex.unlock();

        if (row >= ctx.dim[1]) {
            break;
        }

        render_row(ctx.image, row, ctx.dim, ctx.upper_left, ctx.lower_right, ctx.limit);
    }
}

const ThreadContext = struct {
    image: []u8,
    dim: Tuple(.{ usize, usize }),
    upper_left: Complex(f64),
    lower_right: Complex(f64),
    limit: usize,
    current_row: usize,
    mutex: std.Thread.Mutex = .{},
};

pub fn render_threaded(
    comptime num_threads: comptime_int,
    image: []u8,
    dim: Tuple(.{ usize, usize }),
    upper_left: Complex(f64),
    lower_right: Complex(f64),
    limit: usize,
) !void {
    var threads: [num_threads]std.Thread = undefined;

    var thread_context = ThreadContext{
        .image = image,
        .dim = dim,
        .upper_left = upper_left,
        .lower_right = lower_right,
        .limit = limit,
        .current_row = 0,
    };

    {
        var i: usize = 0;
        while (i < num_threads) {
            threads[i] = try std.Thread.spawn(.{}, render_thread_fn, .{&thread_context});
            i += 1;
        }
    }

    {
        var i: usize = 0;
        while (i < num_threads) {
            threads[i].join();
            i += 1;
        }
    }
}

const single_thread = false;

pub fn main() !void {
    var allocator = ubu.allocators.GlobalArena.allocator();
    defer ubu.allocators.GlobalArena.deinit();

    var args = try std.process.argsAlloc(allocator);
    defer allocator.free(args);

    if (args.len != 5) {
        try ubu.eprintln("Usage: example-mandelbrot FILE SIZE UPPER_LEFT LOWER_LEFT", .{});
        return;
    }

    var filename = args[1];
    var dim = try parse_pair(usize, args[2], 'x');
    var upper_left_nums = try parse_pair(f64, args[3], ',');
    var lower_right_nums = try parse_pair(f64, args[4], ',');
    var upper_left = Complex(f64).init(upper_left_nums[0], upper_left_nums[1]);
    var lower_right = Complex(f64).init(lower_right_nums[0], lower_right_nums[1]);

    var image = try ubu.image.Gray.init_alloc(allocator, dim[0], dim[1]);
    defer image.deinit();

    var f = try ubu.File.create(filename);
    defer f.close();

    if (single_thread) {
        render(image.bytes(), dim, upper_left, lower_right, 255);
    } else {
        try render_threaded(12, image.bytes(), dim, upper_left, lower_right, 255);
    }

    try ppm.encode(image, &f, false);
}
