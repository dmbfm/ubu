///
/// mandelbrot.zig
///
/// Small application that renders a mandelbrot set. This is a port from the
/// mandelbrot example in the book "Programming Rust", by Blandy, Orendorff &
/// Tindall. It's pretty much the same program, but here we only output .ppm
/// files.
///
/// Usage: example-mandelbrot FILE SIZE UPPER_LEFT LOWER_LEFT
///
/// E.g.: example-mandelbrot out.ppm 4000x3000 -1.20,0.35 -1,0.20
///
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

pub fn parsePair(comptime T: type, string: []const u8, sep: u8) !Tuple(.{ T, T }) {
    var i: usize = 0;
    while (i < string.len) {
        if (string[i] == sep) {
            break;
        }
        i += 1;
    }

    if (i == string.len) {
        return error.PairParseError;
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
        else => @compileError("parsePair: invalid type."),
    }
}

test "parsePair" {
    try expectError(error.PairParseError, parsePair(u32, "", ','));
    try expectError(error.InvalidCharacter, parsePair(u32, "1,", ','));
    try expectEqual(@as(Tuple(.{ u32, u32 }), .{ 1, 1 }), try parsePair(u32, "1,1", ','));
    try expectEqual(@as(Tuple(.{ u32, u32 }), .{ 100, 200 }), try parsePair(u32, "100x200", 'x'));
    try expectEqual(@as(Tuple(.{ f64, f64 }), .{ 1.2, 3.234 }), try parsePair(f64, "1.2,3.234", ','));
}

pub fn getPointForPixel(
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

test "getPointForPixel" {
    try expectEqual(
        Complex(f64).init(-0.5, -0.75),
        getPointForPixel(.{ 25, 175 }, .{ 100, 200 }, Complex(f64).init(-1.0, 1.0), Complex(f64).init(1.0, -1.0)),
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
        renderRow(image, row, dim, upper_left, lower_right, limit);
    }
}

pub fn renderRow(
    image: []u8,
    row: usize,
    dim: Tuple(.{ usize, usize }),
    upper_left: Complex(f64),
    lower_right: Complex(f64),
    limit: usize,
) void {
    for (range(dim[0])) |_, col| {
        var point = getPointForPixel(.{ col, row }, dim, upper_left, lower_right);
        var i: usize = 0;
        var z = Complex(f64).init(0, 0);
        while (i < limit and z.normSquared() <= 4) {
            z = z.mul(z).add(point);
            i += 1;
        }

        image[row * dim[0] + col] = getColorForValue(i, limit);
    }
}

pub fn getColorForValue(value: usize, limit: usize) u8 {
    return 255 - @floatToInt(u8, 255.0 * @intToFloat(f64, value) / @intToFloat(f64, limit));
}

pub fn renderThreadFn(ctx: *ThreadContext) void {
    while (true) {
        ctx.mutex.lock();
        var row = ctx.current_row;
        ctx.current_row += 1;
        ctx.mutex.unlock();

        if (row >= ctx.dim[1]) {
            break;
        }

        renderRow(ctx.image, row, ctx.dim, ctx.upper_left, ctx.lower_right, ctx.limit);
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

pub fn renderThreaded(
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
            threads[i] = try std.Thread.spawn(.{}, renderThreadFn, .{&thread_context});
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
const max_iterations = 255;

pub fn printUsage() !void {
    return ubu.eprintln("Usage: example-mandelbrot FILE SIZE UPPER_LEFT LOWER_LEFT", .{});
}

pub fn fatal(msg: []const u8) noreturn {
    ubu.eprintln("{s}\n", .{msg}) catch {};
    printUsage() catch {};
    std.os.exit(1);
}

pub fn main() !void {
    var allocator = ubu.allocators.GlobalArena.allocator();
    defer ubu.allocators.GlobalArena.deinit();

    var args = try std.process.argsAlloc(allocator);
    defer allocator.free(args);

    if (args.len != 5) {
        try printUsage();
        return;
    }

    var filename = args[1];
    var dim = parsePair(usize, args[2], 'x') catch fatal("failed to parse image dimensions!");
    var upper_left_nums = parsePair(f64, args[3], ',') catch fatal("failed to parse upper left coords!");
    var lower_right_nums = parsePair(f64, args[4], ',') catch fatal("failed to parse lower right coords!");
    var upper_left = Complex(f64).init(upper_left_nums[0], upper_left_nums[1]);
    var lower_right = Complex(f64).init(lower_right_nums[0], lower_right_nums[1]);

    var image = ubu.image.Gray.initAlloc(allocator, dim[0], dim[1]) catch fatal("Ouf of memory!");
    defer image.deinit();

    var f = ubu.fs.File.create(filename) catch fatal("Failed to create output file!");
    defer f.close();

    if (single_thread) {
        render(image.bytes(), dim, upper_left, lower_right, max_iterations);
    } else {
        renderThreaded(12, image.bytes(), dim, upper_left, lower_right, max_iterations) catch fatal("Failed to render!");
    }

    ppm.encode(image, f.writer(), false) catch fatal("Failed to output image!");
}
