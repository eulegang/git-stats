const std = @import("std");

pub const MMap = struct {
    pub const Error = std.os.MMapError || std.os.FStatError || error{NotFile};

    content: []align(4096) const u8,

    pub fn init(filename: []const u8) !MMap {
        const handle = try std.os.open(filename, std.os.linux.O.RDONLY, 0o777);
        defer std.os.close(handle);

        const stat = try std.os.fstat(handle);

        if (!std.os.linux.S.ISREG(stat.mode)) {
            return Error.NotFile;
        }

        const size = @bitCast(usize, stat.size);
        const content = try std.os.mmap(null, size, std.os.linux.PROT.READ, std.os.linux.MAP.PRIVATE, handle, 0);

        return MMap{ .content = content };
    }

    pub fn deinit(self: *const @This()) void {
        std.os.munmap(self.content);
    }

    pub fn string(self: *const @This()) []const u8 {
        return self.content;
    }
};
