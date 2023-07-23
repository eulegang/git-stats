const std = @import("std");
const lang = @import("lang");

test "foobar" {
    var vm = try lang.Vm.init(std.testing.allocator);
    defer vm.deinit();
}
