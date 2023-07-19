const std = @import("std");
const GitBuf = @import("buf.zig").GitBuf;
const ref = @import("ref.zig");
pub const Ref = ref.Ref;
pub const oid = ref.oid;
pub const Walk = @import("walk.zig").Walk;

const git2 = @import("git2.zig");

pub const Error = error{
    git_error,
};

pub const Repo = struct {
    const Self = @This();

    path: []const u8,
    repo: *git2.git_repository,

    pub fn open() !Self {
        _ = git2.git_libgit2_init();

        var path = try discover();
        defer path.deinit();

        var repo: ?*git2.git_repository = null;
        var succ = git2.git_repository_open(&repo, path.cstr());

        if (succ != 0) {
            std.log.err("failed to open git repository", .{});
            return Error.git_error;
        }

        return Self{
            .path = try path.copy(std.heap.c_allocator),
            .repo = repo orelse return Error.git_error,
        };
    }

    pub fn deinit(self: *Self) void {
        std.heap.c_allocator.free(self.path);
        git2.git_repository_free(self.repo);
        _ = git2.git_libgit2_shutdown();
    }

    pub fn head(self: *Self) !Ref {
        var r: ?*git2.git_reference = null;
        var succ = git2.git_repository_head(&r, self.repo);

        if (succ != 0) {
            std.log.err("failed to find head", .{});
            return Error.git_error;
        }

        const gref = Ref.init(r orelse unreachable);
        std.log.debug("head {}", .{gref});

        return gref;
    }

    pub fn walk_head(self: *const Self) !Walk {
        var walk = Walk.init(self.repo);
        walk.push_head();

        return walk;
    }

    pub fn local_copy(self: *const Self, path: []const u8) !Repo {
        // should call to keep symetic init/shutdown calls
        _ = git2.git_libgit2_init();

        var buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
        var repo: ?*git2.git_repository = null;

        var url = std.fmt.bufPrint(&buf, "file:///{s}\x00", .{self.path}) catch unreachable;

        var opts: git2.git_clone_options = undefined;
        _ = git2.git_clone_options_init(&opts, git2.GIT_CLONE_OPTIONS_VERSION);

        _ = git2.git_clone(&repo, url.ptr, path.ptr, &opts);

        return Repo{
            .repo = repo orelse return Error.git_error,
            .path = path,
        };
    }
};

fn discover() !GitBuf {
    var path_buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    var path: []const u8 = try std.fs.realpath(".", &path_buf);
    path_buf[path.len] = 0;

    var buf = GitBuf.init();
    var succ = git2.git_repository_discover(&buf.buf, @ptrCast([*:0]const u8, path), 1, null);
    errdefer buf.deinit();

    if (succ != 0) {
        std.log.err("failed to discover repository", .{});
        return Error.git_error;
    }

    std.log.debug("discovered repository at \"{s}\"", .{buf.slice()});

    return buf;
}
