//
//  OrbEngine.swift
//  ThinkingOrbs
//
//  The geometry behind every orb: pure maths over (size, t, opts), with no
//  SwiftUI, no drawing surface and no theme. Hand-ported from Jakub Antalik's
//  thinking-orbs (MIT). Every formula is transcribed term for term from the
//  web engine, including its evaluation order, so the output matches the
//  library's golden vectors to 1e-4 at every dot and a 725,149-frame
//  differential sweep to 2e-9. If a design needs retuning, retune it on the
//  web and re-port; don't nudge constants here.
//

import Foundation

// MARK: - Engine

enum OrbEngine {

    static func frame(_ mode: OrbMode, size: Double, t: Double, opts: OrbOpts) -> OrbFrame {
        switch mode {
        case .orbits: return orbits(size, t, opts)
        case .globe: return globe(size, t, opts)
        case .rubik: return rubik(size, t, opts)
        case .wave: return wave(size, t, opts)
        case .web: return web(size, t, opts)
        case .braid: return braid(size, t, opts)
        case .ribbon, .ring: return ribbon(size, t, opts)
        case .morph: return morph(size, t, opts)
        }
    }

    // MARK: Primitives

    /// JavaScript's `Math.round`: halves go toward +∞.
    static func jsRound(_ x: Double) -> Double { (x + 0.5).rounded(.down) }

    static func frac(_ x: Double) -> Double { x - x.rounded(.down) }

    static func lerp(_ a: Double, _ b: Double, _ f: Double) -> Double { a + (b - a) * f }

    /// Deterministic hash in [0, 1).
    static func hashD(_ a: Double, _ b: Double) -> Double {
        let h = sin(a * 12.9898 + b * 78.233) * 43758.5453
        return h - h.rounded(.down)
    }

    /// Value noise on a 2-D lattice: smooth, deterministic, cheap.
    static func vnoise(_ x: Double, _ y: Double) -> Double {
        let xi = x.rounded(.down)
        let yi = y.rounded(.down)
        var fx = x - xi
        var fy = y - yi
        fx = fx * fx * (3 - 2 * fx)
        fy = fy * fy * (3 - 2 * fy)
        let a = hashD(xi, yi)
        let b = hashD(xi + 1, yi)
        let c = hashD(xi, yi + 1)
        let d = hashD(xi + 1, yi + 1)
        return a + (b - a) * fx + (c - a) * fy + (a - b - c + d) * fx * fy
    }

    /// Stable directions on a unit sphere (Fibonacci lattice).
    static func fibDir(_ i: Int, _ n: Double) -> (Double, Double, Double) {
        let golden = Double.pi * (3 - 5.0.squareRoot())
        let y = 1 - (2 * (Double(i) + 0.5)) / n
        let rad = (1 - y * y).squareRoot()
        let a = Double(i) * golden
        return (rad * cos(a), y, rad * sin(a))
    }

    /// Shortest signed angular distance, wrapped to (-π, π].
    static func angleDelta(_ a: Double, _ b: Double) -> Double {
        atan2(sin(a - b), cos(a - b))
    }

    /// Dot radii were tuned for a 300-pt frame; sub-linear scaling keeps small
    /// spinners legible.
    static func radiusScale(_ size: Double, _ p: Double) -> Double {
        pow(size / 300, p)
    }

    /// Shared spin + tilt + orthographic projection.
    struct Projector {
        let st: Double, ct: Double, sy: Double, cyw: Double
        let cx: Double, cy: Double, scale: Double

        init(yaw: Double, tilt: Double, cx: Double, cy: Double, scale: Double) {
            st = sin(tilt)
            ct = cos(tilt)
            sy = sin(yaw)
            cyw = cos(yaw)
            self.cx = cx
            self.cy = cy
            self.scale = scale
        }

        @inline(__always)
        func callAsFunction(_ x: Double, _ y: Double, _ z: Double) -> (Double, Double, Double) {
            let x1 = x * cyw + z * sy
            let z1 = -x * sy + z * cyw
            let y1 = y * ct - z1 * st
            let z2 = y * st + z1 * ct
            return (cx + x1 * scale, cy - y1 * scale, z2)
        }
    }

