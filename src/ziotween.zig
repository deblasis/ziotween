//! Tweening engine for game animations.
//!
//! Animate any numeric value over time with easing curves.
//! Works standalone or paired with zioease for easing functions.

const std = @import("std");

/// A single tween that animates a float value from `start` to `end`.
pub fn Tween(comptime T: type) type {
    return struct {
        start_val: T,
        end_val: T,
        duration_ns: u64,
        elapsed_ns: u64,
        easing: EasingFn,
        running: bool,
        looping: bool,
        yoyo: bool,
        reversed: bool,

        pub const EasingFn = *const fn (T) T;

        pub fn init(from: T, to: T, duration_ns: u64, easing: EasingFn) @This() {
            return .{
                .start_val = from,
                .end_val = to,
                .duration_ns = duration_ns,
                .elapsed_ns = 0,
                .easing = easing,
                .running = false,
                .looping = false,
                .yoyo = false,
                .reversed = false,
            };
        }

        /// Start (or restart) the tween.
        pub fn start(self: *@This()) void {
            self.elapsed_ns = 0;
            self.running = true;
            self.reversed = false;
        }

        /// Pause the tween.
        pub fn pause(self: *@This()) void {
            self.running = false;
        }

        /// Resume a paused tween.
        pub fn unpause(self: *@This()) void {
            self.running = true;
        }

        /// Update the tween by `dt_ns` nanoseconds. Returns current value.
        pub fn update(self: *@This(), dt_ns: u64) T {
            if (!self.running) return self.value();

            self.elapsed_ns += dt_ns;
            if (self.elapsed_ns >= self.duration_ns) {
                if (self.looping) {
                    self.elapsed_ns %= self.duration_ns;
                    if (self.yoyo) self.reversed = !self.reversed;
                } else {
                    self.elapsed_ns = self.duration_ns;
                    self.running = false;
                }
            }

            return self.value();
        }

        /// Get current interpolated value.
        pub fn value(self: *const @This()) T {
            const t: T = if (self.duration_ns == 0)
                1.0
            else
                @as(T, @floatFromInt(self.elapsed_ns)) / @as(T, @floatFromInt(self.duration_ns));

            const eased = self.easing(std.math.clamp(t, 0, 1));
            if (self.reversed) return self.end_val + (self.start_val - self.end_val) * eased;
            return self.start_val + (self.end_val - self.start_val) * eased;
        }

        /// Has the tween completed?
        pub fn done(self: *const @This()) bool {
            return !self.running and self.elapsed_ns >= self.duration_ns;
        }

        /// Progress from 0 to 1.
        pub fn progress(self: *const @This()) T {
            if (self.duration_ns == 0) return 1.0;
            return std.math.clamp(@as(T, @floatFromInt(self.elapsed_ns)) / @as(T, @floatFromInt(self.duration_ns)), 0, 1);
        }
    };
}

/// Built-in easing functions that can be used directly.
pub const ease = struct {
    pub fn linear(t: f32) f32 { return t; }
    pub fn quadIn(t: f32) f32 { return t * t; }
    pub fn quadOut(t: f32) f32 { return -(t - 1) * (t - 1) + 1; }
    pub fn quadInOut(t: f32) f32 {
        if (t < 0.5) return 2 * t * t;
        return -1 + (4 - 2 * t) * t;
    }
    pub fn cubicIn(t: f32) f32 { return t * t * t; }
    pub fn cubicOut(t: f32) f32 { const t1 = t - 1; return t1 * t1 * t1 + 1; }
    pub fn cubicInOut(t: f32) f32 {
        if (t < 0.5) return 4 * t * t * t;
        const t1 = 2 * t - 2; return 0.5 * t1 * t1 * t1 + 1;
    }
    pub fn elasticOut(t: f32) f32 {
        if (t == 0 or t == 1) return t;
        return std.math.pow(f32, 2, -10 * t) * @sin((10 * t - 0.75) * (2 * std.math.pi) / 3) + 1;
    }
    pub fn bounceOut(t: f32) f32 {
        if (t < 1.0 / 2.75) return 7.5625 * t * t;
        if (t < 2.0 / 2.75) { const t1 = t - 1.5 / 2.75; return 7.5625 * t1 * t1 + 0.75; }
        if (t < 2.5 / 2.75) { const t1 = t - 2.25 / 2.75; return 7.5625 * t1 * t1 + 0.9375; }
        const t1 = t - 2.625 / 2.75; return 7.5625 * t1 * t1 + 0.984375;
    }
    pub fn sineInOut(t: f32) f32 { return -0.5 * (@cos(std.math.pi * t) - 1); }
};

