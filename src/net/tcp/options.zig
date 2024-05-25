const std = @import("std");
const mem = std.mem;

const utils = @import("../utils.zig");

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