    /// Drop invisible marks, clamp radii to the mode's floor, and z-sort
    /// far → near (stable, like the web's Array.sort) into draw order.
    static func finalize(_ dots: [OrbDot], _ lines: [OrbLine], rMin: Double) -> OrbFrame {
        var visible: [(Int, OrbDot)] = []
        visible.reserveCapacity(dots.count)
        for (i, var d) in dots.enumerated() where d.a >= 0.02 {
            d.r = max(rMin, d.r)
            visible.append((i, d))
        }
        visible.sort { $0.1.z != $1.1.z ? $0.1.z < $1.1.z : $0.0 < $1.0 }
        return OrbFrame(dots: visible.map(\.1), lines: lines.filter { $0.a >= 0.02 })
    }

    /// A count option, kept as the raw number the web engine loops against,
    /// so even a fractional count behaves exactly as JS's `i < n` does.
    private static func count(_ o: OrbOpts, _ key: String, _ fallback: Double) -> Double {
        o[key] ?? fallback
    }

    /// How many times `for (let i = 0; i < n; i++)` runs.
    private static func below(_ n: Double) -> Int { n > 0 ? Int(n.rounded(.up)) : 0 }

    /// How many times `for (let i = 0; i <= n; i++)` runs.
    private static func through(_ n: Double) -> Int { n >= 0 ? Int(n.rounded(.down)) + 1 : 0 }

    // MARK: Orbits — working

    static func orbits(_ size: Double, _ t: Double, _ o: OrbOpts) -> OrbFrame {
        let cx = size / 2
        let cy = size / 2
        let R = (size / 2) * 0.82
        let pt = Projector(yaw: t * 0.12, tilt: 0.3, cx: cx, cy: cy, scale: 1)
        let rs = radiusScale(size, o["rsPow"] ?? 0.6)

        let orbitN = count(o, "orbitN", 12)
        let ghostN = count(o, "ghostN", 40)
        let particles = count(o, "particles", 3)
        let ghostR = o["ghostR"] ?? 0.9
        let ghostA = o["ghostA"] ?? 0.5
        let partR = o["partR"] ?? 1.2
        let partRDepth = o["partRDepth"] ?? 1.6

        var dots: [OrbDot] = []
        dots.reserveCapacity(below(orbitN) * (below(ghostN) + below(particles)))

        for orb in 0..<below(orbitN) {
            let h1 = hashD(Double(orb), 1.7)
            let h2 = hashD(Double(orb), 5.2)
            let h3 = hashD(Double(orb), 8.9)
            let ro = R * (0.45 + 0.52 * h1)
            let th = h1 * 2 * Double.pi
            let phi = acos(2 * h2 - 1)
            // orbit plane basis (u, v ⟂ normal n)
            let nx = sin(phi) * cos(th)
            let ny = cos(phi)
            let nz = sin(phi) * sin(th)
            var ux = -ny
            var uy = nx
            let uz = 0.0
            let ul = max(1e-6, (ux * ux + uy * uy).squareRoot())
            ux /= ul
            uy /= ul
            let vx = ny * uz - nz * uy
            let vy = nz * ux - nx * uz
            let vz = nx * uy - ny * ux
            let speed = (0.25 + 0.55 * h3) * (h3 > 0.5 ? 1 : -1)

            // ghost path
            for k in 0..<below(ghostN) {
                let a = (Double(k) / ghostN) * 2 * Double.pi
                let (px, py, z) = pt(
                    (ux * cos(a) + vx * sin(a)) * ro,
                    (uy * cos(a) + vy * sin(a)) * ro,
                    (uz * cos(a) + vz * sin(a)) * ro
                )
                let depth = (z / ro + 1) / 2
                dots.append(OrbDot(x: px, y: py, z: z, r: ghostR * rs, white: 0.72,
                                   a: ghostA * (0.4 + 0.6 * depth)))
            }
            // the particles doing the work
            for m in 0..<below(particles) {
                let a = t * speed + (Double(m) / particles) * 2 * Double.pi + h2 * 6
                let (px, py, z) = pt(
                    (ux * cos(a) + vx * sin(a)) * ro,
                    (uy * cos(a) + vy * sin(a)) * ro,
                    (uz * cos(a) + vz * sin(a)) * ro
                )
                let depth = (z / ro + 1) / 2
                dots.append(OrbDot(x: px, y: py, z: z, r: (partR + partRDepth * depth) * rs,
                                   white: 0.3 - 0.22 * depth))
            }
        }
        return finalize(dots, [], rMin: o["rMin"] ?? 0.3)
    }

