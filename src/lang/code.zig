const std = @import("std");
const native_endian = @import("builtin").target.cpu.arch.endian();

pub const Op = enum {
    pub const Clear = OpClear;
    pub const Append = OpAppend;
    pub const Reg = OpReg;
    pub const Exit = OpExit;

    clear,
    append,
    reg,
    exit,

    fn top() u8 {
        comptime var res = 0;

        comptime {
            var ty = @typeInfo(@This());
            var t = 0;

            for (ty.Enum.fields) |field| {
                if (t < field.value) {
                    t = field.value;
                }
            }

            res = t;
        }

        return res;
    }
};

pub const Inst = union(Op) {
    pub const Error = error{InvalidInst};
    const Self = @This();

    clear: Op.Clear,
    append: Op.Append,
    reg: Op.Reg,
    exit: Op.Exit,

    pub fn from(buf: []const u8) !Inst {
        if (buf.len < 1)
            return Error.InvalidInst;

        var byte = buf[0];
        if (byte > Op.top())
            return Error.InvalidInst;

        var op = @intToEnum(Op, buf[0]);

        switch (op) {
            .clear => return Inst{ .clear = try OpClear.from(buf[1..]) },
            .append => return Inst{ .append = try OpAppend.from(buf[1..]) },
            .reg => return Inst{ .reg = try OpReg.from(buf[1..]) },
            .exit => return Inst{ .exit = try OpExit.from(buf[1..]) },
        }
    }

    pub fn size(self: Self) usize {
        switch (self) {
            .clear => return 1 + @sizeOf(OpClear),
            .append => return 1 + @sizeOf(OpAppend),
            .reg => return 1 + @sizeOf(OpReg),
            .exit => return 1 + @sizeOf(OpExit),
        }
    }

    pub fn imprint(self: Self, buf: []u8) usize {
        buf[0] = @enumToInt(self);

        switch (self) {
            .clear => return 1 + @sizeOf(OpClear),
            .exit => return 1 + @sizeOf(OpExit),
            .append => |a| {
                a.imprint(buf[1..]);
                return 1 + @sizeOf(OpAppend);
            },
            .reg => |r| {
                r.imprint(buf[1..]);
                return 1 + @sizeOf(OpReg);
            },
        }
    }
};

/// Clears the scratch space
const OpClear = struct {
    fn from(_: []const u8) !OpClear {
        return OpClear{};
    }
};

/// Append a constant to the scratch space
const OpAppend = struct {
    constant: u16,

    fn from(buf: []const u8) !OpAppend {
        if (buf.len < @sizeOf(@This()))
            return Inst.Error.InvalidInst;

        var constant = convertU16([2]u8{ buf[0], buf[1] });

        return OpAppend{
            .constant = constant,
        };
    }

    fn imprint(self: OpAppend, buf: []u8) void {
        pushU16(self.constant, buf);
    }
};

/// Put scratch space into a register
const OpReg = struct {
    reg: u8,

    fn from(buf: []const u8) !OpReg {
        if (buf.len < @sizeOf(@This()))
            return Inst.Error.InvalidInst;

        return OpReg{
            .reg = buf[0],
        };
    }

    fn imprint(self: OpReg, buf: []u8) void {
        buf[0] = self.reg;
    }
};

const OpExit = struct {
    fn from(_: []const u8) !OpExit {
        return OpExit{};
    }
};

fn convertU16(arr: [2]u8) u16 {
    var constant = @bitCast(u16, arr);
    if (native_endian == .Big)
        @byteSwap(constant);

    return constant;
}

fn pushU16(num: u16, buf: []u8) void {
    if (native_endian == .Big)
        @byteSwap(num);
    var arr = @bitCast([2]u8, num);

    buf[0] = arr[0];
    buf[1] = arr[1];
}
