const std = @import("std");

const MMap = @import("./mmap.zig").MMap;
pub const lang = @import("lang");
const git = @import("git");

const worker = @import("./worker.zig");

pub fn main() !void {
    var args = std.process.args();
    const stderr = std.io.getStdErr().writer();

    _ = args.next();
    var filename: [:0]const u8 = undefined;

    if (args.next()) |arg| {
        filename = arg;
    } else {
        try stderr.print("need a path to work with\n", .{});
        std.process.exit(1);
    }

    const content = try MMap.init(filename);
    defer content.deinit();

    var repo = try git.Repo.open();
    defer repo.deinit();

    var walk = try repo.walk_head();
    defer walk.deinit();

    const jobs = 4;
    var workers = [_]worker.Worker{undefined} ** jobs;
    var threads = [_]std.Thread{undefined} ** jobs;
    var work_chan = worker.WorkChannel.init();

    var i: usize = 0;
    while (i < jobs) : (i += 1) {
        workers[i] = worker.Worker.init(&work_chan);
        threads[i] = try std.Thread.spawn(.{}, worker.Worker.handler, .{&workers[i]});
    }

    while (true) {
        var oids = [_]git.oid{undefined} ** 32;
        i = 0;
        var need_to_fuse = false;

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
