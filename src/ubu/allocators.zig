const std = @import("std");
const Allocator = std.mem.Allocator;
const Error = std.mem.Allocator.Error;

pub const GlobalArena = struct {
    var arena: ?std.heap.ArenaAllocator = undefined;
    var arena_allocator: ?std.mem.Allocator = undefined;

    pub fn allocator() std.mem.Allocator {
        if (arena == null) {
            arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        }

        if (arena_allocator == null) {
            arena_allocator = arena.?.allocator();
        }

        return arena_allocator.?;
    }

    pub fn deinit() void {
        if (arena) |*a| {
            a.deinit();
        }
    }
};

pub const BufferArena = struct {
    buf: []u8,
    cur: usize = 0,

    pub fn init(buf: []u8) BufferArena {
        return .{ .buf = buf };
    }

    fn alloc(self: *BufferArena, len: usize, ptr_align: u29, len_align: u29, ret_addr: usize) Error![]u8 {
        _ = ret_addr;
        _ = len_align;

        if (self.cur >= self.buf.len) {
            return Error.OutOfMemory;
        } else {
            var current_ptr = &self.buf[self.cur];
            var alignment = @intCast(usize, ptr_align);

            if (@ptrToInt(current_ptr) % alignment == 0) {
                // already aligned...
                if (self.buf[self.cur..].len >= len) {
                    defer self.cur += len;
                    return self.buf[self.cur..(self.cur + len)];
                } else {
                    return Error.OutOfMemory;
                }
            } else {
                var align_len = alignment - (@ptrToInt(current_ptr) % alignment);
                var total_size = align_len + len;

                if (self.buf[self.cur..].len >= total_size) {
                    defer self.cur += total_size;
                    return self.buf[(self.cur + align_len)..(self.cur + total_size)];
                } else {
                    return Error.OutOfMemory;
                }
            }
        }
    }

    fn resize(self: *BufferArena, buf: []u8, buf_align: u29, new_len: usize, len_align: u29, ret_addr: usize) ?usize {
        _ = self;
        _ = buf;
        _ = buf_align;
        _ = new_len;
        _ = len_align;
        _ = ret_addr;

        return null;
    }

    fn free(self: *BufferArena, buf: []u8, buf_align: u29, ret_addr: usize) void {
        _ = self;
        _ = buf;
        _ = buf_align;
        _ = ret_addr;
    }

    pub fn allocator(self: *BufferArena) Allocator {
        return Allocator.init(self, alloc, resize, free);
    }
};

const expect = std.testing.expect;

test "BufferArena" {
    var buf: [1024 * 1024]u8 = [_]u8{0} ** (1024 * 1024);
    var arena = BufferArena.init(&buf);
    var allocator = arena.allocator();

    var x: *i32 = try allocator.create(i32);
    x.* = 2;
    try expect(x.* == 2);
    try expect(arena.cur == 4);

    const SomeStruct = struct {
        x: u8 = 0,
        y: u32 = 1,
        z: i16 = 2,
        w: u1 = 0,
    };

    var s: *SomeStruct = try allocator.create(SomeStruct);
    try expect(@ptrToInt(s) % @alignOf(SomeStruct) == 0);
}
