const std = @import("std");
const git2 = @import("git2.zig");
const oid = @import("ref.zig").oid;

pub const Walk = struct {
    const Self = @This();

    walk: *git2.git_revwalk,

    pub fn init(repo: *git2.git_repository) Self {
        var walk: ?*git2.git_revwalk = null;
        _ = git2.git_revwalk_new(&walk, repo);

        return Self{
            .walk = walk orelse unreachable,
        };
    }

    pub fn deinit(self: *const Self) void {
        git2.git_revwalk_free(self.walk);
    }

    pub fn push_head(self: *Self) void {
        _ = git2.git_revwalk_push_head(self.walk);
    }

    pub fn reset(self: *Self) void {
        _ = git2.git_revwalk_reset(self.walk);
    }

    pub fn next(self: *Self) ?oid {
        var g_oid: git2.git_oid = undefined;
        if (git2.git_revwalk_next(&g_oid, self.walk) == git2.GIT_ITEROVER) {
            return null;
        } else {
            return oid{ .id = g_oid };
        }
    }
};
