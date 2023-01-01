//const Stream = struct {
//    ptr: *anyopaque,
//    readByteFn: ?*const fn (ptr: *anyopaque) u8,
//    writeByteFn: ?*const fn (ptr: *anyopaque, byte: u8) void,
//
//    pub fn init(
//        pointer: anytype,
//        comptime read_byte: ?fn (@TypeOf(pointer)) u8,
//        comptime write_byte: ?fn (@TypeOf(pointer), u8) void,
//    ) Stream {
//        const Ptr = @TypeOf(pointer);
//
//        const gen = struct {
//            fn readByte(ptr: *anyopaque) u8 {
//                if (read_byte == null) {
//                    @compileError("Read not implemented!");
//                }
//                const alignment = @alignOf(Ptr);
//                const self = @ptrCast(Ptr, @alignCast(alignment, ptr));
//                return read_byte(self);
//            }
//
//            fn writeByte(ptr: *anyopaque, byte: u8) void {
//                if (write_byte == null) {
//                    @compileError("Read not implemented!");
//                }
//                const alignment = @alignOf(Ptr);
//                const self = @ptrCast(Ptr, @alignCast(alignment, ptr));
//                write_byte(self, byte);
//            }
//        };
//
//        return .{
//            .ptr = pointer,
//            .readByteFn = if (read_byte != null) gen.readByte else null,
//            .writeByteFn = if (write_byte != null) gen.write_byte else null,
//        };
//    }
//};
//
//const MyReader = struct {
//    const data = "Daniel Sosd s sadjja sdf a sd fasdjfaks dfjaskdj x.";
//    cur: usize = 0,
//
//    pub fn read(self: *MyReader, out: []u8) !usize {
//        if (self.cur >= data.len) {
//            return 0;
//        }
//
//        var amount = std.math.min(data.len - self.cur, out.len);
//        // @memcpy(out.ptr, data[self.cur..].ptr, amount);
//        return amount;
//    }
//};
//
//const Consumer = struct {
//    reader: *anyopaque,
//    allocator: std.mem.Allocator,
//
//    pub fn init(allocator: std.mem.Allocator, reader: anytype) !Consumer {
//        var r = try allocator.create(@TypeOf(reader));
//        // r.* = reader;
//
//        return .{ .reader = r, .allocator = allocator };
//    }
//
//    pub fn deinit(self: *Consumer) void {
//        self.allocator.destroy(self.reader);
//    }
//};
//
//test "Reader/Consumer" {
//    var r = MyReader{};
//    var c = try Consumer.init(std.testing.allocator, r);
//    defer c.deinit();
//}