    // MARK: Globe — searching

    static func globe(_ size: Double, _ t: Double, _ o: OrbOpts) -> OrbFrame {
        let spin = 0.5
        let cx = size / 2
        let cy = size / 2
        let radius = (size / 2) * 0.82
        let tilt = 0.4 + 0.06 * sin(t * 0.35)
        let pt = Projector(yaw: t * spin, tilt: tilt, cx: cx, cy: cy, scale: radius)
        // the scan sweeps relative to the spin; scanMul scales that rate
        let scan = t * (spin + (1.7 - spin) * (o["scanMul"] ?? 1))
        let rs = radiusScale(size, o["rsPow"] ?? 0.6)
        let dimBase = o["dimBase"] ?? 1
        let rBase = o["rBase"] ?? 0.6
        let rDepth = o["rDepth"] ?? 1.7
        let rBoost = o["rBoost"] ?? 1
        let inkFar = o["inkFar"] ?? 0.62
        let inkSpan = o["inkSpan"] ?? 0.54

        var dots: [OrbDot] = []
        let latRings = count(o, "latRings", 17)
        let lonDensity = o["lonDensity"] ?? 44
        for li in 0..<through(latRings) {
            let lat = -Double.pi / 2 + (Double(li) / latRings) * Double.pi
            let cosLat = cos(lat)
            let sinLat = sin(lat)
            let lonCount = max(1, Int(jsRound(abs(cosLat) * lonDensity)))
            for lj in 0..<lonCount {
                let lon = (Double(lj) / Double(lonCount)) * 2 * Double.pi
                let (px, py, z) = pt(cosLat * cos(lon), sinLat, cosLat * sin(lon))
                let depth = (z + 1) / 2
                // the scan: a moving meridian read as a size ripple, not a shine
                let d = angleDelta(lon + t * spin, scan)
                let boost = exp(-(d * d) / 0.18) * max(0, z)
                dots.append(OrbDot(
                    x: px, y: py, z: z,
                    r: (rBase + rDepth * depth + rBoost * boost) * rs,
                    white: inkFar - inkSpan * depth,
                    // dimBase < 1 fades un-scanned dots so the meridian reads
                    a: dimBase + (1 - dimBase) * min(1, boost)
                ))
            }
        }
        return finalize(dots, [], rMin: o["rMin"] ?? 0.3)
    }

    // MARK: Rubik — solving

    // Rapid eased moves scramble, then replay in reverse (a palindrome) so
    // everything clicks back to solved, rests, repeats.

    private struct Move {
        let axis: Int
        let lo: Double
        let hi: Double
        let ang: Double
    }

    private static func solveCycle(_ time: Double, _ count: Int, _ slotDur: Double,
                                   _ rest: Double) -> (amount: [Double], active: Int) {
        let cyc = 2 * Double(count) * slotDur + rest
        // wrapped into [0, cyc) so a negative time can never index before the start
        var tc = time.truncatingRemainder(dividingBy: cyc)
        if tc < 0 { tc += cyc }
        var amount = [Double](repeating: 0, count: count)
        var active = -1
        if tc < 2 * Double(count) * slotDur {
            let slot = Int((tc / slotDur).rounded(.down))
            let p = (tc - Double(slot) * slotDur) / slotDur
            let cl = min(1, p / 0.7)
            let ep = 1 - pow(1 - cl, 3) // machine ease-out
            if slot < count {
                for i in 0..<slot { amount[i] = 1 }
                amount[slot] = ep
                active = slot
            } else {
                let u = 2 * count - 1 - slot
                for i in 0..<u { amount[i] = 1 }
                amount[u] = 1 - ep
                active = u
            }
        }
        return (amount, active)
    }

