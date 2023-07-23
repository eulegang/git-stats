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
            .clear => return Inst{ .clear = try parse_op(OpClear, buf[1..]) },
            .append => return Inst{ .append = try parse_op(OpAppend, buf[1..]) },
            .reg => return Inst{ .reg = try parse_op(OpReg, buf[1..]) },
            .exit => return Inst{ .exit = try parse_op(OpExit, buf[1..]) },
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
            .clear => |op| {
                imprint_op(op, buf[1..]);
                return 1 + @sizeOf(OpClear);
            },

            .exit => |op| {
                imprint_op(op, buf[1..]);
                return 1 + @sizeOf(OpExit);
            },

            .append => |op| {
                imprint_op(op, buf[1..]);
                return 1 + @sizeOf(OpAppend);
            },

            .reg => |op| {
                imprint_op(op, buf[1..]);
                return 1 + @sizeOf(OpReg);
            },
        }
    }
};

/// Clears the scratch space
const OpClear = packed struct {};

/// Append a constant to the scratch space
const OpAppend = packed struct {
    constant: u16,
};

/// Put scratch space into a register
const OpReg = packed struct {
    reg: u8,
};

const OpExit = packed struct {};

fn imprint_op(op: anytype, buf: []u8) void {
    comptime var ty = @typeInfo(@TypeOf(op));
    comptime var i = 0;

    inline for (ty.Struct.fields) |field| {
        comptime var field_ty = @typeInfo(field.type);

        switch (field_ty.Int.bits) {
            8 => {
                buf[i] = @field(op, field.name);
                i += 1;
            },

            16 => {
                var k = @field(op, field.name);
                if (native_endian == .Big)
                    @byteSwap(k);

                var tmp = @bitCast([2]u8, k);

                buf[i] = tmp[0];
                i += 1;
                buf[i] = tmp[1];
                i += 1;
            },

            else => @compileError("unhandled bit field"),
        }
    }
}

fn parse_op(comptime T: type, buf: []const u8) !T {
    if (buf.len < @sizeOf(T)) {
        return Inst.Error.InvalidInst;
    }

    comptime var ty = @typeInfo(T);
    comptime var i = 0;

    var res: [@sizeOf(T)]u8 = undefined;

    inline for (ty.Struct.fields) |field| {
        comptime var field_ty = @typeInfo(field.type);

        switch (field_ty.Int.bits) {
            8 => {
                res[i] = buf[i];
                i += 1;
            },

            16 => {
                if (native_endian == .Big) {
                    res[i] = buf[i + 1];
                    res[i + 1] = buf[i];
                } else {
                    res[i] = buf[i];
                    res[i + 1] = buf[i + 1];
                }
                i += 2;
            },

            else => @compileError("unhandled bit field"),
        }
    }

    return @bitCast(T, res);
}
