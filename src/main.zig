const std = @import("std");
const process = std.process;
const mem = std.mem;
const args = @import("args.zig");
const tun = @import("tun.zig");
const ip = @import("ip.zig");
const tcp = @import("tcp.zig");

pub fn main() !void {
    var process_args = process.args();
    const device_name = try args.parseArgs(&process_args);
    const tun_file = try tun.openTun(device_name);

    const buf_size = 1504; // Default MTU + 4 bytes for headers (flags and protocol)
    var buf: [buf_size]u8 = undefined;
    while (true) {
        const bytes = try tun_file.read(&buf);
        const message = buf[0..bytes];

        const ethernet_protocol = (@as(u16, message[2]) << 8) + message[3];
        if (ethernet_protocol != 0x0800) {
            continue;
        }

        const ip_header = ip.Ip4Header.new(message[4..24]);
        std.debug.print("{any}\n", .{ip_header});
    }
}