    private static func makeMoves(_ count: Int) -> [Move] {
        (0..<count).map { i in
            let fi = Double(i)
            let axis = min(2, Int((hashD(fi, 2.3) * 3).rounded(.down)))
            let lo = -1.0 + 0.5 * min(3, (hashD(fi, 5.9) * 4).rounded(.down))
            let dir: Double = hashD(fi, 7.7) < 0.5 ? 1 : -1
            return Move(axis: axis, lo: lo, hi: lo + 0.5, ang: (dir * Double.pi) / 2)
        }
    }

    private static func applyMoves(_ px: Double, _ py: Double, _ pz: Double, _ moves: [Move],
                                   _ amount: [Double], _ active: Int) -> (Double, Double, Double, Bool) {
        var x = px, y = py, z = pz
        var inActive = false
        for i in 0..<moves.count {
            if amount[i] <= 0 { continue }
            let mv = moves[i]
            let coord = mv.axis == 0 ? x : mv.axis == 1 ? y : z
            if coord < mv.lo || coord >= mv.hi { continue }
            if i == active { inActive = true }
            let a = mv.ang * amount[i]
            let ca = cos(a)
            let sa = sin(a)
            if mv.axis == 0 {
                let y2 = y * ca - z * sa
                z = y * sa + z * ca
                y = y2
            } else if mv.axis == 1 {
                let x2 = x * ca + z * sa
                z = -x * sa + z * ca
                x = x2
            } else {
                let x2 = x * ca - y * sa
                y = x * sa + y * ca
                x = x2
            }
        }
        return (x, y, z, inActive)
    }

    static func rubik(_ size: Double, _ t: Double, _ o: OrbOpts) -> OrbFrame {
        let cx = size / 2
        let cy = size / 2
        let R = (size / 2) * 0.82
        let pt = Projector(yaw: t * 0.55, tilt: 0.35 + 0.1 * sin(t * 0.9), cx: cx, cy: cy, scale: R)
        let rs = radiusScale(size, o["rsPow"] ?? 0.6)
        let moveCount = Int(count(o, "moveCount", 14))
        let moves = makeMoves(moveCount)
        let sc = solveCycle(t, moveCount, 0.42, 1.2)
        let rBase = o["rBase"] ?? 0.6
        let rDepth = o["rDepth"] ?? 1.7
        let rActive = o["rActive"] ?? 0.3
        let inkFar = o["inkFar"] ?? 0.62
        let inkSpan = o["inkSpan"] ?? 0.54

        var dots: [OrbDot] = []
        let latRings = count(o, "latRings", 15)
        let lonDensity = o["lonDensity"] ?? 40
        for li in 0..<through(latRings) {
            let lat = -Double.pi / 2 + (Double(li) / latRings) * Double.pi
            let cosLat = cos(lat)
            let sinLat = sin(lat)
            let lonCount = max(1, Int(jsRound(abs(cosLat) * lonDensity)))
            for lj in 0..<lonCount {
                let lon = (Double(lj) / Double(lonCount)) * 2 * Double.pi
                let (x, y, z, inActive) = applyMoves(cosLat * cos(lon), sinLat, cosLat * sin(lon),
                                                     moves, sc.amount, sc.active)
                let (px, py, zr) = pt(x, y, z)
                let depth = (zr + 1) / 2
                // the band being turned inks a touch darker: the "hand"
                dots.append(OrbDot(
                    x: px, y: py, z: zr,
                    r: (rBase + rDepth * depth + (inActive ? rActive : 0)) * rs,
                    white: inkFar - inkSpan * depth - (inActive ? 0.14 : 0)
                ))
            }
        }
        return finalize(dots, [], rMin: o["rMin"] ?? 0.3)
    }

    // MARK: Wave — listening

