# ziotween

> Tweening engine for Zig game animations. Easing curves, sequences, yoyo/loop.

Part of the [zio-zig](https://github.com/deblasis/zio-zig) ecosystem.

## Quick start

```zig
const ztween = @import("ziotween");
const ease = ztween.ease;

// Create a tween: value goes from 0 to 100 over 1 second
var t = ztween.Tween(f32).init(0, 100, 1_000_000_000, ease.linear);
t.start();

// Update each frame
const value = t.update(16_000_000); // 16ms frame
// value ≈ 1.6

// Check state
if (t.done()) { /* tween finished */ }
const progress = t.progress(); // 0.0 to 1.0

// Create a sequence of tweens
var tweens = [_]ztween.Tween(f32){
    ztween.Tween(f32).init(0, 50, 500_000_000, ease.cubicOut),
    ztween.Tween(f32).init(50, 100, 500_000_000, ease.bounceOut),
};
var seq = ztween.Sequence(f32).init(&tweens);
seq.start();
```

```bash
zig build test          # Run 40 tests
zig build run-example   # Run example
```

## Example output

```
$ zig build run-example
After 16ms: 1.6
Progress: 0.02
Done: false
After 1s: 100.0
Done: true
Sequence done: false
```

## API

### Tween(T)

Animates a value from `from` to `to` over `duration_ns` with an easing function.

| Method | Description |
|--------|-------------|
| `init(from, to, duration_ns, easing)` | Create tween |
| `start()` | Start/restart the tween |
| `update(dt_ns)` | Advance time, returns current value |
| `value()` | Current interpolated value |
| `progress()` | Progress 0.0 to 1.0 |
| `done()` | Whether tween is complete |

### Sequence(T)

Plays multiple tweens in order.

| Method | Description |
|--------|-------------|
| `init(tweens)` | Create from tween array |
| `start()` | Start/restart sequence |
| `update(dt_ns)` | Advance, returns current value |
| `done()` | Whether all tweens complete |

### Easing functions

Use any function with signature `fn(comptime T, T) T`. See [zioease](https://github.com/deblasis/zioease) for 30+ built-in easing functions.

## License

MIT. Copyright (c) 2026 Alessandro De Blasis.
