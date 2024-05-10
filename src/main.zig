const tun = @import("tun.zig");

pub fn main() !void {
    const tun_file = try tun.openTun("tun0");
    _ = tun_file;

    while (true) {}
}
