const std = @import("std");
const os = std.os;
const ip = @import("ip.zig");
const utils = @import("utils.zig");

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

    pub fn parse(raw: []const u8) struct { header: Header, bytes_read: usize } {
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
        const options_union = Options.parse(bytes[options_start..options_end]);
        header.options = options_union.options;

        return .{ .header = header, .bytes_read = 20 + options_union.bytes_read };
    }

    // TODO: Not implemented
    pub fn bytes(self: Header) []const u8 {
        _ = self;
        return undefined;
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
    try std.testing.expectEqual(160, @bitOffsetOf(Header, "options"));
}

test "Header parsing from bytes" {
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

    const actual = Header.parse(bytes);

    try std.testing.expectEqual(expected_bytes_read, actual.bytes_read);
    try std.testing.expectEqual(expected_header, actual.header);
}

pub const HeaderFlags = packed struct(u12) {
    _: u6 = 0,
    urg: bool = false,
    ack: bool = false,
    psh: bool = false,
    rst: bool = false,
    syn: bool = false,
    fin: bool = false,
};

test "HeaderFlags memory layout" {
    try std.testing.expectEqual(6, @bitOffsetOf(HeaderFlags, "urg"));
    try std.testing.expectEqual(7, @bitOffsetOf(HeaderFlags, "ack"));
    try std.testing.expectEqual(8, @bitOffsetOf(HeaderFlags, "psh"));
    try std.testing.expectEqual(9, @bitOffsetOf(HeaderFlags, "rst"));
    try std.testing.expectEqual(10, @bitOffsetOf(HeaderFlags, "syn"));
    try std.testing.expectEqual(11, @bitOffsetOf(HeaderFlags, "fin"));
}

pub const Options = packed struct(u90) {
    maximum_segment_size: u16 = 1460,
    selective_ack: bool = false,
    selective_ack_permitted: bool = false,
    timestamp: u64 = 0,
    window_scale: u8 = 1,

    const KIND_END = 0;
    const KIND_NOOP = 1;
    const KIND_MAXIMUM_SEGMENT_SIZE = 2;
    const KIND_WINDOW_SCALE = 3;
    const KIND_SELECTIVE_ACK_PERMITTED = 4;
    const KIND_SELECTIVE_ACK = 5;
    const KIND_TIMESTAMP = 8;

    const LEN_END = 1;
    const LEN_NOOP = 1;
    const LEN_MAXIMUM_SEGMENT_SIZE = 4;
    const LEN_WINDOW_SCALE = 3;
    const LEN_SELECTIVE_ACK_PERMITTED = 2;
    const LEN_SELECTIVE_ACK = 2;
    const LEN_TIMESTAMP = 10;

    pub fn parse(bytes: []const u8) struct { options: Options, bytes_read: usize } {
        var options = Options{};

        var bytes_read: usize = 0;
        while (bytes_read < bytes.len) {
            const kind = bytes[bytes_read];
            switch (kind) {
                KIND_MAXIMUM_SEGMENT_SIZE => {
                    const start = bytes_read + 2;
                    const end = bytes_read + LEN_MAXIMUM_SEGMENT_SIZE;
                    options.maximum_segment_size = utils.intFromBytes(u16, bytes[start..end]);
                    bytes_read += LEN_MAXIMUM_SEGMENT_SIZE;
                },
                KIND_WINDOW_SCALE => {
                    options.window_scale = bytes[bytes_read + 2];
                    bytes_read += LEN_WINDOW_SCALE;
                },
                KIND_SELECTIVE_ACK_PERMITTED => {
                    options.selective_ack_permitted = true;
                    bytes_read += LEN_SELECTIVE_ACK_PERMITTED;
                },
                KIND_SELECTIVE_ACK => {
                    options.selective_ack = true;
                    bytes_read += LEN_SELECTIVE_ACK;
                },
                KIND_TIMESTAMP => {
                    const start = bytes_read + 2;
                    const end = bytes_read + LEN_TIMESTAMP;
                    options.timestamp = utils.intFromBytes(u64, bytes[start..end]);
                    bytes_read += LEN_TIMESTAMP;
                },
                KIND_NOOP => {
                    bytes_read += LEN_NOOP;
                },
                else => break, // KIND_END
            }
        }

        return .{ .options = options, .bytes_read = bytes_read };
    }
};

test "Options memory layout" {
    try std.testing.expectEqual(0, @bitOffsetOf(Options, "maximum_segment_size"));
    try std.testing.expectEqual(16, @bitOffsetOf(Options, "selective_ack"));
    try std.testing.expectEqual(17, @bitOffsetOf(Options, "selective_ack_permitted"));
    try std.testing.expectEqual(18, @bitOffsetOf(Options, "timestamp"));
    try std.testing.expectEqual(82, @bitOffsetOf(Options, "window_scale"));
}

test "Options parsing from bytes" {
    const bytes: []const u8 = &.{
        0b00000010, 0b00000100, 0b00000101, 0b10110100,
        0b00000100, 0b00000010, 0b00001000, 0b00001010,
        0b10010110, 0b00000000, 0b01100010, 0b01101011,
        0b00000000, 0b00000000, 0b00000000, 0b00000000,
        0b00000001, 0b00000011, 0b00000011, 0b00000111,
        0b00000000, 0b00000000, 0b00000000, 0b00000000, // Dummy bytes
        0b00000000, 0b00000000, 0b00000000, 0b00000000, // Dummy bytes
    };

    const expected_bytes_read = 20;
    const expected_options = Options{
        .maximum_segment_size = 1460,
        .selective_ack = false,
        .selective_ack_permitted = true,
        .timestamp = 10808747317390213120,
        .window_scale = 7,
    };

    const actual = Options.parse(bytes);

    try std.testing.expectEqual(expected_bytes_read, actual.bytes_read);
    try std.testing.expectEqual(expected_options, actual.options);
}

pub const Connection = struct {
    source_address: u32,
    source_port: u16,
    destination_address: u32,
    destination_port: u16,
};

pub const State = enum {
    Listen,
    SynSent,
    SynRecived,
    Established,
    FinWait1,
    FinWait2,
    CloseWait,
    Closing,
    LastAck,
    TimeWait,
    Closed,

    pub fn process(self: State, tun: os.File, iph: ip.Header, tcph: Header, data: []const u8) usize {
        _ = tun;
        _ = iph;
        _ = tcph;
        _ = data;

        return switch (self) {
            State.Listen => undefined,
            State.SynSent => undefined,
            State.SynRecived => undefined,
            State.Established => undefined,
            State.FinWait1 => undefined,
            State.FinWait2 => undefined,
            State.CloseWait => undefined,
            State.Closing => undefined,
            State.LastAck => undefined,
            State.TimeWait => undefined,
            State.Closed => 0,
        };
    }
};