/// Tween sequence — chain multiple tweens one after another.
pub fn Sequence(comptime T: type) type {
    return struct {
        tweens: []Tween(T),
        current: usize,
        running: bool,

        pub fn init(tweens: []Tween(T)) @This() {
            return .{ .tweens = tweens, .current = 0, .running = false };
        }

        pub fn start(self: *@This()) void {
            self.current = 0;
            self.running = true;
            if (self.tweens.len > 0) self.tweens[0].start();
        }

        pub fn update(self: *@This(), dt_ns: u64) T {
            if (!self.running or self.current >= self.tweens.len) return if (self.tweens.len > 0) self.tweens[self.tweens.len - 1].value() else 0;
            const v = self.tweens[self.current].update(dt_ns);
            if (self.tweens[self.current].done()) {
                self.current += 1;
                if (self.current < self.tweens.len) {
                    self.tweens[self.current].start();
                } else {
                    self.running = false;
                }
            }
            return v;
        }

        pub fn done(self: *const @This()) bool {
            return !self.running;
        }
    };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "Tween basic interpolation" {
    var t = Tween(f32).init(0, 100, 1000, ease.linear);
    t.start();
    const v = t.update(500); // halfway
    try std.testing.expectApproxEqAbs(@as(f32, 50), v, 0.1);
}

test "Tween completes" {
    var t = Tween(f32).init(0, 100, 1000, ease.linear);
    t.start();
    _ = t.update(1000);
    try std.testing.expect(t.done());
    try std.testing.expectApproxEqAbs(@as(f32, 100), t.value(), 0.1);
}

test "Tween pauses and unpauses" {
    var t = Tween(f32).init(0, 100, 1000, ease.linear);
    t.start();
    _ = t.update(300);
    t.pause();
    _ = t.update(200); // ignored while paused
    try std.testing.expectApproxEqAbs(@as(f32, 30), t.value(), 0.1);
    t.unpause();
    _ = t.update(200);
    try std.testing.expectApproxEqAbs(@as(f32, 50), t.value(), 0.1);
}

test "Tween looping" {
    var t = Tween(f32).init(0, 100, 1000, ease.linear);
    t.looping = true;
    t.start();
    _ = t.update(1500); // wraps around
    try std.testing.expect(!t.done()); // still running
    try std.testing.expectApproxEqAbs(@as(f32, 50), t.value(), 0.1);
}

test "Tween yoyo" {
    var t = Tween(f32).init(0, 100, 1000, ease.linear);
    t.looping = true;
    t.yoyo = true;
    t.start();
    _ = t.update(1000); // forward complete
    try std.testing.expect(!t.done());
    _ = t.update(500); // halfway back
    try std.testing.expectApproxEqAbs(@as(f32, 50), t.value(), 0.1);
}

test "Tween zero duration" {
    var t = Tween(f32).init(0, 100, 0, ease.linear);
    t.start();
    try std.testing.expectApproxEqAbs(@as(f32, 100), t.value(), 0.1);
}

test "Tween progress" {
    var t = Tween(f32).init(0, 100, 1000, ease.linear);
    t.start();
    _ = t.update(250);
    try std.testing.expectApproxEqAbs(@as(f32, 0.25), t.progress(), 0.01);
}

test "ease quadIn" {
    try std.testing.expectApproxEqAbs(@as(f32, 0.25), ease.quadIn(0.5), 0.001);
}

test "ease elasticOut overshoots" {
    const v = ease.elasticOut(0.5);
    try std.testing.expect(v > 1.0);
}

test "ease bounceOut boundaries" {
    try std.testing.expectApproxEqAbs(@as(f32, 0), ease.bounceOut(0), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1), ease.bounceOut(1), 0.001);
}

test "Sequence chains tweens" {
    var tweens = [_]Tween(f32){
        Tween(f32).init(0, 50, 500, ease.linear),
        Tween(f32).init(50, 100, 500, ease.linear),
    };
    var seq = Sequence(f32).init(&tweens);
    seq.start();
    _ = seq.update(250); // first tween halfway
    try std.testing.expect(!seq.done());
    _ = seq.update(500); // finish first, start second
    _ = seq.update(250); // second halfway
    try std.testing.expectApproxEqAbs(@as(f32, 75), tweens[1].value(), 0.1);
    _ = seq.update(250); // finish second
    try std.testing.expect(seq.done());
}