    static func wave(_ size: Double, _ t: Double, _ o: OrbOpts) -> OrbFrame {
        let cx = size / 2
        let cy = size / 2
        // 0.76 base × 1.15: the undulation pulls the sphere inward, so it is
        // scaled up to read the same size as the other lattice modes
        let R = (size / 2) * 0.874
        let pt = Projector(yaw: t * 0.18, tilt: 0.38, cx: cx, cy: cy, scale: 1)
        let rs = radiusScale(size, o["rsPow"] ?? 0.6)
        let rBase = o["rBase"] ?? 0.6
        let rDepth = o["rDepth"] ?? 1.7

        var dots: [OrbDot] = []
        let rings = count(o, "rings", 15)
        let lonDensity = o["lonDensity"] ?? 40
        for ri in 0..<through(rings) {
            let fri = Double(ri)
            let lat = -Double.pi / 2 + (fri / rings) * Double.pi
            let cosLat = cos(lat)
            let sinLat = sin(lat)
            // two waves, different tempi: organic, never quite repeating
            let w = 0.62 * sin(t * 2.1 - fri * 0.52) + 0.38 * sin(t * 1.27 + fri * 0.83)
            let rr = R * (0.88 + 0.105 * w)
            let lonCount = max(1, Int(jsRound(abs(cosLat) * lonDensity)))
            for lj in 0..<lonCount {
                let lon = (Double(lj) / Double(lonCount)) * 2 * Double.pi
                let (px, py, z) = pt(cosLat * cos(lon) * rr, sinLat * rr, cosLat * sin(lon) * rr)
                let depth = (z / R + 1) / 2
                let crest = max(0, w)
                dots.append(OrbDot(
                    x: px, y: py, z: z,
                    r: (rBase + rDepth * depth) * (1 + 0.4 * crest) * rs,
                    white: 0.66 - 0.56 * depth - 0.1 * crest
                ))
            }
        }
        return finalize(dots, [], rMin: o["rMin"] ?? 0.3)
    }

    // MARK: Web — connecting

    static func web(_ size: Double, _ t: Double, _ o: OrbOpts) -> OrbFrame {
        let cx = size / 2
        let cy = size / 2
        let R = (size / 2) * 0.8 * (o["spread"] ?? 1)
        // the projector carries the radius as its scale, so node vectors stay
        // unit-length and the distances below are in unit-sphere space
        let pt = Projector(yaw: t * 0.12, tilt: 0.32, cx: cx, cy: cy, scale: R)
        let rs = radiusScale(size, o["rsPow"] ?? 0.6)

        let nodeN = count(o, "nodeN", 30)
        let thr = o["thr"] ?? 0.72
        let nodeR = o["nodeR"] ?? 1.4
        let nodeRDepth = o["nodeRDepth"] ?? 1.8
        let lineW = o["lineW"] ?? 0.8

        // nodes: fib lattice + slow noise wander, renormalised to the surface
        var nodes: [(Double, Double, Double)] = []
        nodes.reserveCapacity(below(nodeN))
        for i in 0..<below(nodeN) {
            let fi = Double(i)
            let d = fibDir(i, nodeN)
            let x = d.0 + 0.3 * (vnoise(fi * 0.31 + 9, t * 0.24) - 0.5) * 2
            let y = d.1 + 0.3 * (vnoise(fi * 0.53 + 27, t * 0.21) - 0.5) * 2
            let z = d.2 + 0.3 * (vnoise(fi * 0.77 + 55, t * 0.27) - 0.5) * 2
            let l = (x * x + y * y + z * z).squareRoot()
            nodes.append((x / l, y / l, z / l))
        }

        var lines: [OrbLine] = []
        var dots: [OrbDot] = []

        // edges between close neighbours, alpha by proximity + depth
        for i in 0..<below(nodeN) {
            for j in (i + 1)..<max(i + 1, below(nodeN)) {
                let dx = nodes[i].0 - nodes[j].0
                let dy = nodes[i].1 - nodes[j].1
                let dz = nodes[i].2 - nodes[j].2
                let dist = (dx * dx + dy * dy + dz * dz).squareRoot()
                if dist >= thr { continue }
                let (x1, y1, z1) = pt(nodes[i].0, nodes[i].1, nodes[i].2)
                let (x2, y2, z2) = pt(nodes[j].0, nodes[j].1, nodes[j].2)
                let depth = ((z1 + z2) / 2 + 1) / 2
                lines.append(OrbLine(
                    x1: x1, y1: y1, x2: x2, y2: y2,
                    white: 0.42,
                    a: (1 - dist / thr) * (0.3 + 0.55 * depth),
                    w: max(0.6, lineW * rs)
                ))
            }
        }

        for i in 0..<below(nodeN) {
            let (px, py, z) = pt(nodes[i].0, nodes[i].1, nodes[i].2)
            let depth = (z + 1) / 2
            let pulse = 1 + 0.25 * sin(t * 1.4 + Double(i) * 2.7)
            dots.append(OrbDot(x: px, y: py, z: z, r: (nodeR + nodeRDepth * depth) * pulse * rs,
                               white: 0.55 - 0.45 * depth))
        }

        // signals: bright packets running between re-picked node pairs
        let signals = count(o, "signals", 5)
        for s in 0..<below(signals) {
            let fs = Double(s)
            let seg = (t * 0.55 + fs * 7.31).rounded(.down)
            let a = Int((hashD(seg, fs * 3.1 + 1.7) * nodeN).rounded(.down))
            let b = Int((hashD(seg, fs * 5.7 + 4.2) * nodeN).rounded(.down))
            if a == b { continue }
            let f = frac(t * 0.55 + fs * 7.31)
            let x = lerp(nodes[a].0, nodes[b].0, f)
            let y = lerp(nodes[a].1, nodes[b].1, f)
            let z = lerp(nodes[a].2, nodes[b].2, f)
            let l = max(1e-6, (x * x + y * y + z * z).squareRoot())
            let (px, py, zr) = pt(x / l, y / l, z / l)
            let depth = (zr + 1) / 2
            dots.append(OrbDot(x: px, y: py, z: zr, r: (nodeR * 1.5 + nodeRDepth * depth) * rs,
                               white: 0.05, a: 0.5 + 0.5 * depth))
        }

        return finalize(dots, lines, rMin: o["rMin"] ?? 0.3)
    }

