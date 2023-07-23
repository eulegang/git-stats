const std = @import("std");
const code = @import("code.zig");

pub const Prog = struct {
    const Self = @This();

    code: []const u8,
    tab: Strtab,

    pub fn disassemble(self: *Self, writer: anytype) !void {
        var addr: usize = 0;

        while (addr < self.code.len) {
            var inst = try code.Inst.from(self.code[addr..]);

            switch (inst) {
                .clear => {
                    try writer.print("{X:0>4} clear\n", .{addr});
                },
                .reg => |reg| {
                    try writer.print("{X:0>4} reg {}\n", .{ addr, reg.reg });
                },

                .append => |append| {
                    const content = self.tab.entry(append.constant);

                    try writer.print("{X:0>4} append \"{s}\"\n", .{ addr, content });
                },

                .exit => {
                    try writer.print("{X:0>4} exit\n", .{addr});
                },
            }

            addr += inst.size();
        }
    }
};

pub const Strtab = struct {
    pub const Entry = struct {
        ptr: u16,
        len: u16,
    };

    content: []const u8,
    entries: []const Entry,

    fn entry(self: Strtab, index: u16) []const u8 {
        const e = self.entries[index];
        return self.content[e.ptr .. e.ptr + e.len];
    }
};

pub const Reg = packed struct {
    len: u12,
    present: bool,
    persisted: bool,
};

pub const Vm = struct {
    pub const Error = error{EndOfInst};
    ip: usize,
    regs: [16]Reg,
    regm: *[65536]u8,
    scratch: *Scratch,
    alloc: std.mem.Allocator,

    pub fn init(alloc: std.mem.Allocator) !Vm {
        var regm = try alloc.create([65536]u8);
        var scratch = try alloc.create(Scratch);

        scratch.len = 0;
        scratch.next = null;

        return Vm{
            .ip = 0,
            .regs = [_]Reg{Reg{ .len = 0, .present = false, .persisted = false }} ** 16,
            .regm = regm,
            .scratch = scratch,
            .alloc = alloc,
        };
    }

    pub fn deinit(self: *Vm) void {
        self.alloc.destroy(self.regm);
        self.alloc.destroy(self.scratch);
    }

    pub fn fetch(self: *Vm, id: u8) ?[]const u8 {
        if (!self.regs[id].present)
            return null;

        const start = 4096 * @as(u16, id);
        const end = 4096 * @as(u16, id) + self.regs[id].len;
        return self.regm[start..end];
    }

    pub fn run(self: *Vm, prog: *const Prog) !void {
        var inst: code.Inst = undefined;
        while (self.ip < prog.code.len) {
            inst = try code.Inst.from(prog.code[self.ip..]);

            switch (inst) {
                .clear => {
                    if (self.scratch.next) |next| {
                        next.free(self.alloc);
                    }

                    self.scratch.len = 0;
                },
                .append => |op| {
                    var content = prog.tab.entry(op.constant);
                    try self.scratch.push(content, self.alloc);
                },
                .reg => |op| {
                    if (self.scratch.next) |_| {
                        // do something if scratch has a next
                        // it will not fit into a reg
                        unreachable;
                    } else {
                        const start = 4096 * @as(u16, op.reg);
                        const end = start + self.scratch.len;
                        @memcpy(self.regm[start..end], self.scratch.buf[0..self.scratch.len]);

                        self.regs[op.reg].len = @truncate(u12, self.scratch.len);
                        self.regs[op.reg].present = true;
                    }
                },
                .exit => return,
            }

            self.ip += inst.size();
        }

        return Error.EndOfInst;
    }
};

pub const Scratch = struct {
    next: ?*Scratch,
    len: usize,
    buf: [4096]u8,

    fn free(self: *Scratch, alloc: std.mem.Allocator) void {
        if (self.next) |next| {
            next.free(alloc);
        }

        alloc.destroy(self);
    }

    fn push(self: *Scratch, content: []const u8, alloc: std.mem.Allocator) !void {
        if (self.len + content.len < 4096) {
            @memcpy(self.buf[self.len .. self.len + content.len], content);
            self.len += content.len;
        } else {
            _ = alloc;
            unreachable;
        }
    }
};
