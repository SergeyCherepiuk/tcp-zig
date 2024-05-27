const std = @import("std");
const mem = std.mem;

const utils = @import("utils.zig");

pub const Header = packed struct(u160) {
    version: u4,
    header_length: u4,
    type_of_service: u8,
    total_length: u16,
    id: u16,
    flags: HeaderFlags,
    fragment_offset: u13,
    ttl: u8,
    protocol: u8,
    header_checksum: u16,
    source_address: u32,
    destination_address: u32,

    pub fn fromBytes(raw: []const u8) struct { header: Header, bytes_read: usize } {
        const header = Header{
            .version = @intCast(raw[0] >> 4 & 0xF),
            .header_length = @intCast(raw[0] & 0xF),
            .type_of_service = raw[1],
            .total_length = utils.intFromBytes(u16, raw[2..4]),
            .id = utils.intFromBytes(u16, raw[4..6]),
            .flags = .{
                .df = (raw[6] >> 5) & (1 << 1) != 0,
                .mf = (raw[6] >> 5) & (1 << 0) != 0,
            },
            .fragment_offset = utils.intFromBytes(u13, &[_]u8{ raw[6] & 0x1F, raw[7] }),
            .ttl = raw[8],
            .protocol = raw[9],
            .header_checksum = utils.intFromBytes(u16, raw[10..12]),
            .source_address = utils.intFromBytes(u32, raw[12..16]),
            .destination_address = utils.intFromBytes(u32, raw[16..20]),
        };
        return .{ .header = header, .bytes_read = 20 };
    }

    // TODO: Not implemented and not tested
    pub fn bytes(self: Header, allocator: mem.Allocator) []const u8 {
        _ = self;
        _ = allocator;
        return undefined;
    }
};

test "header memory layout" {
    try std.testing.expectEqual(0, @bitOffsetOf(Header, "version"));
    try std.testing.expectEqual(4, @bitOffsetOf(Header, "header_length"));
    try std.testing.expectEqual(8, @bitOffsetOf(Header, "type_of_service"));
    try std.testing.expectEqual(16, @bitOffsetOf(Header, "total_length"));
    try std.testing.expectEqual(32, @bitOffsetOf(Header, "id"));
    try std.testing.expectEqual(48, @bitOffsetOf(Header, "flags"));
    try std.testing.expectEqual(51, @bitOffsetOf(Header, "fragment_offset"));
    try std.testing.expectEqual(64, @bitOffsetOf(Header, "ttl"));
    try std.testing.expectEqual(72, @bitOffsetOf(Header, "protocol"));
    try std.testing.expectEqual(80, @bitOffsetOf(Header, "header_checksum"));
    try std.testing.expectEqual(96, @bitOffsetOf(Header, "source_address"));
    try std.testing.expectEqual(128, @bitOffsetOf(Header, "destination_address"));
}

test "header from bytes" {
    const bytes: []const u8 = &.{
        0b01000101, 0b00000000, 0b00000000, 0b10000000,
        0b11001011, 0b10110101, 0b01000000, 0b00000000,
        0b01000000, 0b00000001, 0b11011001, 0b01110011,
        0b11000000, 0b10101000, 0b00001010, 0b00000001,
        0b11000000, 0b10101000, 0b00001010, 0b00000010,
        0b00000000, 0b00000000, 0b00000000, 0b00000000, // Dummy bytes
        0b00000000, 0b00000000, 0b00000000, 0b00000000, // Dummy bytes
    };

    const expected_bytes_read = 20;
    const expected_header = Header{
        .version = 4,
        .header_length = 5,
        .type_of_service = 0,
        .total_length = 128,
        .id = 52149,
        .flags = .{ .df = true },
        .fragment_offset = 0,
        .ttl = 64,
        .protocol = 1,
        .header_checksum = 55667,
        .source_address = 3232238081,
        .destination_address = 3232238082,
    };

    const actual = Header.fromBytes(bytes);

    try std.testing.expectEqual(expected_bytes_read, actual.bytes_read);
    try std.testing.expectEqual(expected_header, actual.header);
}

pub const HeaderFlags = packed struct(u3) {
    _: u1 = 0,
    df: bool = true,
    mf: bool = false,
};

test "header flags memory layout" {
    try std.testing.expectEqual(1, @bitOffsetOf(HeaderFlags, "df"));
    try std.testing.expectEqual(2, @bitOffsetOf(HeaderFlags, "mf"));
}
