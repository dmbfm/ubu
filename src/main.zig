const std = @import("std");
const ubu = @import("ubu.zig");
const gl = @import("ubu/gfx/gl.zig");

const App = ubu.app.App(MyApp);

const glfw = @import("ubu/app/glfw.zig");

const MyApp = struct {
    counter: usize = 0,
    t: f64 = 0,

    pub const Error = error{
        MyAppError,
    };

    pub fn init(self: *MyApp) Error!void {
        _ = self;
        std.log.info("[MyApp]: init", .{});
    }

    pub fn frame(self: *MyApp) Error!void {
        var r: f64 = 0.5 + 0.5 * std.math.sin(self.t);
        gl.glClearColor(@floatCast(f32, r), 0.6, 0.4, 1);
        gl.glClear(gl.GL_COLOR_BUFFER_BIT);

        std.log.info("[MyApp]: frame = {}", .{self.counter});
        self.counter += 1;
        self.t += 0.025;
    }
};

pub fn main() !void {
    const str = "a£ह𐍈";

    var iter = ubu.string.SliceIterator.init(str);

    var i: usize = 0;
    while (try iter.nextSlice()) |slice| {
        std.log.info("{}: {s} (0x{X})", .{ i, slice, try ubu.string.codepoint(slice) });
        i += 1;
    }

    var my_app = MyApp{};
    try App.run(&my_app, .{
        .width = 800,
        .height = 600,
        .title = "App",
    });
}

test {
    _ = @import("ubu/main.zig");
}
