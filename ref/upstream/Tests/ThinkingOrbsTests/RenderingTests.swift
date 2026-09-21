//
//  RenderingTests.swift
//  ThinkingOrbsTests
//
//  1. A contact sheet of every design × size × ink × instant, drawn by the
//     real Canvas path at 2x, to pixel-diff against the same sheet painted by
//     Chrome's 2D canvas (ORB_SHEET_OUT).
//  2. Isolated circles and lines at every radius the designs use, to tell
//     rasteriser antialiasing apart from any colour or alpha mistake
//     (ORB_PRIMS_IN / ORB_PRIMS_OUT).
//  3. A frame budget: engine and raster time per frame, per design. Runs
//     everywhere, and is the one worth reading on a real iPhone.
//

import Foundation
import ImageIO
import SwiftUI
import Testing
import UniformTypeIdentifiers
@testable import ThinkingOrbs

private let env = ProcessInfo.processInfo.environment

struct RenderingTests {

    // MARK: - 2. Contact sheet for pixel parity

    /// Same layout as the Chrome sheet: 16 columns (dark then light; 64 then
    /// 20; t = 0.6, 1.7, 3.3, 5.1) × 9 state rows, 80-pt tiles, the orb
    /// centred at its preset size on pure black or white, rendered at 2x.
    @Test(.enabled(if: env["ORB_SHEET_OUT"] != nil))
    @MainActor
    func rendersPixelParitySheet() throws {
        let times = [0.6, 1.7, 3.3, 5.1]
        var columns: [(dark: Bool, size: OrbSize, t: Double)] = []
        for dark in [true, false] {
            for size in [OrbSize.regular, .small] {
                for t in times { columns.append((dark, size, t)) }
            }
        }
        let sheet = ZStack(alignment: .topLeading) {
            Color(.sRGB, white: 0.5, opacity: 1)
            ForEach(Array(columns.enumerated()), id: \.offset) { col, c in
                ForEach(Array(OrbDesign.allCases.enumerated()), id: \.offset) { row, design in
                    ZStack {
                        Color(.sRGB, white: c.dark ? 0 : 1, opacity: 1)
                        OrbCanvas(resolved: OrbPresets.resolve(design, c.size), size: c.size, t: c.t, dark: c.dark)
                            .frame(width: c.size.points, height: c.size.points)
                    }
                    .frame(width: 80, height: 80)
                    .offset(x: CGFloat(col * 80), y: CGFloat(row * 80))
                }
            }
        }
        .frame(width: 1280, height: 720, alignment: .topLeading)

        let renderer = ImageRenderer(content: sheet)
        renderer.scale = 2
        let image = try #require(renderer.cgImage)

        // normalise to 8-bit sRGB so the diff compares like with like
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        let ctx = try #require(CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
                                         bytesPerRow: 0, space: space,
                                         bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let flat = try #require(ctx.makeImage())
        let url = URL(fileURLWithPath: env["ORB_SHEET_OUT"]!)
        let dest = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(dest, flat, nil)
        #expect(CGImageDestinationFinalize(dest))
        #expect(flat.width == 2560 && flat.height == 1440)
    }

    /// Isolated circles and lines at every radius and width the orbs use, drawn
    /// through the same paint routine, to separate rasteriser antialiasing
    /// from any colour or alpha mistake. Mirrors the Chrome page that paints
    /// prims.json: a dark canvas above a light one, W × H points each, at 2x.
    @Test(.enabled(if: env["ORB_PRIMS_IN"] != nil && env["ORB_PRIMS_OUT"] != nil))
    @MainActor
    func rendersPrimitiveSheet() throws {
        struct Prims: Decodable {
            struct D: Decodable { let x, y, r, white: Double; let a: Double? }
            struct L: Decodable { let x1, y1, x2, y2, white, w: Double; let a: Double? }
            let W: Double
            let H: Double
            let dots: [D]
            let lines: [L]
        }
        let p = try JSONDecoder().decode(Prims.self, from: Data(contentsOf: URL(fileURLWithPath: env["ORB_PRIMS_IN"]!)))
        let frame = OrbFrame(
            dots: p.dots.map { OrbDot(x: $0.x, y: $0.y, z: 0, r: $0.r, white: $0.white, a: $0.a ?? 1) },
            lines: p.lines.map { OrbLine(x1: $0.x1, y1: $0.y1, x2: $0.x2, y2: $0.y2, white: $0.white, a: $0.a ?? 1, w: $0.w) }
        )
        let sheet = VStack(spacing: 0) {
            ForEach([true, false], id: \.self) { dark in
                Canvas { context, _ in OrbCanvas.paint(frame, dark: dark, in: &context) }
                    .frame(width: p.W, height: p.H)
                    .background(Color(.sRGB, white: dark ? 0 : 1, opacity: 1))
            }
        }
        let renderer = ImageRenderer(content: sheet)
        renderer.scale = 2
        let image = try #require(renderer.cgImage)
        let url = URL(fileURLWithPath: env["ORB_PRIMS_OUT"]!)
        let dest = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(dest, image, nil)
        #expect(CGImageDestinationFinalize(dest))
    }

    // MARK: - 3. Frame budget

    /// Times the geometry for every state at both sizes, and the Canvas raster
    /// of one frame at 3x. The budget is generous (a 120 Hz frame is 8.3 ms and
    /// a page shows many orbs); the printed table is the real result.
    @Test @MainActor
    func frameBudget() throws {
        let clock = ContinuousClock()
        var table: [String] = ["state        size  dots  engine µs  raster µs"]
        for design in OrbDesign.allCases {
            for size in OrbSize.allCases {
                let resolved = OrbPresets.resolve(design, size)
                let n = 240
                var dotCount = 0
                let engine = clock.measure {
                    for i in 0..<n {
                        dotCount = resolved.frame(size: size.length, t: Double(i) / 60).dots.count
                    }
                }
                let rasterN = 30
                let raster = clock.measure {
                    for i in 0..<rasterN {
                        let r = ImageRenderer(content: OrbCanvas(resolved: resolved, size: size, t: Double(i) / 60, dark: false)
                            .frame(width: size.points, height: size.points))
                        r.scale = 3
                        _ = r.cgImage
                    }
                }
                let engineMicros = Double(engine.components.attoseconds) / 1e12 / Double(n)
                    + Double(engine.components.seconds) * 1e6 / Double(n)
                let rasterMicros = Double(raster.components.attoseconds) / 1e12 / Double(rasterN)
                    + Double(raster.components.seconds) * 1e6 / Double(rasterN)
                table.append(String(format: "%-12@ %4d  %4d  %9.1f  %9.1f",
                                    design.rawValue as NSString, size.rawValue, dotCount, engineMicros, rasterMicros))
                #expect(engineMicros < 4_000, "\(design) \(size.rawValue): \(engineMicros) µs per frame")
            }
        }
        let text = table.joined(separator: "\n")
        print(text)
        if let out = env["ORB_BUDGET_OUT"] {
            try? text.write(toFile: out, atomically: true, encoding: .utf8)
        }
        Attachment.record(text, named: "frame-budget.txt")
    }
}
