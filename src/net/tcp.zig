const std = @import("std");
const mem = std.mem;
const ip = @import("ip.zig");
const utils = @import("utils.zig");

pub const Header = packed struct(u160) {
    source_port: u16,
    destination_port: u16,
    sequence_number: u32,
    acknowledgment_number: u32,
    data_offset: u4,
    flags: HeaderFlags,
    window: u16,
    checksum: u16,
    urgent_pointer: u16,

    pub fn new(bytes: [20]u8) Header {
        return Header{
            .source_port = utils.intFromBytes(u16, bytes[0..2]),
            .destination_port = utils.intFromBytes(u16, bytes[2..4]),
            .sequence_number = utils.intFromBytes(u32, bytes[4..8]),
            .acknowledgment_number = utils.intFromBytes(u32, bytes[8..12]),
            .data_offset = @intCast(bytes[12] >> 4 & 0xF),
            .flags = HeaderFlags{
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

pub const HeaderFlags = packed struct(u12) {
    _: u6 = 0,
    urg: bool = false,
    ack: bool = false,
    psh: bool = false,
    rst: bool = false,
    syn: bool = false,
    fin: bool = false,
};

pub const Connection = struct {
    source_address: u32,
    source_port: u16,
    destination_address: u32,
    destination_port: u16,
};

pub const State = struct {
    pub fn processPacket(
        _: State,
        allocator: mem.Allocator,
        ip_header: ip.Header,
        tcp_header: Header,
        data: []const u8,
    ) !void {
        std.debug.print("{s}:{d} -> {s}:{d} {d} bytes over tcp\n", .{
            try utils.formatIp(allocator, ip_header.source_address),
            tcp_header.source_port,
            try utils.formatIp(allocator, ip_header.destination_address),
            tcp_header.destination_port,
            data.len,
        });
    }
};

test "Header memory layout" {
    try std.testing.expectEqual(0, @bitOffsetOf(Header, "source_port"));
    try std.testing.expectEqual(16, @bitOffsetOf(Header, "destination_port"));
    try std.testing.expectEqual(32, @bitOffsetOf(Header, "sequence_number"));
    try std.testing.expectEqual(64, @bitOffsetOf(Header, "acknowledgment_number"));
    try std.testing.expectEqual(96, @bitOffsetOf(Header, "data_offset"));
    try std.testing.expectEqual(100, @bitOffsetOf(Header, "flags"));
    try std.testing.expectEqual(112, @bitOffsetOf(Header, "window"));
    try std.testing.expectEqual(128, @bitOffsetOf(Header, "checksum"));
    try std.testing.expectEqual(144, @bitOffsetOf(Header, "urgent_pointer"));
}

test "HeaderFlags memory layout" {
    try std.testing.expectEqual(6, @bitOffsetOf(HeaderFlags, "urg"));
    try std.testing.expectEqual(7, @bitOffsetOf(HeaderFlags, "ack"));
    try std.testing.expectEqual(8, @bitOffsetOf(HeaderFlags, "psh"));
    try std.testing.expectEqual(9, @bitOffsetOf(HeaderFlags, "rst"));
    try std.testing.expectEqual(10, @bitOffsetOf(HeaderFlags, "syn"));
    try std.testing.expectEqual(11, @bitOffsetOf(HeaderFlags, "fin"));
}

test "Header parsing from bytes" {
    const bytes = [20]u8{
        0b11100100, 0b01111100, 0b00000001, 0b10111011,
        0b11110101, 0b00110010, 0b10110010, 0b10101110,
        0b00000000, 0b00000000, 0b00000000, 0b00000000,
        0b10100000, 0b00000010, 0b01111101, 0b01111000,
        0b10000000, 0b00010101, 0b00000000, 0b00000000,
    };

    const actual = Header.new(bytes);
    const expected = Header{
        .source_port = 58492,
        .destination_port = 443,
        .sequence_number = 4113740462,
        .acknowledgment_number = 0,
        .data_offset = 10,
        .flags = HeaderFlags{ .syn = true },
        .window = 32120,
        .checksum = 32789,
        .urgent_pointer = 0,
    };

    try std.testing.expectEqual(expected, actual);
}
