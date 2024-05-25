const std = @import("std");
const mem = std.mem;

const utils = @import("../utils.zig");

const Options = @import("options.zig").Options;

pub const Header = packed struct(u250) {
    source_port: u16,
    destination_port: u16,
    sequence_number: u32,
    acknowledgment_number: u32,
    data_offset: u4,
    flags: HeaderFlags,
    window: u16,
    checksum: u16,
    urgent_pointer: u16,
    options: Options,

    pub fn fromBytes(raw: []const u8) struct { header: Header, bytes_read: usize } {
        var header = Header{
            .source_port = utils.intFromBytes(u16, raw[0..2]),
            .destination_port = utils.intFromBytes(u16, raw[2..4]),
            .sequence_number = utils.intFromBytes(u32, raw[4..8]),
            .acknowledgment_number = utils.intFromBytes(u32, raw[8..12]),
            .data_offset = @intCast(raw[12] >> 4 & 0xF),
            .flags = .{
                .urg = raw[13] & (1 << 5) != 0,
                .ack = raw[13] & (1 << 4) != 0,
                .psh = raw[13] & (1 << 3) != 0,
                .rst = raw[13] & (1 << 2) != 0,
                .syn = raw[13] & (1 << 1) != 0,
                .fin = raw[13] & (1 << 0) != 0,
            },
            .window = utils.intFromBytes(u16, raw[14..16]),
            .checksum = utils.intFromBytes(u16, raw[16..18]),
            .urgent_pointer = utils.intFromBytes(u16, raw[18..20]),
            .options = undefined,
        };

        const options_start = @as(u16, header.data_offset) * 4 - 20;
        const options_end = @as(u16, header.data_offset) * 4;
        const options_union = Options.fromBytes(raw[options_start..options_end]);
        header.options = options_union.options;

        return .{ .header = header, .bytes_read = 20 + options_union.bytes_read };
    }

    pub fn toBytes(self: Header, allocator: mem.Allocator) mem.Allocator.Error![]const u8 {
        var buf: []u8 = try allocator.alloc(u8, 44);

        mem.copyForwards(u8, buf[0..2], &utils.bytesFromInt(u16, self.source_port));
        mem.copyForwards(u8, buf[2..4], &utils.bytesFromInt(u16, self.destination_port));
        mem.copyForwards(u8, buf[4..8], &utils.bytesFromInt(u32, self.sequence_number));
        mem.copyForwards(u8, buf[8..12], &utils.bytesFromInt(u32, self.acknowledgment_number));
        buf[12] = @as(u8, self.data_offset) << 4;
        buf[13] = @truncate(@as(u12, @bitCast(self.flags)));
        mem.copyForwards(u8, buf[14..16], &utils.bytesFromInt(u16, self.window));
        mem.copyForwards(u8, buf[16..18], &utils.bytesFromInt(u16, self.checksum));
        mem.copyForwards(u8, buf[18..20], &utils.bytesFromInt(u16, self.urgent_pointer));

        const option_bytes = try self.options.toBytes(allocator);
        defer allocator.free(option_bytes);
        mem.copyForwards(u8, buf[20..42], option_bytes);

        const padding: u16 = 0;
        mem.copyForwards(u8, buf[42..44], &utils.bytesFromInt(u16, padding));

        return buf;
    }
};

test "header memory layout" {
    try std.testing.expectEqual(0, @bitOffsetOf(Header, "source_port"));
    try std.testing.expectEqual(16, @bitOffsetOf(Header, "destination_port"));
    try std.testing.expectEqual(32, @bitOffsetOf(Header, "sequence_number"));
    try std.testing.expectEqual(64, @bitOffsetOf(Header, "acknowledgment_number"));
    try std.testing.expectEqual(96, @bitOffsetOf(Header, "data_offset"));
    try std.testing.expectEqual(100, @bitOffsetOf(Header, "flags"));
    try std.testing.expectEqual(112, @bitOffsetOf(Header, "window"));
    try std.testing.expectEqual(128, @bitOffsetOf(Header, "checksum"));
    try std.testing.expectEqual(144, @bitOffsetOf(Header, "urgent_pointer"));
    try std.testing.expectEqual(160, @bitOffsetOf(Header, "options"));
}

