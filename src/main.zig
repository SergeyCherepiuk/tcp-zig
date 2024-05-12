const tun = @import("tun.zig");

pub fn main() !void {
    const tun_file = try tun.openTun("");
    _ = tun_file;

    while (true) {}
}
