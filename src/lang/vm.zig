const std = @import("std");
const code = @import("code.zig");

pub const Prog = struct {
    const Self = @This();

    code: []const u8,
    tab: Strtab,
    export_count: usize,
    global_count: usize,

    pub fn disassemble(self: *Self, writer: anytype) !void {
        var addr: usize = 0;

        while (addr < self.code.len) {
            var inst = try code.Inst.from(self.code[addr..]);

            switch (inst) {
                .clear => {
                    try writer.print("{X:0>4} clear\n", .{addr});
                },

                .append => |append| {
                    const content = self.tab.entry(append.constant);

                    try writer.print("{X:0>4} append \"{s}\"\n", .{ addr, content });
                },

                .exit => {
                    try writer.print("{X:0>4} exit\n", .{addr});
                },

                .set_export => |op| {
                    try writer.print("{X:0>4} set_export {}\n", .{ addr, op.id });
                },
                .get_export => |op| {
                    try writer.print("{X:0>4} get_export {}\n", .{ addr, op.id });
                },

                .set_global => |op| {
                    try writer.print("{X:0>4} set_export {}\n", .{ addr, op.id });
                },

                .get_global => |op| {
                    try writer.print("{X:0>4} get_export {}\n", .{ addr, op.id });
                },

                .get_scratch => {
                    try writer.print("{X:0>4} get_scratch\n", .{addr});
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
    pub const Error = error{
        EndOfInst,
        StackLimit,
        StackUnderflow,
    };

    const STACK_LIMIT = 1028;

    ip: usize,
    scratch: *Scratch,
    alloc: std.mem.Allocator,

    sp: usize,
    stack: [STACK_LIMIT]Atom,
    exports: []Atom,
    globals: []Atom,

    pub fn init(alloc: std.mem.Allocator) !Vm {
        var scratch = try alloc.create(Scratch);

        scratch.len = 0;
        scratch.next = null;
        const exports = try alloc.alloc(Atom, 0);
        const globals = try alloc.alloc(Atom, 0);

        return Vm{
            .ip = 0,
            .scratch = scratch,
            .alloc = alloc,
            .sp = 0,
            .stack = [_]Atom{undefined} ** 1028,
            .exports = exports,
            .globals = globals,
        };
    }

    pub fn deinit(self: *Vm) void {
        self.alloc.destroy(self.scratch);

        for (self.exports) |i| {
            self.alloc.free(i.buf);
        }

        self.alloc.free(self.exports);

        for (self.globals) |i| {
            self.alloc.free(i.buf);
        }

        self.alloc.free(self.globals);
    }

    pub fn fetch(self: *Vm, id: u8) ?[]const u8 {
        if (id >= self.exports.len) {
            return null;
        }

        return self.exports[id].buf;
    }

    pub fn run(self: *Vm, prog: *const Prog) !void {
        // not so great need to figure this out better
        self.alloc.free(self.exports);
        self.alloc.free(self.globals);
        self.exports = try self.alloc.alloc(Atom, prog.export_count);

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
                .set_export => |op| {
                    if (self.sp == 0) {
                        return Error.StackUnderflow;
                    }

                    self.sp -= 1;
                    self.exports[op.id] = self.stack[self.sp];
                },
                .get_export => |op| {
                    if (self.sp >= STACK_LIMIT) {
                        return Error.StackLimit;
                    }

                    self.stack[self.sp] = self.exports[op.id];
                    self.sp += 1;
                },

                .set_global => |op| {
                    if (self.sp == 0) {
                        return Error.StackUnderflow;
                    }

                    self.sp -= 1;
                    self.globals[op.id] = self.stack[self.sp];
                },

                .get_global => |op| {
                    if (self.sp >= STACK_LIMIT) {
                        return Error.StackLimit;
                    }

                    self.stack[self.sp] = self.globals[op.id];
                    self.sp += 1;
                },
                .get_scratch => {
                    const len = self.scratch.total();
                    const buf = try self.alloc.alloc(u8, len);
                    self.scratch.copy_to(buf);

                    const atom = Atom{ .stowed = false, .alloc = self.alloc, .buf = buf };
                    self.stack[self.sp] = atom;
                    self.sp += 1;
                },

                .exit => return,

                //else => unreachable,
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

    fn total(self: *Scratch) usize {
        var len: usize = 0;
        var cur: ?*Scratch = self;
        while (cur) |c| {
            len += c.len;
            cur = c.next;
        }

        return len;
    }

    fn copy_to(self: *Scratch, buf: []u8) void {
        var i: usize = 0;
        var s: ?*Scratch = self;
        while (s) |cur| {
            @memcpy(buf[i..cur.len], cur.buf[0..cur.len]);

            i += cur.len;
            s = cur.next;
        }
    }
};

pub const Atom = struct {
    stowed: bool,
    alloc: std.mem.Allocator,
    buf: []u8,
};

//pub const Atom = union(enum) {
//    bare: BareAtom,
//    stored: StoreAtom,
//};
//
//const BareAtom = struct {
//    alloc: std.mem.Allocator,
//    buf: []u8,
//};
//
//const StoreAtom = struct {};
