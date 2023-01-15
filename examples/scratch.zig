const std = @import("std");
const ubu = @import("ubu");

const c = @cImport({
    @cInclude("sys/socket.h");
    @cInclude("netinet/tcp.h");
    @cInclude("unistd.h");
    @cInclude("time.h");
});

extern fn htons(u16) u16;
extern fn htonl(u32) u32;
extern fn bind(c_int, *anyopaque, c.socklen_t) c_int;

const len = 2048;

// const res =
// \\ HTTP/1.1 200 OK\r
// \\ Date: Mon, 04 JAN 2023 18:07:00 GMT\r
// ;

pub fn handleClient(fd: c_int) void {
    while (true) {
        var buf: [len]u8 = [_:0]u8{0} ** len;
        var ret = c.read(fd, &buf[0], len);
        if (ret == 0) {
            return;
        } else if (ret == -1) {
            ubu.eprintln("Read error!", .{}) catch {};
            return;
        }

        ubu.println("{s}", .{buf}) catch {};

        const r0 = "HTTP/1.1 200 OK\r\n";
        // std.time.ns_per_min
        // std.time.Date

        _ = c.write(fd, r0, r0.len);
    }
}

pub const WeekDay = enum(u32) {
    Sun = 0,
    Mon,
    Tue,
    Wed,
    Thu,
    Fri,
    Sat,
};

fn isLeapYear(year: u32) bool {
    if (year % 400 == 0) {
        return true;
    } else if (year % 100 == 0) {
        return false;
    } else if (year % 4 == 0) {
        return true;
    }

    return false;
}

pub fn weekDay(year: u32, month: std.time.epoch.Month, day: u32) WeekDay {
    const offsets_common = [12]u32{ 0, 3, 3, 6, 1, 4, 6, 2, 5, 0, 3, 5 };
    const offsets_leap = [12]u32{ 0, 3, 4, 0, 2, 5, 0, 3, 6, 1, 4, 6 };

    var m = @intCast(u32, month.numeric() - 1);

    var d1 = (1 + 5 * ((year - 1) % 4) + 4 * ((year - 1) % 100) + 6 * ((year - 1) % 400)) % 7;

    var offset = if (isLeapYear(year)) offsets_leap[@intCast(usize, m)] else offsets_common[@intCast(usize, m)];
    _ = offset;

    return @intToEnum(WeekDay, (d1 + m + day) % 7);
}

pub fn main() !void {
    var secs = std.time.timestamp();
    var e = std.time.epoch.EpochSeconds{ .secs = @intCast(u64, secs) };
    var day = e.getEpochDay();
    var ed = std.time.epoch.EpochDay{ .day = day.day };
    var year = ed.calculateYearDay();
    var dayseconds = e.getDaySeconds();
    // year.year
    std.log.info("Date: day = {}, year = {}, month = {}, monthday = {}, daysecs = {}, {}:{}:{}, day = {}", .{
        year.day,
        year.year,
        year.calculateMonthDay().month,
        year.calculateMonthDay().day_index,
        dayseconds.secs,
        dayseconds.getHoursIntoDay(),
        dayseconds.getMinutesIntoHour(),
        dayseconds.getSecondsIntoMinute(),
        weekDay(@intCast(u32, 2023), year.calculateMonthDay().month, @intCast(u32, year.calculateMonthDay().day_index)),
    });

    var server_fd: c_int = c.socket(c.PF_INET, c.SOCK_STREAM, c.IPPROTO_TCP);
    defer _ = c.close(server_fd);

    if (server_fd == -1) {
        @panic("cannot create socker");
    }

    var sa = c.struct_sockaddr_in{
        .sin_family = c.AF_INET,
        .sin_len = @as(u8, 0),
        .sin_port = htons(1234),
        .sin_zero = [1]u8{0} ** 8,
        .sin_addr = .{
            .s_addr = htonl(c.INADDR_ANY),
        },
    };

    if (bind(server_fd, &sa, @sizeOf(@TypeOf(sa))) == -1) {
        _ = c.close(server_fd);
        @panic("bind failed!");
    }

    if (c.listen(server_fd, 5) == -1) {
        _ = c.close(server_fd);
        @panic("listen failed!");
    }

    while (true) {
        std.log.info(".", .{});
        var client_fd = c.accept(server_fd, null, null);

        if (client_fd < 0) {
            _ = c.close(server_fd);
            @panic("accept failed!");
        }

        std.log.info("accepted!", .{});
        handleClient(client_fd);

        if (c.shutdown(client_fd, c.SHUT_RDWR) == -1) {
            @panic("shutdown failed!");
        }
        _ = c.close(server_fd);
    }
}