//
//fn ReadFn(comptime T: type, comptime Error: type) type {
//    return fn (self: T, out: []u8) Error!usize;
//}
//
//fn PeekFn(comptime T: type, comptime Error: type) type {
//    return fn (self: T, out: []u8) Error!usize;
//}
//
//fn WriteFn(comptime T: type, comptime Error: type) type {
//    return fn (self: T, data: []const u8) Error!usize;
//}
//
//fn SeekFn(comptime T: type, comptime Error: type) type {
//    return fn (self: T, amount: usize) Error!usize;
//}
//
//fn implementsReader(comptime T: type, comptime E: type) bool {
//    if (std.meta.trait.hasFn("read")(T)) {
//        const read_fn = @field(T, "read");
//        if (@TypeOf(read_fn) == ReadFn(T, E)) {
//            return true;
//        }
//    }
//
//    return false;
//}
//
//test "implementsReader" {
//    const S = struct {
//        const Error = error{};
//        const Self = @This();
//        pub fn read(self: Self, out: []u8) Error!usize {
//            _ = out;
//            _ = self;
//            return 0;
//        }
//    };
//    try std.testing.expect(implementsReader(S, error{}));
//}
//
//fn implementsFn(comptime T: type, comptime fn_name: []const u8, comptime FnType: type) bool {
//    if (std.meta.trait.hasFn(fn_name)(T)) {
//        const f = @field(T, fn_name);
//        if (@TypeOf(f) == FnType) {
//            return true;
//        }
//    }
//
//    return false;
//}
//
//test "implementsFn" {
//    const S = struct {
//        pub const Error = error{};
//        const Self = @This();
//        pub fn read(self: Self, out: []u8) Error!usize {
//            _ = out;
//            _ = self;
//            return 0;
//        }
//    };
//    try std.testing.expect(implementsFn(S, "read", ReadFn(S, S.Error)));
//
//    const S2 = struct {
//        pub fn f(reader: anytype) void {
//            const ReaderType = @TypeOf(reader);
//            if (!(comptime implementsFn(ReaderType, "read", ReadFn(ReaderType, ReaderType.Error)))) {
//                @compileError("Interface 'Reader' not implemented!");
//            }
//        }
//    };
//
//    const S3 = struct {
//        reader: *anyopaque,
//
//        const Self = @This();
//        pub fn init(allocator: std.mem.Allocator, reader: anytype) Self {
//            // _ = allocator;
//
//            var r = try allocator.create(@TypeOf(reader));
//            r.* = reader;
//            // reader = &r;
//
//            const ptrInfo = @typeInfo(@TypeOf(reader)).Pointer;
//            const ReaderType = ptrInfo.child;
//            if (!(comptime implementsFn(ReaderType, "read", ReadFn(ReaderType, ReaderType.Error)))) {
//                @compileError("Interface 'Reader' not implemented!");
//            }
//
//            return .{ .reader = reader };
//        }
//    };
//    var s = S{};
//    _ = S3.init(&s);
//
//    S2.f(S{});
//    // _ = S2;
//}
//
//const Interface = struct {};
//
//const SomeType = struct {
//    // f: Interface({})
//};
//
//const StreamInterface = enum {
//    Reader,
//    Writer,
//    Seek,
//    Peek,
//};
//
//fn Stream(
//    comptime T: type,
//    comptime Error: type,
//    comptime kind: u4,
//) type {
//    return struct {
//        vtable: VTable,
//        ctx: T,
//
//        pub const VTable = struct {
//            read: ?*const ReadFn(T, Error) = null,
//            write: ?*const WriteFn(T, Error) = null,
//            peek: ?*const PeekFn(T, Error) = null,
//            seek: ?*const SeekFn(T, Error) = null,
//        };
//
//        const Self = @This();
//        pub fn init(ctx: T, comptime vtable: VTable) Self {
//            comptime {
//                if (Self.has(Reader) and vtable.read == null) {
//                    @compileError("Reader not implemented!");
//                } else if (Self.has(Writer) and vtable.write == null) {
//                    @compileError("Writer not implemented!");
//                } else if (Self.has(Peek) and vtable.peek == null) {
//                    @compileError("Peek not implemented!");
//                } else if (Self.has(Seek) and vtable.seek == null) {
//                    @compileError("Seek not implemented!");
//                }
//            }
//
//            return .{
//                .vtable = vtable,
//                .ctx = ctx,
//            };
//        }
//
//        pub fn read(self: Self, out: []u8) Error!usize {
//            if (self.vtable.read) |read_fn| {
//                return read_fn(self.ctx, out);
//            }
//
//            unreachable;
//        }
//
//        pub fn peek(self: Self, out: []u8) Error!usize {
//            if (self.vtable.peek) |f| {
//                return f(self.ctx, out);
//            }
//
//            unreachable;
//        }
//
//        pub fn has(comptime interface: u4) bool {
//            if (!(comptime std.math.isPowerOfTwo(interface))) {
//                @compileError("Invalid interface");
//            }
//
//            return interface & kind != 0;
//        }
//    };
//}
//
//const buffer_len = 1024;
//const Buffer = struct {
//    buffer: [buffer_len]u8 = undefined,
//    cur: usize = 0,
//
//    pub const Error = error{NoError};
//
//    pub fn read(self: *Buffer, out: []u8) Error!usize {
//        if (self.cur >= buffer_len) {
//            return 0;
//        }
//        out[0] = self.buffer[self.cur];
//        self.cur += 1;
//        return 1;
//    }
//
//    pub fn peek(self: *Buffer, out: []u8) Error!usize {
//        if (self.cur >= buffer_len) {
//            return 0;
//        }
//        out[0] = self.buffer[self.cur];
//        return 1;
//    }
//
//    pub fn stream(self: *Buffer, comptime kind: u4) Stream(*Buffer, Error, kind) {
//        const StreamType = Stream(*Buffer, Error, kind);
//        comptime {
//            if (StreamType.has(Writer) or StreamType.has(Seek)) {
//                @compileError("Writer and Seek not implemented for buffer!");
//            }
//        }
//        const vtable = comptime StreamType.VTable{
//            .read = if (StreamType.has(Reader)) Buffer.read else null,
//            .peek = if (StreamType.has(Peek)) Buffer.peek else null,
//        };
//
//        return StreamType.init(self, vtable);
//    }
//};
//
//fn State(comptime T: type, comptime E: type) type {
//    return struct {
//        stream: Stream(T, E, Reader | Peek),
//
//        const Self = @This();
//
//        pub fn init(stream: Stream(T, E, Reader | Peek)) Self {
//            return .{ .stream = stream };
//        }
//    };
//}
//
//pub fn main() !void {}
//
//const Reader: u4 = 1;
//const Writer: u4 = 1 << 1;
//const Peek: u4 = 1 << 2;
//const Seek: u4 = 1 << 3;
//
//test {
//    const S = Stream(u8, error{}, Reader);
//    try std.testing.expect(S.has(Reader));
//    try std.testing.expect(!S.has(Writer));
//
//    const S2 = Stream(u8, error{}, Reader | Peek);
//    try std.testing.expect(!S2.has(Writer));
//
//    // try std.testing.expect(Reader != Writer);
//    var buffer = Buffer{};
//    // var s = buffer.stream(1);
//    // _ = s;
//    var s = State(*Buffer, Buffer.Error).init(buffer.stream(Reader | Peek));
//    _ = s;
//    // var s2 = buffer.stream(Writer);
//    // _ = s2;
//    // _ = s;
//    // _ = s;
//}
