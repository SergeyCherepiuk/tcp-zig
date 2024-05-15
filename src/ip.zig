// TODO: Make the struct packed when Zig resolves the issue with
// endianness and bit-order. Use @bitCast to create Ip4Header.
pub const Ip4Header = struct {
    version: u4,
    header_length: u4,
    type_of_service: u8,
    total_length: u16,
    id: u16,
    flags: u3,
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
            .total_length = intFromBytes(u16, bytes[2..4]),
            .id = intFromBytes(u16, bytes[4..6]),
            .flags = @intCast(bytes[6] >> 5),
            .fragment_offset = intFromBytes(u13, &[_]u8{ bytes[6] & 0x1F, bytes[7] }),
            .ttl = bytes[8],
            .protocol = bytes[9],
            .header_checksum = intFromBytes(u16, bytes[10..12]),
            .source_address = intFromBytes(u32, bytes[12..16]),
            .destination_address = intFromBytes(u32, bytes[16..20]),
        };
    }
};

fn intFromBytes(comptime T: type, slice: []const u8) T {
    var sum: T = 0;
    for (0.., slice) |i, el| {
        const slf = (slice.len - i - 1) * 8;
        sum += @as(T, el) << @intCast(slf);
    }
    return sum;
}
