//
//  SweepTests.swift
//  ThinkingOrbsTests
//
//  A dense differential sweep against the ORIGINAL TypeScript engine: the web
//  engine streams its frames (raw little-endian Float64) into a FIFO on the
//  host, and this test recomputes every one with the Swift engine and
//  compares dot for dot. Run it with Scripts/differential-sweep.sh, which
//  fetches the upstream engine at a pinned commit, starts the stream and runs
//  this test on an iPhone simulator. Skipped otherwise.
//

import Foundation
import Testing
@testable import ThinkingOrbs

private let env = ProcessInfo.processInfo.environment

// MARK: - 1. Differential sweep

private struct SweepSpec: Decodable {
    struct Case: Decodable {
        let name: String
        let state: String?
        let mode: String
        let size: Double
        let opts: [String: Double]
        let ts: [Double]
    }

    struct ScaleTest: Decodable {
        let mode: String
        let scale: Double
        let counts: [String: Double]
        let radii: [String: Double]
    }

    struct Resolved: Decodable {
        let mode: String
        let speed: Double
        let opts: [String: Double]
    }

    let cases: [Case]
    let scaleTests: [ScaleTest]
    let resolved: [String: Resolved]
    let base: [String: [String: Double]]
}

/// Reads the web engine's Float64 stream.
private final class DoubleStream {
    private let file: UnsafeMutablePointer<FILE>
    private var buffer = [Double](repeating: 0, count: 1 << 16)

    init?(path: String) {
        guard let f = fopen(path, "rb") else { return nil }
        file = f
    }

    deinit { fclose(file) }

    func read(_ n: Int) -> [Double]? {
        if buffer.count < n { buffer = [Double](repeating: 0, count: n) }
        var got = 0
        let ok = buffer.withUnsafeMutableBytes { raw -> Bool in
            while got < n {
                let r = fread(raw.baseAddress! + got * 8, 8, n - got, file)
                if r == 0 { return false }
                got += r
            }
            return true
        }
        return ok ? Array(buffer[0..<n]) : nil
    }
}

struct SweepTests {