test "Tween negative values" {
    var t = Tween(f32).init(-100, 100, 1000, ease.linear);
    t.start();
    const v = t.update(500);
    try std.testing.expectApproxEqAbs(@as(f32, 0), v, 0.1);
}

test "Tween very small duration" {
    var t = Tween(f32).init(0, 100, 1, ease.linear);
    t.start();
    _ = t.update(1);
    try std.testing.expect(t.done());
}

test "ease cubicInOut" {
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), ease.cubicInOut(0.5), 0.001);
}

test "ease sineInOut" {
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), ease.sineInOut(0.5), 0.001);
}

test "Tween f64 precision" {
    var t = Tween(f64).init(0, 100, 1000, struct {
        fn f(t: f64) f64 { return t; }
    }.f);
    t.start();
    const v = t.update(500);
    try std.testing.expectApproxEqAbs(@as(f64, 50), v, 0.1);
}

test "Tween large values" {
    var t = Tween(f32).init(-1000, 1000, 1000, ease.linear);
    t.start();
    const v = t.update(500);
    try std.testing.expectApproxEqAbs(@as(f32, 0), v, 0.1);
}

test "Sequence empty" {
    var tweens = [_]Tween(f32){};
    var seq = Sequence(f32).init(&tweens);
    seq.start();
    // Empty sequence: start sets running=true, but no tweens to process
    // update should return 0
    const v = seq.update(100);
    try std.testing.expectEqual(@as(f32, 0), v);
}

test "Tween ease quadOut" {
    try std.testing.expectApproxEqAbs(@as(f32, 0.75), ease.quadOut(0.5), 0.001);
}

test "Tween ease bounceOut at 0.5" {
    const v = ease.bounceOut(0.5);
    try std.testing.expect(v > 0 and v < 1);
}

test "Tween yoyo with loop returns to start" {
    var t = Tween(f32).init(0, 100, 1000, ease.linear);
    t.looping = true;
    t.yoyo = true;
    t.start();
    _ = t.update(1000); // forward complete → value 100
    _ = t.update(1000); // backward complete → value 0
    try std.testing.expectApproxEqAbs(@as(f32, 0), t.value(), 0.1);
}

test "ease quadIn value" {
    try std.testing.expectApproxEqAbs(@as(f32, 0.25), ease.quadIn(0.5), 0.001);
}

test "ease cubicOut value" {
    try std.testing.expectApproxEqAbs(@as(f32, 0.875), ease.cubicOut(0.5), 0.001);
}

test "Sequence with three tweens" {
    var tweens = [_]Tween(f32){
        Tween(f32).init(0, 10, 100, ease.linear),
        Tween(f32).init(10, 20, 100, ease.linear),
        Tween(f32).init(20, 30, 100, ease.linear),
    };
    var seq = Sequence(f32).init(&tweens);
    seq.start();

    _ = seq.update(100); // finish first
    _ = seq.update(100); // finish second
    _ = seq.update(100); // finish third
    try std.testing.expect(seq.done());
}

test "Tween negative to negative" {
    var t = Tween(f32).init(-50, -10, 1000, ease.linear);
    t.start();
    const v = t.update(500);
    try std.testing.expectApproxEqAbs(@as(f32, -30), v, 0.1);
}

test "Tween done after exact duration" {
    var t = Tween(f32).init(0, 100, 1000, ease.linear);
    t.start();
    _ = t.update(999);
    try std.testing.expect(!t.done());
    _ = t.update(1);
    try std.testing.expect(t.done());
}

test "Tween start resets elapsed" {
    var t = Tween(f32).init(0, 100, 1000, ease.linear);
    t.start();
    _ = t.update(500);
    t.start(); // restart
    try std.testing.expectEqual(@as(u64, 0), t.elapsed_ns);
    try std.testing.expect(!t.done());
}

test "ease linear at 0.25" {
    try std.testing.expectApproxEqAbs(@as(f32, 0.25), ease.linear(0.25), 0.001);
}

test "Tween with elastic ease overshoots then settles" {
    var t = Tween(f32).init(0, 100, 1000, ease.elasticOut);
    t.start();
    // At some point during animation, value should exceed target
    var overshot = false;
    for (0..20) |_| {
        const v = t.update(50);
        if (v > 100) overshot = true;
    }
    try std.testing.expect(overshot);
}

test "Tween value at start" {
    var t = Tween(f32).init(10, 50, 1000, ease.linear);
    t.start();
    try std.testing.expectApproxEqAbs(@as(f32, 10), t.value(), 0.1);
}