    // MARK: Braid — weaving

    static func braid(_ size: Double, _ t: Double, _ o: OrbOpts) -> OrbFrame {
        let cx = size / 2
        let cy = size / 2
        let R = (size / 2) * 0.76
        let pt = Projector(yaw: t * 0.4, tilt: 0.3, cx: cx, cy: cy, scale: 1)
        let rs = radiusScale(size, o["rsPow"] ?? 0.6)
        let rBase = o["rBase"] ?? 1.2
        let rDepth = o["rDepth"] ?? 1.8

        var dots: [OrbDot] = []
        let ghostN = count(o, "ghostN", 150)
        for i in 0..<below(ghostN) {
            let d = fibDir(i, ghostN)
            let (px, py, z) = pt(d.0 * R, d.1 * R, d.2 * R)
            let depth = (z / R + 1) / 2
            dots.append(OrbDot(x: px, y: py, z: z, r: 0.8 * rs, white: 0.78, a: 0.1 + 0.22 * depth))
        }

        let strandN = count(o, "strandN", 52)
        let turns = o["turns"] ?? 3
        for s in 0..<3 {
            let phase = (Double(s) / 3) * 2 * Double.pi
            for i in 0..<below(strandN) {
                // u walks pole to pole; the frac() drift slides the strand along
                let u = (frac(Double(i) / strandN + t * 0.045) * 2 - 1) * 0.96
                let surf = max(0, 1 - u * u).squareRoot()
                let endFade = min(1, (1 - abs(u)) / 0.1)
                let a = u * Double.pi * turns + phase
                // radial breathing: strands trade places, the over/under of a plait
                let weave = 1 + 0.075 * sin(u * Double.pi * turns * 2 + phase * 2 + t * 0.8)
                let rr = surf * R * weave
                let (px, py, zr) = pt(cos(a) * rr, u * R * weave, sin(a) * rr)
                let depth = (zr / R + 1) / 2
                dots.append(OrbDot(
                    x: px, y: py, z: zr,
                    r: (rBase + rDepth * depth) * rs,
                    white: 0.55 - 0.45 * depth,
                    a: endFade * (0.45 + 0.55 * depth)
                ))
            }
        }
        return finalize(dots, [], rMin: o["rMin"] ?? 0.3)
    }

    // MARK: Ribbon — composing (and ring — breathing, via faceOn)

