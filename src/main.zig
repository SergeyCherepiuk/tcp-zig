const std = @import("std");
const process = std.process;
const args = @import("args.zig");
const tun = @import("tun.zig");

pub fn main() !void {
    var process_args = process.args();
    const device_name = try args.parseArgs(&process_args);
    const tun_file = try tun.openTun(device_name);

    const buf_size = 1504; // MTU + 4 bytes for headers
    var buf: [buf_size]u8 = undefined;
    while (true) {
        const bytes = try tun_file.read(&buf);
        const message = buf[0..bytes];
        std.debug.print("{any}\n", .{message});
    }
}
