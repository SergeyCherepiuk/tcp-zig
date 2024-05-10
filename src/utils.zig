const std = @import("std");

pub fn stringToFixedArray(string: []const u8, comptime size: usize) [size]u8 {
    var buf: [size]u8 = [_]u8{0} ** size;
    std.mem.copyForwards(u8, &buf, string);
    return buf;
}