    static func ribbon(_ size: Double, _ t: Double, _ o: OrbOpts) -> OrbFrame {
        let cx = size / 2
        let cy = size / 2
        let R = (size / 2) * 0.78
        // spin scales the 3D tumble; 0 freezes the band's orientation,
        // leaving only the traveling undulation
        let spin = o["spin"] ?? 1
        let camTilt = 0.3
        let pt = Projector(yaw: t * 0.1 * spin, tilt: camTilt, cx: cx, cy: cy, scale: 1)
        let rs = radiusScale(size, o["rsPow"] ?? 0.6)
        let faceOn = (o["faceOn"] ?? 0) != 0
        let wobMul = o["wobMul"] ?? 1
        let rBase = o["rBase"] ?? 1.1
        let rDepth = o["rDepth"] ?? 1.7

        var dots: [OrbDot] = []
        let ghostN = count(o, "ghostN", 150)
        for i in 0..<below(ghostN) {
            let d = fibDir(i, ghostN)
            let (px, py, z) = pt(d.0 * R, d.1 * R, d.2 * R)
            let depth = (z / R + 1) / 2
            dots.append(OrbDot(x: px, y: py, z: z, r: 0.8 * rs, white: 0.78, a: 0.1 + 0.22 * depth))
        }

        // The band plane, precessing (frozen when spin = 0). Face-on sets
        // ta = -camTilt so the band reads as a true circle, not an ellipse.
        let ya = t * 0.24 * spin
        let ta = faceOn ? -camTilt : 0.55 + 0.3 * sin(t * 0.18) * spin
        let ux = cos(ya)
        let uy = 0.0
        let uz = sin(ya)
        let vx = -uz * sin(ta)
        let vy = cos(ta)
        let vz = ux * sin(ta)
        // plane normal n = u × v
        let nx = uy * vz - uz * vy
        let ny = uz * vx - ux * vz
        let nz = ux * vy - uy * vx

        // Radial lobes swell past R, so face-on pulls the base radius in by
        // most of the wobble amplitude to keep the silhouette in frame.
        let wobAmp = 0.23 * wobMul
        let baseR = faceOn ? R / (1 + 0.85 * wobAmp) : R

        let baseLanes = o["lanes"] ?? 5
        let segs = count(o, "segs", 88)
        let lanes = max(1, Int(jsRound(baseLanes * (o["bandMul"] ?? 1))))
        let mid = Double(lanes - 1) / 2
        dots.reserveCapacity(dots.count + lanes * below(segs))
        for w in 0..<lanes {
            let fw = Double(w)
            let laneOff = (fw - mid) * 0.075
            let edge = abs(fw - mid) / max(1, mid)
            for k in 0..<below(segs) {
                let a = (Double(k) / segs) * 2 * Double.pi
                // two traveling waves along the band; wobMul scales the
                // deformation, 0 is a clean band
                let wob = (0.16 * sin(a * 3 - t * 1.7 + fw * 0.22) + 0.07 * sin(a * 5 + t * 1.1)) * wobMul
                // ribbon wobbles out of plane (renormalised back onto the
                // sphere); face-on modulates the in-plane radius instead
                let radial = faceOn ? 1 + wob : 1
                let off = faceOn ? laneOff : laneOff + wob
                let x = ux * cos(a) + vx * sin(a) + nx * off
                let y = uy * cos(a) + vy * sin(a) + ny * off
                let z = uz * cos(a) + vz * sin(a) + nz * off
                let l = (x * x + y * y + z * z).squareRoot()
                let rr = baseR * radial
                let (px, py, zr) = pt((x / l) * rr, (y / l) * rr, (z / l) * rr)
                let depth = (zr / R + 1) / 2
                dots.append(OrbDot(
                    x: px, y: py, z: zr,
                    r: (rBase + rDepth * depth) * (1 - 0.25 * edge) * rs,
                    white: 0.52 - 0.44 * depth + 0.18 * edge,
                    a: 0.4 + 0.6 * depth
                ))
            }
        }
        return finalize(dots, [], rMin: o["rMin"] ?? 0.3)
    }

    // MARK: Morph — shaping

    // Each shape is a closed path parameterised by arc length (top-centre
    // start, clockwise). Every frame blends the two neighbouring paths, then
    // lays the dots EVENLY along the blended outline, so spacing stays
    // uniform through holds and transitions alike.

    private struct PolyPath {
        let verts: [(Double, Double)]
        let lengths: [Double]
        let total: Double

