const git = @import("git");
const std = @import("std");

var report = std.Thread.Mutex{};

pub const WorkChannel = struct {
    const Self = @This();

    buf: [32]git.oid,

    mutex: std.Thread.Mutex,
    need: std.Thread.Condition,
    filled: std.Thread.Condition,

    cur: usize,
    len: usize,
    fused: bool,

    pub fn init() Self {
        return Self{
            .buf = [_]git.oid{undefined} ** 32,
            .mutex = std.Thread.Mutex{},
            .need = std.Thread.Condition{},
            .filled = std.Thread.Condition{},
            .cur = 0,
            .len = 0,
            .fused = false,
        };
    }

    pub fn next(self: *Self) ?git.oid {
        self.mutex.lock();
        defer self.mutex.unlock();

        while (!self.fused and self.cur == self.len) {
            self.filled.wait(&self.mutex);
        }

        if (self.cur == self.len and self.fused) {
            std.log.debug("fused!", .{});
            return null;
        }

        std.log.debug("nexted ({} / {})", .{ self.cur, self.len });

        const oid = self.buf[self.cur];
        self.cur += 1;

        if (self.cur == self.len)
            self.need.signal();

        std.log.debug("found {}", .{oid});

        return oid;
    }

    pub fn fill(self: *Self, oids: []git.oid) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        std.log.debug("filling {}", .{oids.len});

        if (oids.len > 32) @panic("need a smaller fill");

        while (self.cur < self.len) {
            self.need.wait(&self.mutex);
        }

        @memcpy(self.buf[0..oids.len], oids);

        self.len = oids.len;
        self.cur = 0;

        self.filled.broadcast();
    }

    pub fn fuse(self: *Self) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        std.log.debug("fusing", .{});

        self.fused = true;
    }
};

pub const Worker = struct {
    const Self = @This();

    chan: *WorkChannel,

    pub fn init(chan: *WorkChannel) Self {
        return Self{ .chan = chan };
    }

    pub fn run(self: *Self) !bool {
        var oid = self.chan.next() orelse return false;

        {
            report.lock();
            defer report.unlock();
            var stdout = std.io.getStdOut();
            var out = stdout.writer();

            try out.print("{}\n", .{oid});
        }

        return true;
    }

    pub fn handler(worker: *Worker) void {
        while (worker.run() catch false) {}
    }
};
