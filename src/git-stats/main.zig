const std = @import("std");

const MMap = @import("./mmap.zig").MMap;
pub const lang = @import("lang");
const git = @import("git");

const worker = @import("./worker.zig");

var tmp_path = [_]u8{undefined} ** std.fs.MAX_PATH_BYTES;

const Args = struct {
    filename: []const u8,
    jobs: ?usize,
    postmordem: bool,
};

pub fn main() !void {
    //var args = std.process.args();
    //const stderr = std.io.getStdErr().writer();

    //_ = args.next();
    //var filename: [:0]const u8 = undefined;

    //if (args.next()) |arg| {
    //    filename = arg;
    //} else {
    //    try stderr.print("need a path to work with\n", .{});
    //    std.process.exit(1);
    //}
    var args = Args{
        .filename = "example",
        .jobs = 4,
        .postmordem = true,
    };

    if (args.jobs orelse 0 > 32) {
        try std.io.getStdErr().writer().print("what are you doing?\n", .{});
        std.process.exit(1);
    }

    const content = try MMap.init(args.filename);
    defer content.deinit();

    var repo = try git.Repo.open();
    defer repo.deinit();

    var walk = try repo.walk_head();
    defer walk.deinit();

    const jobs = args.jobs orelse try std.Thread.getCpuCount();
    var workers = [_]worker.Worker{undefined} ** 32;
    var threads = [_]std.Thread{undefined} ** 32;
    var work_chan = worker.WorkChannel.init();

    const pid = std.os.linux.getpid();

    const path = try std.fmt.bufPrint(&tmp_path, "/tmp/git-stats-{}/", .{pid});

    try std.fs.makeDirAbsolute(path);
    var dir = try std.fs.openDirAbsolute(path, .{});
    defer dir.close();

    try dir.makeDir("repos");

    defer if (!args.postmordem)
        std.fs.deleteTreeAbsolute(path) catch {};

    var i: usize = 0;
    var name_buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    while (i < jobs) : (i += 1) {
        var p = try std.fmt.bufPrint(&name_buf, "/tmp/git-stats-{}/repos/{}", .{ pid, i });

        const r = try repo.local_copy(p);

        workers[i] = worker.Worker.init(&work_chan, r);
        threads[i] = try std.Thread.spawn(.{}, worker.Worker.handler, .{&workers[i]});
    }

    while (true) {
        var oids = [_]git.oid{undefined} ** 32;
        var need_to_fuse = false;
        i = 0;

        while (i < 32) : (i += 1) {
            oids[i] = walk.next() orelse {
                need_to_fuse = true;
                break;
            };
        }

        work_chan.fill(oids[0..i]);

        if (need_to_fuse) {
            work_chan.fuse();
            break;
        }
    }

    i = 0;
    while (i < jobs) : (i += 1) {
        threads[i].join();
    }
}
