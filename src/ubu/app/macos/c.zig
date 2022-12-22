const ubu_bool_t = c_int;

pub extern fn ubuMacObjcRelease(ptr: *anyopaque) void;
pub extern fn ubuAppMacRun(desc: UbuMacAppDesc) void;
pub extern fn ubuAppMacShutdown() void;

pub const UbuMacErrorCode = enum(c_int) {
    UBU_MAC_OK = 0,
    UBU_MAC_ALLOC_WINDOW_ERROR = 1,
    UBU_MAC_ALLOC_WINDOW_DELEGATE_ERROR = 2,
};

pub const UbuMacAppDesc = extern struct {
    width: c_int,
    height: c_int,
    title: [*:0]const u8,
    centered: ubu_bool_t,
    init_fn: *const fn (error_code: c_int) void,
    frame_fn: *const fn () void,
};
