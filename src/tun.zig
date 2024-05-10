const std = @import("std");
const fs = std.fs;
const linux = std.os.linux;
const utils = @import("utils.zig");

const TUNSETIFF = linux.IOCTL.IOW('T', 202, i32);
const IFF_TUN = 0x0001;

// TODO: Read errno for better error handling
const OpenTunError = fs.File.OpenError || error{Error};

pub fn openTun(device_name: []const u8) OpenTunError!fs.File {
    const tun_file = try fs.openFileAbsolute("/dev/net/tun", .{ .mode = .read_write });

    const ifr = linux.ifreq{
        .ifrn = .{ .name = utils.stringToFixedArray(device_name, 16) },
        .ifru = .{ .flags = IFF_TUN },
    };

    const ioctl_code = linux.ioctl(tun_file.handle, TUNSETIFF, @intFromPtr(&ifr));
    if (ioctl_code == -1) {
        return error.Error;
    }

    return tun_file;
}
