const std = @import("std");

pub fn Tuple(comptime types: anytype) type {
    comptime var b: [types.len]type = undefined;
    comptime var i: usize = 0;
    inline while (i < types.len) {
        b[i] = types[i];
        i += 1;
    }
    return std.meta.Tuple(&b);
}

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const eql = std.mem.eql;

test "Tuple" {
    const Record = Tuple(.{ []const u8, u64 });

    const Closure = struct {
        pub fn name(r: Record) []const u8 {
            return r[0];
        }

        pub fn age(r: Record) u64 {
            return r[1];
        }
    };

    const record = .{ "Daniel", 37 };
    try expect(std.mem.eql(u8, Closure.name(record), "Daniel"));
    try expect(Closure.age(record) == 37);
}
