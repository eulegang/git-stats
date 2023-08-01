const std = @import("std");
const native_endian = @import("builtin").target.cpu.arch.endian();

pub const Op = enum {
    pub const Clear = OpClear;
    pub const Append = OpAppend;
    pub const Exit = OpExit;

    pub const SetExport = OpSetExport;
    pub const GetExport = OpGetExport;

    pub const SetGlobal = OpSetGlobal;
    pub const GetGlobal = OpGetGlobal;

    pub const GetScratch = OpGetScratch;

    clear,
    append,
    exit,
    set_export,
    get_export,
    set_global,
    get_global,
    get_scratch,

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

const SContext = enum(u8) {
    constant = 0,
    globals = 1,
    exports = 2,
    scratch = 3,
};

pub const Inst = union(Op) {
    pub const Error = error{InvalidInst};
    const Self = @This();

    clear: Op.Clear,
    append: Op.Append,
    exit: Op.Exit,
    set_export: Op.SetExport,
    get_export: Op.GetExport,
    set_global: Op.SetGlobal,
    get_global: Op.GetGlobal,
    get_scratch: Op.GetScratch,

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
            .exit => return Inst{ .exit = try parse_op(OpExit, buf[1..]) },
            .set_export => return Inst{ .set_export = try parse_op(OpSetExport, buf[1..]) },
            .get_export => return Inst{ .get_export = try parse_op(OpGetExport, buf[1..]) },
            .set_global => return Inst{ .set_global = try parse_op(OpSetGlobal, buf[1..]) },
            .get_global => return Inst{ .get_global = try parse_op(OpGetGlobal, buf[1..]) },
            .get_scratch => return Inst{ .get_scratch = try parse_op(OpGetScratch, buf[1..]) },
        }
    }

    pub fn size(self: Self) usize {
        switch (self) {
            .clear => return 1 + @sizeOf(OpClear),
            .append => return 1 + @sizeOf(OpAppend),
            .exit => return 1 + @sizeOf(OpExit),
            .set_export => return 1 + @sizeOf(OpSetExport),
            .get_export => return 1 + @sizeOf(OpGetExport),
            .set_global => return 1 + @sizeOf(OpSetExport),
            .get_global => return 1 + @sizeOf(OpGetExport),
            .get_scratch => return 1 + @sizeOf(OpGetScratch),
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

            .set_export => |op| {
                imprint_op(op, buf[1..]);
                return 1 + @sizeOf(OpSetExport);
            },

            .get_export => |op| {
                imprint_op(op, buf[1..]);
                return 1 + @sizeOf(OpGetExport);
            },

            .set_global => |op| {
                imprint_op(op, buf[1..]);
                return 1 + @sizeOf(OpSetGlobal);
            },

            .get_global => |op| {
                imprint_op(op, buf[1..]);
                return 1 + @sizeOf(OpGetGlobal);
            },

            .get_scratch => |op| {
                imprint_op(op, buf[1..]);
                return 1 + @sizeOf(OpGetScratch);
            },
        }
    }
};

/// Clears the scratch space
const OpClear = packed struct {};

/// Append a constant to the scratch space
const OpAppend = packed struct {
    src: SContext,
    _pad: u8,
    constant: u16,
};

const OpExit = packed struct {};

const OpSetExport = packed struct {
    id: u8,
};

const OpGetExport = packed struct {
    id: u8,
};

const OpSetGlobal = packed struct {
    id: u16,
};

const OpGetGlobal = packed struct {
    id: u16,
};

const OpGetScratch = packed struct {};

const OpPush = packed struct {
    id: u16,

    pub fn is_export(self: OpPush) bool {
        return 0xc000 & self.id == 0x4000;
    }

    pub fn is_global(self: OpPush) bool {
        return 0xc000 & self.id == 0x8000;
    }

    pub fn is_scratch(self: OpPush) bool {
        return 0xc000 & self.id == 0xc000;
    }

    pub fn addr(self: OpPush) u16 {
        return 0x3FFF & self.id;
    }
};

fn imprint_op(op: anytype, buf: []u8) void {
    comptime var ty = @typeInfo(@TypeOf(op));
    comptime var i = 0;

    inline for (ty.Struct.fields) |field| {
        comptime var field_ty = @typeInfo(field.type);
        comptime var bytes: comptime_int = 0;

        switch (field_ty) {
            .Int => |int| {
                switch (int.bits) {
                    8 => bytes = 1,
                    16 => bytes = 2,
                    else => @compileError("type not supported `" ++ @typeName(field.type) ++ "`"),
                }
            },

            .Enum => bytes = @sizeOf(field.type),

            else => unreachable,
        }

        switch (bytes) {
            1 => {
                if (field_ty == .Enum) {
                    buf[i] = @enumToInt(@field(op, field.name));
                } else {
                    buf[i] = @field(op, field.name);
                }
                i += 1;
            },

            2 => {
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
        comptime var bytes: comptime_int = 0;

        switch (field_ty) {
            .Int => |int| {
                switch (int.bits) {
                    8 => bytes = 1,
                    16 => bytes = 2,
                    else => @compileError("type not supported `" ++ @typeName(field.type) ++ "`"),
                }
            },

            .Enum => bytes = @sizeOf(field.type),

            else => unreachable,
        }

        switch (bytes) {
            1 => {
                res[i] = buf[i];
                i += 1;
            },

            2 => {
                if (native_endian == .Big) {
                    res[i] = buf[i + 1];
                    res[i + 1] = buf[i];
                } else {
                    res[i] = buf[i];
                    res[i + 1] = buf[i + 1];
                }
                i += 2;
            },

            else => {},
        }
    }

    return @bitCast(T, res);
}
