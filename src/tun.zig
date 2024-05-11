const std = @import("std");
const fs = std.fs;
const linux = std.os.linux;
const utils = @import("utils.zig");
const c = @cImport({
    @cInclude("linux/if.h");
    @cInclude("linux/if_tun.h");
    @cInclude("linux/errno.h");
});

const TUNSETIFF = linux.IOCTL.IOW('T', 202, i32);

const IoctlError = error{
    UnknownError,
    BadFileDescriptor,
    InaccessibleMemory,
    InvalidRequest,
    NoCharacterDevice,
};

const OpenTunError = fs.File.OpenError || IoctlError;

pub fn openTun(device_name: []const u8) OpenTunError!fs.File {
    const tun_file = try fs.openFileAbsolute("/dev/net/tun", .{ .mode = .read_write });

    const ifr = linux.ifreq{
        .ifrn = .{ .name = utils.stringToFixedArray(device_name, c.IFNAMSIZ) },
        .ifru = .{ .flags = c.IFF_TUN | c.IFF_NO_PI },
    };

    const ioctl_code = linux.ioctl(tun_file.handle, TUNSETIFF, @intFromPtr(&ifr));
    if (ioctl_code != 0) {
        return mapReturnCode(ioctl_code);
    }

    return tun_file;
}

fn mapReturnCode(code: u64) IoctlError {
    const errno: c_int = @intCast(std.math.maxInt(u64) - code + 1);
    return switch (errno) {
        c.EBADF => error.BadFileDescriptor,
        c.EFAULT => error.InaccessibleMemory,
        c.EINVAL => error.InvalidRequest,
        c.ENOTTY => error.NoCharacterDevice,
        else => error.UnknownError,
    };
}
