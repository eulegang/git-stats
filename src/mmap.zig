const std = @import("std");

const linux = std.os.linux;

const Error = std.os.MMapError || std.os.FStatError || error{NotFile};

pub const MMap = struct {
    content: []align(4096) const u8,

    pub fn init(filename: []const u8) !MMap {
        const handle = try std.os.open(filename, std.os.linux.O.RDONLY, 0o777);
        defer std.os.close(handle);

        const stat = try std.os.fstat(handle);

        if (!linux.S.ISREG(stat.mode)) {
            return Error.NotFile;
        }

        const size = @bitCast(usize, stat.size);
        const content = try std.os.mmap(null, size, linux.PROT.READ, linux.MAP.PRIVATE, handle, 0);

        return MMap{ .content = content };
    }

    pub fn deinit(self: *const @This()) void {
        std.os.munmap(self.content);
    }

    pub fn string(self: *const @This()) []const u8 {
        return self.content;
    }
};