test "header from bytes" {
    const bytes: []const u8 = &.{
        0b10001100, 0b10110100, 0b00000001, 0b10111011,
        0b10001110, 0b01100001, 0b00110010, 0b10010100,
        0b00000000, 0b00000000, 0b00000000, 0b00000000,
        0b10100000, 0b00000010, 0b01111101, 0b01111000,
        0b11101100, 0b01101010, 0b00000000, 0b00000000,
        0b00000010, 0b00000100, 0b00000101, 0b10110100,
        0b00000100, 0b00000010, 0b00001000, 0b00001010,
        0b10010110, 0b00000000, 0b01100010, 0b01101011,
        0b00000000, 0b00000000, 0b00000000, 0b00000000,
        0b00000001, 0b00000011, 0b00000011, 0b00000111,
        0b00000000, 0b00000000, 0b00000000, 0b00000000, // Dummy bytes
        0b00000000, 0b00000000, 0b00000000, 0b00000000, // Dummy bytes
    };

    const expected_bytes_read = 40;
    const expected_header = Header{
        .source_port = 36020,
        .destination_port = 443,
        .sequence_number = 2388734612,
        .acknowledgment_number = 0,
        .data_offset = 10,
        .flags = .{ .syn = true },
        .window = 32120,
        .checksum = 60522,
        .urgent_pointer = 0,
        .options = .{
            .maximum_segment_size = 1460,
            .selective_ack = false,
            .selective_ack_permitted = true,
            .timestamp = 10808747317390213120,
            .window_scale = 7,
        },
    };

    const actual = Header.fromBytes(bytes);

    try std.testing.expectEqual(expected_bytes_read, actual.bytes_read);
    try std.testing.expectEqual(expected_header, actual.header);
}

test "header to bytes" {
    const header = Header{
        .source_port = 36020,
        .destination_port = 443,
        .sequence_number = 2388734612,
        .acknowledgment_number = 0,
        .data_offset = 10,
        .flags = .{ .syn = true },
        .window = 32120,
        .checksum = 60522,
        .urgent_pointer = 0,
        .options = .{
            .maximum_segment_size = 1460,
            .selective_ack = false,
            .selective_ack_permitted = true,
            .timestamp = 10808747317390213120,
            .window_scale = 7,
        },
    };

    const expected_bytes = &.{
        0b10001100, 0b10110100, 0b00000001, 0b10111011,
        0b10001110, 0b01100001, 0b00110010, 0b10010100,
        0b00000000, 0b00000000, 0b00000000, 0b00000000,
        0b10100000, 0b00000010, 0b01111101, 0b01111000,
        0b11101100, 0b01101010, 0b00000000, 0b00000000,
        0b00000010, 0b00000100, 0b00000101, 0b10110100,
        0b00001000, 0b00001010, 0b10010110, 0b00000000,
        0b01100010, 0b01101011, 0b00000000, 0b00000000,
        0b00000000, 0b00000000, 0b00000011, 0b00000011,
        0b00000111, 0b00000001, 0b00000001, 0b00000100,
        0b00000010, 0b00000000, 0b00000000, 0b00000000,
    };

    const actual_bytes = try header.toBytes(std.testing.allocator);
    defer std.testing.allocator.free(actual_bytes);

    try std.testing.expectEqualSlices(u8, expected_bytes, actual_bytes);
}

pub const HeaderFlags = packed struct(u12) {
    fin: bool = false,
    syn: bool = false,
    rst: bool = false,
    psh: bool = false,
    ack: bool = false,
    urg: bool = false,
    _: u6 = 0,
};

test "header flags memory layout" {
    try std.testing.expectEqual(0, @bitOffsetOf(HeaderFlags, "fin"));
    try std.testing.expectEqual(1, @bitOffsetOf(HeaderFlags, "syn"));
    try std.testing.expectEqual(2, @bitOffsetOf(HeaderFlags, "rst"));
    try std.testing.expectEqual(3, @bitOffsetOf(HeaderFlags, "psh"));
    try std.testing.expectEqual(4, @bitOffsetOf(HeaderFlags, "ack"));
    try std.testing.expectEqual(5, @bitOffsetOf(HeaderFlags, "urg"));
}
