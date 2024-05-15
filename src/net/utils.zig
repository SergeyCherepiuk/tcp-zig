pub fn intFromBytes(comptime T: type, slice: []const u8) T {
    var sum: T = 0;
    for (0.., slice) |i, el| {
        const slf = (slice.len - i - 1) * 8;
        sum += @as(T, el) << @intCast(slf);
    }
    return sum;
}
