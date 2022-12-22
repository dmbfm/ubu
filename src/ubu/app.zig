const std = @import("std");
const builtin = @import("builtin");

const use_glfw: bool = false;

pub const AppDesc = struct {
    width: usize,
    height: usize,
    title: []const u8,
};

pub const AppError = error{
    AppError,
};

pub fn DummyImpl(comptime AppType: type) type {
    return struct {
        pub fn run(impl_desc: AppType.ImplDesc) AppType.Error!void {
            _ = impl_desc;
        }
    };
}

pub fn App(comptime UserType: type) type {
    return struct {
        const UserError = if (@hasDecl(UserType, "Error")) UserType.Error else error{};
        const user_init_proto = fn (self: *UserType) UserError!void;
        const user_frame_proto = fn (self: *UserType) UserError!void;
        const user_shutdown_proto = fn (self: *UserType) UserError!void;

        pub const Error = error{
            AppError,
        } || UserError;

        pub const ImplDesc = struct {
            app_desc: AppDesc,
            init_fn: *const fn () void,
            frame_fn: *const fn () void,
        };

        const Self = @This();

        const Impl = blk: {
            if (use_glfw) {
                break :blk @import("app/glfw.zig").Impl(Self);
            }

            if (builtin.cpu.arch.isWasm()) {
                @compileError("WASM application backend not implmented!");
            }

            break :blk switch (builtin.target.os.tag) {
                .macos => @import("app/macos.zig").Impl(Self),
                else => @compileError("Unsupported target!"),
            };
        };

        var user_instance: *UserType = undefined;

        fn init() void {
            user_instance.init() catch @panic("[init]: error");
        }

        fn frame() void {
            user_instance.frame() catch @panic("[frame]: error");
        }

        pub fn run(instance: *UserType, desc: AppDesc) Error!void {
            user_instance = instance;

            _ = user_init_proto;
            _ = user_frame_proto;
            _ = user_shutdown_proto;

            var impl_desc = ImplDesc{
                .app_desc = desc,
                .init_fn = init,
                .frame_fn = frame,
            };

            try Impl.run(impl_desc);
        }
    };
}
