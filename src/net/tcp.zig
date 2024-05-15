const std = @import("std");
const utils = @import("utils.zig");

pub const TcpHeader = packed struct(u160) {
    source_port: u16,
    destination_port: u16,
    sequence_number: u32,
    acknowledgment_number: u32,
    data_offset: u4,
    flags: TcpHeaderFlags,
    window: u16,
    checksum: u16,
    urgent_pointer: u16,

    // TODO: Implement contructor ("new") function
};

pub const TcpHeaderFlags = packed struct(u12) {
    _: u6 = 0,
    urg: bool = false,
    ack: bool = false,
    psh: bool = false,
    rst: bool = false,
    syn: bool = false,
    fin: bool = false,
};

test "TcpHeader memory layout" {
    try std.testing.expectEqual(0, @bitOffsetOf(TcpHeader, "source_port"));
    try std.testing.expectEqual(16, @bitOffsetOf(TcpHeader, "destination_port"));
    try std.testing.expectEqual(32, @bitOffsetOf(TcpHeader, "sequence_number"));
    try std.testing.expectEqual(64, @bitOffsetOf(TcpHeader, "acknowledgment_number"));
    try std.testing.expectEqual(96, @bitOffsetOf(TcpHeader, "data_offset"));
    try std.testing.expectEqual(100, @bitOffsetOf(TcpHeader, "flags"));
    try std.testing.expectEqual(112, @bitOffsetOf(TcpHeader, "window"));
    try std.testing.expectEqual(128, @bitOffsetOf(TcpHeader, "checksum"));
    try std.testing.expectEqual(144, @bitOffsetOf(TcpHeader, "urgent_pointer"));
}

test "TcpHeaderFlags memory layout" {
    try std.testing.expectEqual(6, @bitOffsetOf(TcpHeaderFlags, "urg"));
    try std.testing.expectEqual(7, @bitOffsetOf(TcpHeaderFlags, "ack"));
    try std.testing.expectEqual(8, @bitOffsetOf(TcpHeaderFlags, "psh"));
    try std.testing.expectEqual(9, @bitOffsetOf(TcpHeaderFlags, "rst"));
    try std.testing.expectEqual(10, @bitOffsetOf(TcpHeaderFlags, "syn"));
    try std.testing.expectEqual(11, @bitOffsetOf(TcpHeaderFlags, "fin"));
}
