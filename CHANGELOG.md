## 0.0.1

* Initial release: 1:1 Flutter port of ThinkingOrbs.
* 9 hand-tuned designs: `working`, `searching`, `solving`, `listening`, `connecting`, `weaving`, `composing`, `breathing`, `shaping`.
* 2 purpose-tuned sizes: `regular` (64 pt) and `small` (20 pt).
* Pure monochrome dot rendering with 256-level ink quantization and theme brightness following.
* Shared global clock synchronization across all orbs on screen.
* `ThinkingOrbLabel` status indicator with live 2.0s highlight shimmer mask.
* `.thinkingShimmer()` widget extension modifier.
* `OrbClockOverride` for deterministic golden image snapshots.
* Support for Reduce Motion (`MediaQuery.disableAnimations`) and High Contrast.
* Complete reference specifications and architecture mappings in `ref/`.
* 100% pass on 72-case golden vector verification suite matching web and Swift upstream.
