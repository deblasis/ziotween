const std = @import("std");
const ztween = @import("ziotween");
const ease = ztween.ease;

pub fn main() !void {
    // Create a tween: value goes from 0 to 100 over 1 second
    // (using built-in ease — for more, import zioease)
    var t = ztween.Tween(f32).init(0, 100, 1_000_000_000, ease.linear);
    t.start();

    // Update each frame (16ms)
    const value = t.update(16_000_000);
    std.debug.print("After 16ms: {d:.1}\n", .{value});

    // Check state
    std.debug.print("Progress: {d:.2}\n", .{t.progress()});
    std.debug.print("Done: {}\n", .{t.done()});

    // Finish the tween
    _ = t.update(984_000_000);
    std.debug.print("After 1s: {d:.1}\n", .{t.value()});
    std.debug.print("Done: {}\n", .{t.done()});

    // Create a sequence of tweens
    var tweens = [_]ztween.Tween(f32){
        ztween.Tween(f32).init(0, 50, 500_000_000, ease.cubicOut),
        ztween.Tween(f32).init(50, 100, 500_000_000, ease.bounceOut),
    };
    var seq = ztween.Sequence(f32).init(&tweens);
    seq.start();

    _ = seq.update(600_000_000); // in second tween
    std.debug.print("Sequence done: {}\n", .{seq.done()});
}
