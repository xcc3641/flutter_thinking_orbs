//
//  GoldenTests.swift
//  ThinkingOrbsTests
//
//  Checks the Swift orb engine against the web library's golden vectors
//  (orbs-golden.json, from thinking-orbs `npm run spec`): every preset's
//  resolved options, and every dot and line of every design × size at four
//  frozen instants, to 1e-4.
//
//  Draw order is compared too, with one allowance: dots whose depths tie to
//  within the tolerance may swap. The face-on `breathing` ring puts a whole
//  lane at z ≈ 0, where the web's and Darwin's libm disagree in the last ulp
//  and so sort the tie differently. Tied dots in a lane share ink, radius and
//  alpha, so the swap cannot change a pixel.
//

import Foundation
import Testing
@testable import ThinkingOrbs

private struct Golden: Decodable {
    struct Resolved: Decodable {
        let mode: String
        let speed: Double
        let opts: [String: Double]
    }

    struct Case: Decodable {
        let key: String
        let state: String
        let size: Int
        let t: Double
        let dotCount: Int
        let lineCount: Int
        let dots: [Double]
        let lines: [Double]
    }

    let tolerance: Double
    let resolved: [String: Resolved]
    let cases: [Case]

    static let shared: Golden = {
        let url = Bundle.module.url(forResource: "orbs-golden", withExtension: "json")!
        return try! JSONDecoder().decode(Golden.self, from: Data(contentsOf: url))
    }()
}

struct GoldenTests {

    @Test func presetsResolveExactlyLikeTheWeb() {
        let golden = Golden.shared
        #expect(golden.resolved.count == OrbDesign.allCases.count * OrbSize.allCases.count)
        for design in OrbDesign.allCases {
            for size in OrbSize.allCases {
                let key = "\(design.rawValue)-\(size.rawValue)"
                guard let want = golden.resolved[key] else {
                    Issue.record("golden has no \(key)")
                    continue
                }
                let got = OrbPresets.resolve(design, size)
                #expect(got.mode.rawValue == want.mode, "\(key) mode")
                #expect(got.speed == want.speed, "\(key) speed")
                #expect(Set(got.opts.keys) == Set(want.opts.keys), "\(key) option keys")
                for (name, value) in want.opts {
                    #expect(abs((got.opts[name] ?? .nan) - value) < 1e-12, "\(key).\(name)")
                }
            }
        }
    }

    @Test(arguments: OrbDesign.allCases, OrbSize.allCases)
    func geometryMatchesTheWeb(design: OrbDesign, size: OrbSize) {
        let golden = Golden.shared
        let cases = golden.cases.filter { $0.state == design.rawValue && $0.size == size.rawValue }
        #expect(cases.count == 4)

        for c in cases {
            let frame = OrbPresets.resolve(design, size).frame(size: size.length, t: c.t)
            #expect(frame.dots.count == c.dotCount, "\(c.key) dot count")
            #expect(frame.lines.count == c.lineCount, "\(c.key) line count")
            guard frame.dots.count == c.dotCount, frame.lines.count == c.lineCount else { continue }

            let tol = golden.tolerance
            let want = stride(from: 0, to: c.dots.count, by: 6).map { Array(c.dots[$0..<$0 + 6]) }
            let got = frame.dots.map { [$0.x, $0.y, $0.z, $0.r, $0.white, $0.a] }
            let close: ([Double], [Double]) -> Bool = { a, b in
                zip(a, b).allSatisfy { abs($0 - $1) <= tol }
            }

            var used = [Bool](repeating: false, count: want.count)
            var firstMiss: String?
            for i in got.indices {
                if !used[i], close(got[i], want[i]) {
                    used[i] = true
                    continue
                }
                // not in its own slot: accept only a slot tied with it in depth
                var j = i
                while j > 0, abs(want[j - 1][2] - got[i][2]) <= tol { j -= 1 }
                var matched = false
                while j < want.count, want[j][2] <= got[i][2] + tol {
                    if !used[j], close(got[i], want[j]) {
                        used[j] = true
                        matched = true
                        break
                    }
                    j += 1
                }
                if !matched, firstMiss == nil {
                    firstMiss = "dot \(i): got \(got[i]) want \(want[i])"
                }
            }
            #expect(firstMiss == nil, "\(c.key): \(firstMiss ?? "")")

            for (i, line) in frame.lines.enumerated() {
                let values = [line.x1, line.y1, line.x2, line.y2, line.white, line.a, line.w]
                let expected = Array(c.lines[(i * 7)..<(i * 7 + 7)])
                #expect(close(values, expected), "\(c.key) line \(i)")
            }
        }
    }
}
