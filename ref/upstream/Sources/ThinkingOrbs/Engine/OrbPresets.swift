//
//  OrbPresets.swift
//  ThinkingOrbs
//
//  The shipped tunings: nine designs × two sizes, baked on the web. Each
//  preset multiplies a base ("fine") profile's counts and radii and sets the
//  speed of the shared clock. Resolved once per (design, size) and cached, so
//  the render loop only ever sees plain numbers.
//

import Foundation

/// The geometry builder a design runs on. `ring` shares ribbon's builder.
enum OrbMode: String, CaseIterable, Sendable {
    case orbits, globe, rubik, wave, web, braid, ribbon, ring, morph
}

extension OrbDesign {
    var mode: OrbMode {
        switch self {
        case .working: return .orbits
        case .searching: return .globe
        case .solving: return .rubik
        case .listening: return .wave
        case .connecting: return .web
        case .weaving: return .braid
        case .composing: return .ribbon
        case .breathing: return .ring
        case .shaping: return .morph
        }
    }
}

/// Mode options, keyed exactly as the web engine keys them. A missing key
/// falls back to the default written at its point of use.
typealias OrbOpts = [String: Double]

/// A (design, size) pair resolved to its builder, baked speed and options.
struct OrbResolved: Sendable {
    let mode: OrbMode
    let speed: Double
    let opts: OrbOpts

    /// The frame at geometry time `t` (seconds × speed) for a `size`-point box.
    /// Any time is safe, negative or not; a non-finite one draws time zero.
    func frame(size: Double, t: Double) -> OrbFrame {
        OrbEngine.frame(mode, size: size, t: t.isFinite ? t : 0, opts: opts)
    }
}

// MARK: - Presets

enum OrbPresets {

    struct Preset {
        let speed: Double
        let count: Double
        let size: Double
        var extra: OrbOpts = [:]
    }

    /// The shipped tunings, baked on the web. `count` and `size` multiply the
    /// base profile; `speed` multiplies the shared clock.
    static func preset(_ mode: OrbMode, _ size: OrbSize) -> Preset {
        switch (mode, size) {
        case (.orbits, .regular): return Preset(speed: 1.885, count: 1, size: 1)
        case (.orbits, .small): return Preset(speed: 3.9, count: 0.238, size: 2.4)
        case (.globe, .regular): return Preset(speed: 2.015, count: 0.42, size: 1.15, extra: ["scanMul": 4.08, "dimBase": 0.45])
        case (.globe, .small): return Preset(speed: 2.665, count: 0.105, size: 1.75, extra: ["scanMul": 4.335, "dimBase": 0.45])
        case (.rubik, .regular): return Preset(speed: 1.82, count: 0.35, size: 1.05)
        case (.rubik, .small): return Preset(speed: 1.95, count: 0.088, size: 1.9)
        case (.wave, .regular): return Preset(speed: 4.388, count: 0.341, size: 1)
        case (.wave, .small): return Preset(speed: 3.998, count: 0.105, size: 1.6)
        case (.web, .regular): return Preset(speed: 3.315, count: 1.35, size: 0.95)
        case (.web, .small): return Preset(speed: 6.63, count: 0.25, size: 1.52)
        case (.braid, .regular): return Preset(speed: 1.625, count: 0.5, size: 1)
        case (.braid, .small): return Preset(speed: 2.75, count: 0.1125, size: 1.36)
        case (.ribbon, .regular): return Preset(speed: 2.34, count: 0.25, size: 0.85, extra: ["spin": 0, "bandMul": 3.9, "wobMul": 1])
        case (.ribbon, .small): return Preset(speed: 3.12, count: 0.051, size: 1.073, extra: ["spin": 0, "bandMul": 4.94, "wobMul": 1])
        case (.ring, .regular): return Preset(speed: 3.24, count: 0.25, size: 0.956, extra: ["spin": 0, "bandMul": 3.627, "wobMul": 0.368])
        case (.ring, .small): return Preset(speed: 3.78, count: 0.028, size: 1.622, extra: ["spin": 0, "bandMul": 3.968, "wobMul": 0.565])
        case (.morph, .regular): return Preset(speed: 2.405, count: 0.702, size: 0.395, extra: ["spread": 1.45])
        case (.morph, .small): return Preset(speed: 2.08, count: 0.53, size: 1.011, extra: ["spread": 1.45])
        }
    }

