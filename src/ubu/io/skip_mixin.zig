const std = @import("std");

pub fn SkipMixin(comptime T: type, comptime E: type) type {
    return struct {
        pub fn skipByte(self: T) E!void {
            return self.skip(1);
        }
    };
}