    @Test(.enabled(if: env["ORB_SWEEP_SPEC"] != nil && env["ORB_SWEEP_STREAM"] != nil))
    func denseSweepMatchesTheWebEngine() throws {
        let tol = 1e-6
        let zTie = 1e-9
        let spec = try JSONDecoder().decode(
            SweepSpec.self, from: Data(contentsOf: URL(fileURLWithPath: env["ORB_SWEEP_SPEC"]!)))
        var report: [String] = []
        defer {
            if let out = env["ORB_SWEEP_REPORT"] {
                try? report.joined(separator: "\n").write(toFile: out, atomically: true, encoding: .utf8)
            }
        }

        // option machinery, bit for bit
        func sameOpts(_ a: OrbOpts, _ b: [String: Double]) -> String? {
            if Set(a.keys) != Set(b.keys) { return "keys \(a.keys.sorted()) vs \(b.keys.sorted())" }
            for (k, v) in b where a[k]! != v { return "\(k): swift \(a[k]!) js \(v)" }
            return nil
        }
        var optFailures = 0
        for (m, js) in spec.base {
            if let msg = sameOpts(OrbPresets.base(OrbMode(rawValue: m)!), js) {
                optFailures += 1
                report.append("BASE \(m): \(msg)")
            }
        }
        for (key, js) in spec.resolved {
            let p = key.split(separator: "-")
            let r = OrbPresets.resolve(OrbDesign(rawValue: String(p[0]))!, OrbSize(rawValue: Int(p[1])!)!)
            if r.mode.rawValue != js.mode || r.speed != js.speed { optFailures += 1; report.append("RESOLVE \(key) mode/speed") }
            if let msg = sameOpts(r.opts, js.opts) { optFailures += 1; report.append("RESOLVE \(key): \(msg)") }
        }
        for st in spec.scaleTests {
            let base = OrbPresets.base(OrbMode(rawValue: st.mode)!)
            if let msg = sameOpts(OrbPresets.scaleCounts(base, st.scale), st.counts) {
                optFailures += 1
                report.append("SCALECOUNTS \(st.mode) \(st.scale): \(msg)")
            }
            if let msg = sameOpts(OrbPresets.scaleRadii(base, st.scale), st.radii) {
                optFailures += 1
                report.append("SCALERADII \(st.mode) \(st.scale): \(msg)")
            }
        }
        report.append("options: \(spec.base.count) base, \(spec.resolved.count) resolved, \(spec.scaleTests.count) scale pairs -> \(optFailures) mismatches")
        #expect(optFailures == 0)

        // frames
        let stream = try #require(DoubleStream(path: env["ORB_SWEEP_STREAM"]!))
        var frames = 0, dots = 0, lines = 0, divergent = 0, tieGroups = 0, jsThrew = 0
        var worst = 0.0
        var worstAt = ""

        for c in spec.cases {
            let mode: OrbMode
            let opts: OrbOpts
            if let s = c.state {
                let r = OrbPresets.resolve(OrbDesign(rawValue: s)!, OrbSize(rawValue: Int(c.size))!)
                mode = r.mode
                opts = r.opts
            } else {
                mode = OrbMode(rawValue: c.mode)!
                opts = c.opts
            }
            var caseWorst = 0.0, caseDivergent = 0, caseTies = 0
            var details: [String] = []

            for t in c.ts {
                let header = try #require(stream.read(2), "stream ended early")
                let nd = Int(header[0]), nl = Int(header[1])
                let f = OrbEngine.frame(mode, size: c.size, t: t, opts: opts)
                if nd < 0 {
                    jsThrew += 1
                    continue
                }
                let jd = try #require(nd > 0 ? stream.read(nd * 6) : [], "stream ended early")
                let jl = try #require(nl > 0 ? stream.read(nl * 7) : [], "stream ended early")
                frames += 1
                dots += nd
                lines += nl

                var bad: [String] = []
                if f.dots.count != nd || f.lines.count != nl {
                    bad.append("count dots \(f.dots.count)/\(nd) lines \(f.lines.count)/\(nl)")
                }
                if f.dots.count == nd {
                    var sd = [Double]()
                    sd.reserveCapacity(nd * 6)
                    for d in f.dots { sd += [d.x, d.y, d.z, d.r, d.white, d.a] }
                    func err(_ i: Int, _ j: Int) -> Double {
                        var m = 0.0
                        for k in 0..<6 {
                            let e = abs(sd[j * 6 + k] - jd[i * 6 + k])
                            m = e.isNaN ? .infinity : max(m, e)
                        }
                        return m
                    }
                    var g = 0
                    while g < nd {
                        // a run of dots whose depths tie may come out in any order
                        var h = g + 1
                        while h < nd, abs(jd[h * 6 + 2] - jd[(h - 1) * 6 + 2]) <= zTie { h += 1 }
                        let direct = (g..<h).map { err($0, $0) }
                        if direct.allSatisfy({ $0 <= tol }) {
                            caseWorst = max(caseWorst, direct.max() ?? 0)
                        } else if h - g == 1 {
                            bad.append("dot \(g) |d|=\(direct[0])")
                        } else {
                            var used = Set<Int>()
                            var ok = true
                            for i in g..<h {
                                let best = (g..<h).filter { !used.contains($0) }.min { err(i, $0) < err(i, $1) }
                                guard let j = best, err(i, j) <= tol else { ok = false; break }
                                used.insert(j)
                                caseWorst = max(caseWorst, err(i, j))
                            }
                            if ok { caseTies += 1 } else { bad.append("tie group \(g)..<\(h) unmatched") }
                        }
                        g = h
                    }
                }
                if f.lines.count == nl {
                    for (i, l) in f.lines.enumerated() {
                        let s = [l.x1, l.y1, l.x2, l.y2, l.white, l.a, l.w]
                        for k in 0..<7 {
                            let e = abs(s[k] - jl[i * 7 + k])
                            caseWorst = max(caseWorst, e)
                            if e > tol || e.isNaN { bad.append("line \(i).\(k) |d|=\(e)"); break }
                        }
                    }
                }
                if !bad.isEmpty {
                    caseDivergent += 1
                    if details.count < 4 { details.append("  t=\(t): " + bad.prefix(3).joined(separator: " | ")) }
                }
            }
            divergent += caseDivergent
            tieGroups += caseTies
            if caseWorst > worst { worst = caseWorst; worstAt = c.name }
            report.append("\(c.name.padding(toLength: 24, withPad: " ", startingAt: 0)) frames=\(c.ts.count) maxErr=\(String(format: "%.2e", caseWorst)) divergent=\(caseDivergent) tieGroups=\(caseTies)")
            report += details
        }
        report.append("TOTAL frames=\(frames) dots=\(dots) lines=\(lines) divergent=\(divergent) tieGroups=\(tieGroups) jsThrew=\(jsThrew) maxErr=\(worst) at \(worstAt)")
        #expect(divergent == 0, "\(divergent) frames diverge from the web engine")
    }
}
