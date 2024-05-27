const std = @import("std");
const fs = std.fs;
const linux = std.os.linux;

const c = @cImport({
    @cInclude("linux/if.h");
    @cInclude("linux/if_tun.h");
    @cInclude("linux/errno.h");
});

const TUNSETIFF = linux.IOCTL.IOW('T', 202, i32);

const OpenTunError = error{ NoTunDevice, TunDeviceBusy, PermissionDenied, DeviceNameTaken };

pub fn openTun(device_name: []const u8) OpenTunError!fs.File {
    const tun_file_union = fs.openFileAbsolute("/dev/net/tun", .{ .mode = .read_write });

    const tun_file = tun_file_union catch |err| switch (err) {
        fs.File.OpenError.NoDevice => return error.NoTunDevice,
        fs.File.OpenError.DeviceBusy => return error.TunDeviceBusy,
        else => unreachable,
    };

    const ifr = linux.ifreq{
        .ifrn = .{ .name = stringToFixedArray(device_name, c.IFNAMSIZ) },
        .ifru = .{ .flags = c.IFF_TUN },
    };

    const ioctl_code = linux.ioctl(tun_file.handle, TUNSETIFF, @intFromPtr(&ifr));
    if (ioctl_code != 0) {
        try ioctlError(ioctl_code);
    }

    return tun_file;
}

fn stringToFixedArray(string: []const u8, comptime size: usize) [size]u8 {
    var buf: [size]u8 = [_]u8{0} ** size;
    std.mem.copyForwards(u8, &buf, string);
    return buf;
}

fn ioctlError(code: usize) OpenTunError!void {
    const errno: c_int = @intCast(std.math.maxInt(u64) - code + 1);
    return switch (errno) {
        c.EPERM => error.PermissionDenied,
        c.EBUSY => error.DeviceNameTaken,
        else => {},
    };
}
