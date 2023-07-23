const std = @import("std");
const lang = @import("lang");

test "simple execution example" {
    var emitter = try lang.Emitter.init(std.testing.allocator);
    defer emitter.deinit();

    try emitter.clear();
    try emitter.append("hello");
    try emitter.reg(1);
    try emitter.append(", ");
    try emitter.append("world");
    try emitter.reg(0);
    try emitter.clear();
    try emitter.append("hallo, welt");
    try emitter.reg(2);
    try emitter.exit();

    var vm = try lang.Vm.init(std.testing.allocator);
    defer vm.deinit();

    var prog = emitter.emit();

    try vm.run(&prog);

    try std.testing.expectEqualStrings("hello, world", vm.fetch(0).?);
    try std.testing.expectEqualStrings("hello", vm.fetch(1).?);
    try std.testing.expectEqualStrings("hallo, welt", vm.fetch(2).?);
    try std.testing.expectEqual(vm.fetch(3), null);
}
