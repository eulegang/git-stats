const git2 = @import("git2.zig");

pub const GitBuf = struct {
    const Self = @This();
    buf: git2.git_buf,

    pub fn init() Self {
        return Self{
            .buf = git2.git_buf{
                .ptr = null,
                .reserved = 0,
                .size = 0,
            },
        };
    }

    pub fn slice(self: *const Self) []const u8 {
        return self.buf.ptr[0..self.buf.size];
    }

    pub fn cstr(self: *const Self) [*:0]const u8 {
        return self.buf.ptr;
    }

    pub fn deinit(self: *Self) void {
        git2.git_buf_dispose(&self.buf);
    }
};
