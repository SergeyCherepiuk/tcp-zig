const std = @import("std");
const mem = std.mem;
const rand = std.crypto.random;

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

    // TODO: Unit test
    pub fn new(
        source_address: u32,
        destination_address: u32,
        data_length: usize,
        protocol: u8,
    ) Header {
        var header = Header{
            .version = 4,
            .header_length = 5,
            .type_of_service = 0,
            .total_length = 20 + data_length,
            .id = rand.int(u16),
            .flags = HeaderFlags{ .df = true },
            .fragment_offset = 0,
            .ttl = 64,
            .protocol = protocol,
            .checksum = 0,
            .source_address = source_address,
            .destination_address = destination_address,
        };
        header.checksum = header.checksum();
        return header;
    }

    // TODO: Review and refactor
    pub fn checksum(self: Header) u16 {
        const df = @as(u16, @intFromBool(self.flags.df)) << 14;
        const mf = @as(u16, @intFromBool(self.flags.mf)) << 13;
        const flags_and_fragment_offset = df | mf | @as(u16, self.fragment_offset);

        const five_hex_digit_sum =
            @as(u32, (@as(u16, self.version) << 12) | (@as(u16, self.header_length) << 8) | @as(u16, self.type_of_service)) +
            @as(u32, self.total_length) +
            @as(u32, self.id) +
            @as(u32, flags_and_fragment_offset) +
            @as(u32, (@as(u16, self.ttl) << 8) | @as(u16, self.protocol)) +
            @as(u32, self.source_address >> 16) +
            @as(u32, self.source_address & 0xFFFF) +
            @as(u32, self.destination_address >> 16) +
            @as(u32, self.destination_address & 0xFFFF);

        const four_hex_digit_sum =
            @as(u16, @truncate(five_hex_digit_sum >> 16)) +
            @as(u16, @truncate(five_hex_digit_sum & 0x0FFFF));

        return 0xFFFF - four_hex_digit_sum;
    }

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

    pub fn toBytes(self: Header, allocator: mem.Allocator) mem.Allocator.Error![]const u8 {
        var buf: []u8 = try allocator.alloc(u8, 20);

        buf[0] = (@as(u8, self.version) << 4) + self.header_length;
        buf[1] = self.type_of_service;
        mem.copyForwards(u8, buf[2..4], &utils.bytesFromInt(u16, self.total_length));
        mem.copyForwards(u8, buf[4..6], &utils.bytesFromInt(u16, self.id));

        buf[6] = (@as(u8, @intFromBool(self.flags.df)) << 6) +
            (@as(u8, @intFromBool(self.flags.mf)) << 5) +
            @as(u8, @truncate(self.fragment_offset >> 8));

        buf[7] = @truncate(self.fragment_offset & 0xF);

        buf[8] = self.ttl;
        buf[9] = self.protocol;
        mem.copyForwards(u8, buf[10..12], &utils.bytesFromInt(u16, self.header_checksum));
        mem.copyForwards(u8, buf[12..16], &utils.bytesFromInt(u32, self.source_address));
        mem.copyForwards(u8, buf[16..20], &utils.bytesFromInt(u32, self.destination_address));

        return buf;
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

test "header checksum" {
    const header = Header{
        .version = 4,
        .header_length = 5,
        .type_of_service = 0,
        .total_length = 52,
        .id = 30155,
        .flags = HeaderFlags{ .df = true },
        .fragment_offset = 0,
        .ttl = 64,
        .protocol = 6,
        .header_checksum = 0,
        .source_address = 2887058667,
        .destination_address = 1820996403,
    };

    const expected_checksum = 0x743b;

    const actual_checksum = header.checksum();

    try std.testing.expectEqual(expected_checksum, actual_checksum);
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

test "header to bytes" {
    const header = Header{
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

    const expected_bytes: []const u8 = &.{
        0b01000101, 0b00000000, 0b00000000, 0b10000000,
        0b11001011, 0b10110101, 0b01000000, 0b00000000,
        0b01000000, 0b00000001, 0b11011001, 0b01110011,
        0b11000000, 0b10101000, 0b00001010, 0b00000001,
        0b11000000, 0b10101000, 0b00001010, 0b00000010,
    };

    const actual_bytes = try header.toBytes(std.testing.allocator);
    defer std.testing.allocator.free(actual_bytes);

    try std.testing.expectEqualSlices(u8, expected_bytes, actual_bytes);
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
