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

    pub fn new(bytes: [20]u8) TcpHeader {
        return TcpHeader{
            .source_port = utils.intFromBytes(u16, bytes[0..2]),
            .destination_port = utils.intFromBytes(u16, bytes[2..4]),
            .sequence_number = utils.intFromBytes(u32, bytes[4..8]),
            .acknowledgment_number = utils.intFromBytes(u32, bytes[8..12]),
            .data_offset = @intCast(bytes[12] >> 4 & 0xF),
            .flags = TcpHeaderFlags{
                .urg = bytes[13] & (1 << 5) != 0,
                .ack = bytes[13] & (1 << 4) != 0,
                .psh = bytes[13] & (1 << 3) != 0,
                .rst = bytes[13] & (1 << 2) != 0,
                .syn = bytes[13] & (1 << 1) != 0,
                .fin = bytes[13] & (1 << 0) != 0,
            },
            .window = utils.intFromBytes(u16, bytes[14..16]),
            .checksum = utils.intFromBytes(u16, bytes[16..18]),
            .urgent_pointer = utils.intFromBytes(u16, bytes[18..20]),
        };
    }
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

test "TcpHeader parsing from bytes" {
    const bytes = [20]u8{
        0b11100100, 0b01111100, 0b00000001, 0b10111011,
        0b11110101, 0b00110010, 0b10110010, 0b10101110,
        0b00000000, 0b00000000, 0b00000000, 0b00000000,
        0b10100000, 0b00000010, 0b01111101, 0b01111000,
        0b10000000, 0b00010101, 0b00000000, 0b00000000,
    };

    const actual = TcpHeader.new(bytes);
    const expected = TcpHeader{
        .source_port = 58492,
        .destination_port = 443,
        .sequence_number = 4113740462,
        .acknowledgment_number = 0,
        .data_offset = 10,
        .flags = TcpHeaderFlags{ .syn = true },
        .window = 32120,
        .checksum = 32789,
        .urgent_pointer = 0,
    };

    try std.testing.expectEqual(expected, actual);
}
