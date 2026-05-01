const std = @import("std");
const zt = @import("ziotween");

pub fn main() !void {
    var t = zt.Tween(f32).init(0, 100, 1_000_000_000, zt.ease.elasticOut);
    t.start();

    for (0..10) |i| {
        const v = t.update(100_000_000);
        std.debug.print("t={d}: {d:.1}\n", .{i + 1, v});
    }
}
