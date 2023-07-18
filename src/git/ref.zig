const std = @import("std");
const git2 = @import("git2.zig");

pub const Ref = struct {
    const Self = @This();

    ref: *git2.git_reference,

    pub fn init(ref: *git2.git_reference) Self {
        return Ref{ .ref = ref };
    }

    pub fn deinit(self: *const Self) void {
        git2.git_reference_free(self.ref);
    }

    pub fn format(
        self: *const Self,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        const g_oid = git2.git_reference_target(self.ref);
        try writer.print("{}", .{oid{ .id = g_oid.* }});
    }
};

pub const oid = struct {
    id: git2.git_oid,

    pub fn format(
        self: *const oid,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        var buf = [_]u8{0} ** 40;
        _ = git2.git_oid_fmt(&buf, &self.id);

        try writer.print("{s}", .{buf});
    }
};
