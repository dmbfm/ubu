const std = @import("std");
const app = @import("../app.zig");
const c = @import("macos/c.zig");

pub fn Impl(comptime AppType: type) type {
    return struct {
        var desc: AppType.ImplDesc = undefined;

        fn init(error_code: c_int) void {
            if (error_code == 0) {
                desc.init_fn();
            } else {}
        }

        fn frame() void {
            desc.frame_fn();
        }

        pub fn run(impl_desc: AppType.ImplDesc) AppType.Error!void {
            desc = impl_desc;

            c.ubuAppMacRun(.{
                .width = @intCast(c_int, desc.app_desc.width),
                .height = @intCast(c_int, desc.app_desc.height),
                .centered = 1,
                .title = @ptrCast([*:0]const u8, desc.app_desc.title.ptr),
                .init_fn = init,
                .frame_fn = frame,
            });
        }
    };
}
