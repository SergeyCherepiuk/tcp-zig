const std = @import("std");
const mem = std.mem;
const fs = std.fs;
const arch = @import("builtin").cpu.arch;

const utils = @import("utils.zig");

const IpHeader = @import("ip.zig").Header;

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

        const flagsBitset = @as(u12, @bitCast(self.flags));
        buf[13] = switch (arch.endian()) {
            .little => @truncate(@bitReverse(flagsBitset)),
            .big => @truncate(flagsBitset),
        };

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
    _: u6 = 0,
    urg: bool = false,
    ack: bool = false,
    psh: bool = false,
    rst: bool = false,
    syn: bool = false,
    fin: bool = false,
};

test "header flags memory layout" {
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

    pub fn fromBytes(raw: []const u8) struct { options: Options, bytes_read: usize } {
        var options = Options{};

        var bytes_read: usize = 0;
        while (bytes_read < raw.len) {
            const kind = raw[bytes_read];
            switch (kind) {
                KIND_MAXIMUM_SEGMENT_SIZE => {
                    const start = bytes_read + 2;
                    const end = bytes_read + LEN_MAXIMUM_SEGMENT_SIZE;
                    options.maximum_segment_size = utils.intFromBytes(u16, raw[start..end]);
                    bytes_read += LEN_MAXIMUM_SEGMENT_SIZE;
                },
                KIND_WINDOW_SCALE => {
                    options.window_scale = raw[bytes_read + 2];
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
                    options.timestamp = utils.intFromBytes(u64, raw[start..end]);
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

    pub fn toBytes(self: Options, allocator: mem.Allocator) mem.Allocator.Error![]const u8 {
        const size = LEN_MAXIMUM_SEGMENT_SIZE + LEN_TIMESTAMP + LEN_WINDOW_SCALE +
            LEN_SELECTIVE_ACK + LEN_SELECTIVE_ACK_PERMITTED + LEN_END;
        const buf = try allocator.alloc(u8, size);

        buf[0] = KIND_MAXIMUM_SEGMENT_SIZE;
        buf[1] = LEN_MAXIMUM_SEGMENT_SIZE;
        mem.copyForwards(u8, buf[2..4], &utils.bytesFromInt(u16, self.maximum_segment_size));

        buf[4] = KIND_TIMESTAMP;
        buf[5] = LEN_TIMESTAMP;
        mem.copyForwards(u8, buf[6..14], &utils.bytesFromInt(u64, self.timestamp));

        buf[14] = KIND_WINDOW_SCALE;
        buf[15] = LEN_WINDOW_SCALE;
        buf[16] = self.window_scale;

        buf[17] = if (self.selective_ack) KIND_SELECTIVE_ACK else KIND_NOOP;
        buf[18] = if (self.selective_ack) LEN_SELECTIVE_ACK else KIND_NOOP;

        buf[19] = if (self.selective_ack_permitted) KIND_SELECTIVE_ACK_PERMITTED else KIND_NOOP;
        buf[20] = if (self.selective_ack_permitted) LEN_SELECTIVE_ACK_PERMITTED else KIND_NOOP;

        buf[21] = KIND_END;

        return buf;
    }
};

test "options memory layout" {
    try std.testing.expectEqual(0, @bitOffsetOf(Options, "maximum_segment_size"));
    try std.testing.expectEqual(16, @bitOffsetOf(Options, "selective_ack"));
    try std.testing.expectEqual(17, @bitOffsetOf(Options, "selective_ack_permitted"));
    try std.testing.expectEqual(18, @bitOffsetOf(Options, "timestamp"));
    try std.testing.expectEqual(82, @bitOffsetOf(Options, "window_scale"));
}

test "options from bytes" {
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

    const actual = Options.fromBytes(bytes);

    try std.testing.expectEqual(expected_bytes_read, actual.bytes_read);
    try std.testing.expectEqual(expected_options, actual.options);
}

test "options to bytes" {
    const options = Options{
        .maximum_segment_size = 1460,
        .selective_ack = false,
        .selective_ack_permitted = true,
        .timestamp = 10808747317390213120,
        .window_scale = 7,
    };

    const expected_bytes: []const u8 = &.{
        0b00000010, 0b00000100, 0b00000101, 0b10110100,
        0b00001000, 0b00001010, 0b10010110, 0b00000000,
        0b01100010, 0b01101011, 0b00000000, 0b00000000,
        0b00000000, 0b00000000, 0b00000011, 0b00000011,
        0b00000111, 0b00000001, 0b00000001, 0b00000100,
        0b00000010, 0b00000000,
    };

    const actual_bytes = try options.toBytes(std.testing.allocator);
    defer std.testing.allocator.free(actual_bytes);

    try std.testing.expectEqualSlices(u8, expected_bytes, actual_bytes);
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

    pub fn process(
        self: State,
        tun: fs.File,
        ip_header: IpHeader,
        tcp_header: Header,
        data: []const u8,
    ) usize {
        _ = tun;
        _ = ip_header;
        _ = tcp_header;
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
