const std = @import("std");

pub fn intFromBytes(comptime T: type, slice: []const u8) T {
    var sum: T = 0;
    for (0.., slice) |i, el| {
        const slf = (slice.len - i - 1) * 8;
        sum += @as(T, el) << @intCast(slf);
    }
    return sum;
}

test "integer from slice of bytes" {
    try std.testing.expectEqual(intFromBytes(u8, &.{0x1}), @as(u8, 0x01));
    try std.testing.expectEqual(intFromBytes(u16, &.{ 0x2, 0x1 }), @as(u16, 0x0201));
    try std.testing.expectEqual(intFromBytes(u32, &.{ 0x3, 0x2, 0x1 }), @as(u32, 0x030201));
    try std.testing.expectEqual(intFromBytes(u8, &.{}), @as(u8, 0x0));
}
