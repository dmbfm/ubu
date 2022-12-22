pub const GLbitfield = u32;

pub const GL_DEPTH_BUFFER_BIT: u32 = 0x00000100;
pub const GL_STENCIL_BUFFER_BIT: u32 = 0x00000400;
pub const GL_COLOR_BUFFER_BIT: u32 = 0x00004000;

pub extern fn glClearColor(r: f32, g: f32, b: f32, a: f32) void;
pub extern fn glClear(mask: GLbitfield) void;
