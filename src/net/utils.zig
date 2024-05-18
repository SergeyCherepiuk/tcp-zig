const std = @import("std");
const mem = std.mem;
const fmt = std.fmt;
const heap = std.heap;

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

pub fn formatIp(allocator: mem.Allocator, address: u32) fmt.AllocPrintError![]const u8 {
    return try fmt.allocPrint(allocator, "{d}.{d}.{d}.{d}", .{
        (address >> 24) & 0xFF,
        (address >> 16) & 0xFF,
        (address >> 8) & 0xFF,
        (address >> 0) & 0xFF,
    });
}

test "ip address formatting" {
    const Datum = struct { address: u32, expected: []const u8 };
    const data = [_]Datum{
        Datum{ .address = 2130706433, .expected = "127.0.0.1" },
        Datum{ .address = 167772161, .expected = "10.0.0.1" },
        Datum{ .address = 2886729729, .expected = "172.16.0.1" },
        Datum{ .address = 3232235521, .expected = "192.168.0.1" },
        Datum{ .address = 134744072, .expected = "8.8.8.8" },
    };

    const allocator = heap.page_allocator;
    for (data) |datum| {
        const actual = try formatIp(allocator, datum.address);
        try std.testing.expectEqualSlices(u8, datum.expected, actual);
    }
}
