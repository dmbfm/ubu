const std = @import("std");
const ubu = @import("ubu");
const Value = ubu.constraint.Value;
const expect = std.testing.expect;
const mem = std.mem;

const Dir = enum {
    left,
    right,
    up,
    down,

    pub fn opposite(dir: Dir) Dir {
        return switch (dir) {
            .left => .right,
            .right => .left,
            .up => .down,
            .down => .up,
        };
    }

    pub fn name(dir: Dir) []const u8 {
        return switch (dir) {
            .left => "left",
            .right => "right",
            .up => "up",
            .down => "down",
        };
    }
};

test "Dir/name" {
    try expect(mem.eql(u8, Dir.left.name(), "left"));
    try expect(mem.eql(u8, Dir.right.name(), "right"));
    try expect(mem.eql(u8, Dir.up.name(), "up"));
    try expect(mem.eql(u8, Dir.down.name(), "down"));
}

const Rule = struct {
    a: u8,
    b: u8,
    dir: Dir,

    pub fn init(a: u8, dir: Dir, b: u8) Rule {
        return .{ .a = a, .b = b, .dir = dir };
    }

    pub fn equivalent(lhs: Rule, rhs: Rule) bool {
        if (lhs.dir == rhs.dir and lhs.a == rhs.a and lhs.b == rhs.b) {
            return true;
        } else if (lhs.dir == rhs.dir.opposite() and lhs.a == rhs.b and lhs.b == rhs.a) {
            return true;
        }

        return false;
    }

    pub fn format(
        self: Rule,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = options;
        _ = fmt;
        return std.fmt.format(writer, "({} {s} of {})", .{ self.a, self.dir.name(), self.b });
    }
};

test "Rule/equivalent" {
    try expect(Rule.init(0, .left, 1).equivalent(Rule.init(1, .right, 0)));
    try expect(Rule.init(0, .up, 1).equivalent(Rule.init(1, .down, 0)));
}

const RuleSet = struct {
    const N = 1024;
    items: [N]Rule = undefined,
    num: usize = 0,

    pub fn initWithImage(img: ubu.image.Gray) !RuleSet {
        var set = RuleSet{};
        for (ubu.range(img.height)) |_, y| {
            for (ubu.range(img.width)) |_, x| {
                var value = img.get(x, y).?;
                if (x > 0) {
                    try set.add(img.get(x - 1, y).?, .left, value);
                }

                if (x < (img.width - 1)) {
                    try set.add(img.get(x + 1, y).?, .right, value);
                }

                if (y > 0) {
                    try set.add(img.get(x, y - 1).?, .up, value);
                }

                if (y < (img.height - 1)) {
                    try set.add(img.get(x, y + 1).?, .down, value);
                }
            }
        }

        return set;
    }

    pub fn has(self: RuleSet, rule: Rule) bool {
        for (self.items[0..self.num]) |r| {
            if (rule.equivalent(r)) {
                return true;
            }
        }

        return false;
    }

    pub fn add(self: *RuleSet, a: u8, dir: Dir, b: u8) !void {
        return self.addRule(Rule.init(a, dir, b));
    }

    pub fn addRule(self: *RuleSet, rule: Rule) !void {
        if (self.has(rule)) {
            return;
        }

        if (self.num >= N) {
            return error.TooManyRulez;
        }

        self.items[self.num] = rule;
        self.num += 1;
    }

    pub fn rules(self: *RuleSet) []Rule {
        return self.items[0..self.num];
    }
};

pub fn main() !void {
    var allocator = ubu.allocators.GlobalArena.allocator();
    defer ubu.allocators.GlobalArena.deinit();

    // var set = RuleSet{};

    var img: ubu.image.Gray = (try ubu.image.ppm.decodeFilePath(
        allocator,
        "square.ppm",
        .{ .scale_to_max_value = false },
    )).gray;
    defer img.deinit();

    var set = try RuleSet.initWithImage(img);
    std.log.info("{any}", .{set.rules()});
}