    /// Base ("fine") profiles per mode, before the preset multipliers.
    static func base(_ mode: OrbMode) -> OrbOpts {
        switch mode {
        case .globe:
            return ["latRings": 17, "lonDensity": 44, "rBase": 0.6, "rDepth": 1.7, "rBoost": 1.0,
                    "inkFar": 0.62, "inkSpan": 0.54, "rsPow": 0.6, "rMin": 0.3]
        case .orbits:
            return ["orbitN": 12, "ghostN": 40, "ghostR": 0.9, "ghostA": 0.5, "particles": 3,
                    "partR": 1.2, "partRDepth": 1.6, "rsPow": 0.6, "rMin": 0.3]
        case .rubik:
            return ["latRings": 15, "lonDensity": 40, "moveCount": 14, "rBase": 0.6, "rDepth": 1.7,
                    "rActive": 0.3, "inkFar": 0.62, "inkSpan": 0.54, "rsPow": 0.6, "rMin": 0.3]
        case .wave:
            return ["rings": 15, "lonDensity": 40, "rBase": 0.6, "rDepth": 1.7, "rsPow": 0.6, "rMin": 0.3]
        case .web:
            return ["nodeN": 30, "thr": 0.72, "signals": 5, "nodeR": 1.4, "nodeRDepth": 1.8,
                    "lineW": 0.8, "rsPow": 0.6, "rMin": 0.3]
        case .braid:
            return ["strandN": 52, "turns": 3.0, "ghostN": 150, "rBase": 1.2, "rDepth": 1.8,
                    "rsPow": 0.6, "rMin": 0.3]
        case .ribbon:
            return ["lanes": 5, "segs": 88, "ghostN": 150, "rBase": 1.1, "rDepth": 1.7,
                    "rsPow": 0.6, "rMin": 0.3]
        case .ring:
            // ribbon's builder; faceOn cancels the camera tilt and moves the
            // undulation onto the radius, and there is no ghost sphere behind it
            return ["lanes": 5, "segs": 88, "ghostN": 0, "faceOn": 1, "rBase": 1.1, "rDepth": 1.7,
                    "rsPow": 0.6, "rMin": 0.3]
        case .morph:
            return ["rDot": 0.021, "iconD": 1, "rMin": 0.25]
        }
    }

    // 2-D lattices come in pairs: each side takes √scale so the TOTAL count
    // scales by `scale`. Flat lists scale linearly.
    private static let countPairs: [(String, String)] = [
        ("latRings", "lonDensity"), ("rings", "lonDensity"), ("lanes", "segs"),
    ]
    private static let countKeys = ["orbitN", "ghostN", "nodeN", "strandN", "signals"]
    private static let radiusKeys = ["rBase", "rDepth", "rActive", "rDot", "ghostR", "partR",
                                     "partRDepth", "nodeR", "nodeRDepth"]

    static func scaleCounts(_ opts: OrbOpts, _ scale: Double) -> OrbOpts {
        var out = opts
        var done = Set<String>()
        let rt = scale.squareRoot()
        for (a, b) in countPairs {
            if let va = out[a], let vb = out[b], !done.contains(a), !done.contains(b) {
                out[a] = max(2, OrbEngine.jsRound(va * rt))
                out[b] = max(2, OrbEngine.jsRound(vb * rt))
                done.insert(a)
                done.insert(b)
            }
        }
        for k in countKeys {
            // 0 opts a layer out entirely (ring has no ghost sphere); scaling
            // must not resurrect it as a single stray dot
            if let v = out[k], v != 0, !done.contains(k) {
                out[k] = max(1, OrbEngine.jsRound(v * scale))
            }
        }
        if let v = out["iconD"] { out["iconD"] = max(0.02, v * scale) }
        return out
    }

    static func scaleRadii(_ opts: OrbOpts, _ scale: Double) -> OrbOpts {
        var out = opts
        for k in radiusKeys {
            if let v = out[k] { out[k] = v * scale }
        }
        out["rSizeMul"] = (out["rSizeMul"] ?? 1) * scale
        return out
    }

    private static let cache: [String: OrbResolved] = {
        var c: [String: OrbResolved] = [:]
        for design in OrbDesign.allCases {
            for size in OrbSize.allCases {
                c["\(design.rawValue)-\(size.rawValue)"] = compute(design, size)
            }
        }
        return c
    }()

    /// A (design, size) pair's builder and fully scaled options. Cached.
    static func resolve(_ design: OrbDesign, _ size: OrbSize) -> OrbResolved {
        cache["\(design.rawValue)-\(size.rawValue)"] ?? compute(design, size)
    }

    private static func compute(_ design: OrbDesign, _ size: OrbSize) -> OrbResolved {
        let mode = design.mode
        let p = preset(mode, size)
        var opts = base(mode)
        if p.count != 1 { opts = scaleCounts(opts, p.count) }
        if p.size != 1 { opts = scaleRadii(opts, p.size) }
        opts.merge(p.extra) { _, new in new }
        return OrbResolved(mode: mode, speed: p.speed, opts: opts)
    }
}
