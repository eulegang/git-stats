const std = @import("std");
const code = @import("code.zig");
const vm = @import("vm.zig");

const Inst = code.Inst;
const Op = code.Op;
const Entry = vm.Strtab.Entry;
const Prog = vm.Prog;

pub const Emitter = struct {
    code: std.ArrayList(u8),
    tab: std.ArrayList(u8),
    entries: std.ArrayList(Entry),
    global_count: usize,
    exports: std.ArrayList([]const u8),

    pub fn init(alloc: std.mem.Allocator) !Emitter {
        return Emitter{
            .code = std.ArrayList(u8).init(alloc),
            .tab = std.ArrayList(u8).init(alloc),
            .entries = std.ArrayList(Entry).init(alloc),
            .global_count = 0,
            .exports = std.ArrayList([]const u8).init(alloc),
        };
    }

    pub fn deinit(self: *Emitter) void {
        self.code.deinit();
        self.tab.deinit();
        self.entries.deinit();
        self.exports.deinit();
    }

    pub fn emit(self: *Emitter) Prog {
        return Prog{
            .code = self.code.items,
            .tab = vm.Strtab{
                .content = self.tab.items,
                .entries = self.entries.items,
            },
            .export_count = self.exports.items.len,
            .global_count = self.global_count,
        };
    }

    pub fn clear(self: *Emitter) !void {
        const inst = Inst{ .clear = Op.Clear{} };
        try self.push(inst);
    }

    pub fn append_const(self: *Emitter, str: []const u8) !void {
        const entry = self.entries.items.len;
        const start = self.tab.items.len;

        const inst = Inst{ .append = Op.Append{ .src = .constant, ._pad = 0, .constant = @truncate(u16, entry) } };

        try self.tab.appendSlice(str);
        try self.entries.append(Entry{
            .ptr = @truncate(u16, start),
            .len = @truncate(u16, str.len),
        });

        try self.push(inst);
    }

    pub fn append_export(self: *Emitter, id: u16) !void {
        try self.push(Inst{ .append = Op.Append{
            .src = .exports,
            ._pad = 0,
            .constant = id,
        } });
    }

    pub fn append_global(self: *Emitter, id: u16) !void {
        try self.push(Inst{ .append = Op.Append{
            .src = .globals,
            ._pad = 0,
            .constant = id,
        } });
    }

    pub fn reg(self: *Emitter, r: u8) !void {
        const inst = Inst{ .reg = Op.Reg{ .reg = r } };
        try self.push(inst);
    }

    pub fn add_export(self: *Emitter, name: []const u8) !u8 {
        const id = self.exports.items.len;
        try self.exports.append(name);
        return @truncate(u8, id);
    }

    pub fn set_export(self: *Emitter, id: u8) !void {
        const inst = Inst{ .set_export = Op.SetExport{ .id = id } };
        try self.push(inst);
    }

    pub fn get_export(self: *Emitter, id: u8) !void {
        const inst = Inst{ .get_export = Op.GetExport{ .id = id } };
        try self.push(inst);
    }

    pub fn push_scratch(self: *Emitter) !void {
        const inst = Inst{ .get_scratch = Op.GetScratch{} };
        try self.push(inst);
    }

    pub fn exit(self: *Emitter) !void {
        try self.push(Inst{ .exit = Op.Exit{} });
    }

    fn push(self: *Emitter, inst: Inst) !void {
        var buf = [_]u8{0} ** 8;
        const size = inst.imprint(&buf);

        try self.code.appendSlice(buf[0..size]);
    }
};
