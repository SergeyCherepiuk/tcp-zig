const std = @import("std");
const utils = @import("utils.zig");

pub const Ip4Header = packed struct(u160) {
    version: u4,
    header_length: u4,
    type_of_service: u8,
    total_length: u16,
    id: u16,
    flags: Ip4HeaderFlags,
    fragment_offset: u13,
    ttl: u8,
    protocol: u8,
    header_checksum: u16,
    source_address: u32,
    destination_address: u32,

    pub fn new(bytes: *[20]u8) Ip4Header {
        return Ip4Header{
            .version = @intCast(bytes[0] >> 4 & 0xF),
            .header_length = @intCast(bytes[0] & 0xF),
            .type_of_service = bytes[1],
            .total_length = utils.intFromBytes(u16, bytes[2..4]),
            .id = utils.intFromBytes(u16, bytes[4..6]),
            .flags = Ip4HeaderFlags{
                .df = (bytes[6] >> 5) & 0x2 != 0,
                .mf = (bytes[6] >> 5) & 0x1 != 0,
            },
            .fragment_offset = utils.intFromBytes(u13, &[_]u8{ bytes[6] & 0x1F, bytes[7] }),
            .ttl = bytes[8],
            .protocol = bytes[9],
            .header_checksum = utils.intFromBytes(u16, bytes[10..12]),
            .source_address = utils.intFromBytes(u32, bytes[12..16]),
            .destination_address = utils.intFromBytes(u32, bytes[16..20]),
        };
    }
};

pub const Ip4HeaderFlags = packed struct(u3) {
    _: u1 = 0,
    df: bool = true,
    mf: bool = false,
};

test "Ip4Header memory layout" {
    try std.testing.expectEqual(0, @bitOffsetOf(Ip4Header, "version"));
    try std.testing.expectEqual(4, @bitOffsetOf(Ip4Header, "header_length"));
    try std.testing.expectEqual(8, @bitOffsetOf(Ip4Header, "type_of_service"));
    try std.testing.expectEqual(16, @bitOffsetOf(Ip4Header, "total_length"));
    try std.testing.expectEqual(32, @bitOffsetOf(Ip4Header, "id"));
    try std.testing.expectEqual(48, @bitOffsetOf(Ip4Header, "flags"));
    try std.testing.expectEqual(51, @bitOffsetOf(Ip4Header, "fragment_offset"));
    try std.testing.expectEqual(64, @bitOffsetOf(Ip4Header, "ttl"));
    try std.testing.expectEqual(72, @bitOffsetOf(Ip4Header, "protocol"));
    try std.testing.expectEqual(80, @bitOffsetOf(Ip4Header, "header_checksum"));
    try std.testing.expectEqual(96, @bitOffsetOf(Ip4Header, "source_address"));
    try std.testing.expectEqual(128, @bitOffsetOf(Ip4Header, "destination_address"));
}

test "Ip4HeaderFlags memory layout" {
    try std.testing.expectEqual(1, @bitOffsetOf(Ip4HeaderFlags, "df"));
    try std.testing.expectEqual(2, @bitOffsetOf(Ip4HeaderFlags, "mf"));
}
