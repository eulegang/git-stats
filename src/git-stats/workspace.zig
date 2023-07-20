pub const std = @import("std");
pub const Repo = @import("git").Repo;

pub const Workspace = struct {
    const Self = @This();

    alloc: std.mem.Allocator,
    cleanup: bool,
    workspace: std.fs.Dir,
    path: []u8,

    pub fn init(alloc: std.mem.Allocator, cleanup: bool) !Self {
        var env = try std.process.getEnvMap(alloc);

        var path: []u8 = undefined;

        var root = try std.fs.openDirAbsolute("/", .{});
        const pid = std.os.linux.getpid();
        if (env.get("HOME")) |home| {
            path = try std.fmt.allocPrint(alloc, "{s}/.cache/git-stats/{}", .{ home, pid });
        } else {
            path = try std.fmt.allocPrint(alloc, "/tmp/git-stats-{}/", .{pid});
        }

        std.log.debug("workspace {s}", .{path});
        const workspace = try std.fs.Dir.makeOpenPath(root, path, .{});

        try workspace.makeDir("repos");

        return Self{
            .alloc = alloc,
            .workspace = workspace,
            .cleanup = cleanup,
            .path = path,
        };
    }

    pub fn copy_repo(self: *Self, repo: Repo, i: usize) !Repo {
        var path = try std.fmt.allocPrint(self.alloc, "{}\x00", .{i});
        defer self.alloc.free(path);

        return try repo.local_copy(path);
    }

    pub fn chdir(self: *Self, path: []const u8) !void {
        var buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
        var repos = try std.fmt.bufPrint(&buf, "{s}/{s}", .{ self.path, path });
        try std.os.chdir(repos);
    }

    pub fn reset_dir(self: *Self) !void {
        try std.os.chdir(self.path);
    }

    pub fn deinit(self: *Self) void {
        self.workspace.close();
        if (self.cleanup) {
            std.log.debug("cleaning up \"{s}\"", .{self.path});
            std.fs.deleteTreeAbsolute(self.path) catch {};
        }

        self.alloc.free(self.path);
    }
};