        init(_ verts: [(Double, Double)]) {
            self.verts = verts
            var lengths: [Double] = []
            var total = 0.0
            for i in 0..<verts.count {
                let a = verts[i]
                let b = verts[(i + 1) % verts.count]
                let l = hypot(b.0 - a.0, b.1 - a.1)
                lengths.append(l)
                total += l
            }
            self.lengths = lengths
            self.total = total
        }

        func at(_ f: Double) -> (Double, Double) {
            var target = f * total
            var i = 0
            while target > lengths[i] && i < verts.count - 1 {
                target -= lengths[i]
                i += 1
            }
            let a = verts[i]
            let b = verts[(i + 1) % verts.count]
            let ff = lengths[i] != 0 ? min(1, target / lengths[i]) : 0
            return (a.0 + (b.0 - a.0) * ff, a.1 + (b.1 - a.1) * ff)
        }
    }

    private static let triangle = PolyPath([(0.0, -0.26), (0.24, 0.16), (-0.24, 0.16)])
    // 5-vertex walk so the path STARTS at top-centre like the other shapes
    private static let square = PolyPath([(0, -0.2), (0.2, -0.2), (0.2, 0.2), (-0.2, 0.2), (-0.2, -0.2)])

    private static func shapePoint(_ shape: Int, _ f: Double) -> (Double, Double) {
        switch shape {
        case 0:
            let a = -Double.pi / 2 + f * 2 * Double.pi
            return (cos(a) * 0.24, sin(a) * 0.24)
        case 1: return triangle.at(f)
        default: return square.at(f)
        }
    }

    private static let morphHold = 1.4
    private static let morphTime = 0.9

    static func morph(_ size: Double, _ t: Double, _ o: OrbOpts) -> OrbFrame {
        let K = 3
        let segDur = morphHold + morphTime
        var tc = t.truncatingRemainder(dividingBy: segDur * Double(K))
        if tc < 0 { tc += segDur * Double(K) }
        let k = Int((tc / segDur).rounded(.down))
        let local = tc - Double(k) * segDur
        let m: Double = {
            guard local > morphHold else { return 0 }
            let x = (local - morphHold) / morphTime
            return x * x * (3 - 2 * x)
        }()
        let sprd = o["spread"] ?? 1

        // blend the two shape PATHS at m, then measure the blended outline
        let M = 160
        var pts: [(Double, Double)] = []
        pts.reserveCapacity(M)
        for i in 0..<M {
            let f = Double(i) / Double(M)
            let a = shapePoint(k, f)
            let b = shapePoint((k + 1) % K, f)
            pts.append(((a.0 + (b.0 - a.0) * m) * sprd, (a.1 + (b.1 - a.1) * m) * sprd))
        }
        var L: [Double] = []
        L.reserveCapacity(M)
        var total = 0.0
        for i in 0..<M {
            let a = pts[i]
            let b = pts[(i + 1) % M]
            let l = hypot(b.0 - a.0, b.1 - a.1)
            L.append(l)
            total += l
        }

        // dot radius depends ONLY on rDot; the count sets the gaps. Formed
        // shapes breathe a little (a uniform pulse).
        let n = max(6, Int(jsRound(34 * (o["iconD"] ?? 1))))
        let re = (o["rDot"] ?? 0.021) * 1.35 * sprd
        let pulse = 1 + 0.02 * sin(local * 3.1)

        var dots: [OrbDot] = []
        dots.reserveCapacity(n)
        let c2 = size / 2
        var seg = 0
        var acc = 0.0
        for k2 in 0..<n {
            let target = (Double(k2) / Double(n)) * total
            while acc + L[seg] < target && seg < M - 1 {
                acc += L[seg]
                seg += 1
            }
            let a = pts[seg]
            let b = pts[(seg + 1) % M]
            let f = L[seg] != 0 ? min(1, (target - acc) / L[seg]) : 0
            let x = (a.0 + (b.0 - a.0) * f) * pulse
            let y = (a.1 + (b.1 - a.1) * f) * pulse
            dots.append(OrbDot(x: c2 + x * size, y: c2 + y * size, z: 0,
                               r: max(0.35, re * size), white: 0.1))
        }
        return finalize(dots, [], rMin: o["rMin"] ?? 0.25)
    }
}
