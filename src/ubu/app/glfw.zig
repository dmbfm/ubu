const c = @cImport({
    @cDefine("GLFW_INCLUDE_NONE", "");
    @cInclude("GLFW/glfw3.h");
});

pub fn Impl(comptime AppType: type) type {
    return struct {
        pub fn run(impl_desc: AppType.ImplDesc) AppType.Error!void {
            if (c.glfwInit() == 0) {
                @panic("failed to init");
            }

            c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, 3);
            c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, 0);

            var window = c.glfwCreateWindow(
                @intCast(c_int, impl_desc.app_desc.width),
                @intCast(c_int, impl_desc.app_desc.height),
                "Simple example",
                null,
                null,
            );
            if (window == null) {
                @panic("failed to create window");
            }

            c.glfwMakeContextCurrent(window);
            c.glfwSwapInterval(1);

            impl_desc.init_fn();

            while (c.glfwWindowShouldClose(window) == 0) {
                impl_desc.frame_fn();
                c.glfwSwapBuffers(window);
                c.glfwPollEvents();
            }

            c.glfwDestroyWindow(window);
            c.glfwTerminate();
        }
    };
}
