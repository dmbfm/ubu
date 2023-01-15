const std = @import("std");

pub const Rgb = extern struct {
    r: u8,
    g: u8,
    b: u8,
};

pub const Rgba = extern struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,
};

comptime {
    if (@sizeOf(Rgb) != 3) {
        @compileError("Invalid size for Rgb struct!");
    }

    if (@sizeOf(Rgba) != 4) {
        @compileError("Invalid size for Rgba struct!");
    }
}
