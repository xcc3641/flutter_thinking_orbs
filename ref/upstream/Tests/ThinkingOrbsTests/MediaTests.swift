//
//  MediaTests.swift
//  ThinkingOrbsTests
//
//  Renders the README's animations frame by frame through the real public
//  views, with the orb clock pinned to each instant, so every GIF is exact and
//  identical run to run. Writes PNG sequences into ORBS_MEDIA_OUT; run it with
//  Scripts/render-media.sh, which turns them into looping GIFs. Skipped
//  otherwise.
//

import Foundation
import ImageIO
import SwiftUI
import Testing
import UniformTypeIdentifiers
@testable import ThinkingOrbs

private let env = ProcessInfo.processInfo.environment

/// GitHub's page colours, so each GIF sits seamlessly on its README theme.
private enum Page: String, CaseIterable {
    case light, dark

    var background: Color {
        switch self {
        case .light: return Color(.sRGB, red: 1, green: 1, blue: 1)
        case .dark: return Color(.sRGB, red: 13 / 255, green: 17 / 255, blue: 23 / 255)
        }
    }

    /// GitHub's zebra stripe, behind every second row of a README table.
    var stripe: Color {
        switch self {
        case .light: return Color(.sRGB, red: 246 / 255, green: 248 / 255, blue: 250 / 255)
        case .dark: return Color(.sRGB, red: 21 / 255, green: 27 / 255, blue: 35 / 255)
        }
    }

    var surface: Color {
        switch self {
        case .light: return Color(.sRGB, red: 246 / 255, green: 248 / 255, blue: 250 / 255)
        case .dark: return Color(.sRGB, red: 22 / 255, green: 27 / 255, blue: 34 / 255)
        }
    }

    var hairline: Color {
        switch self {
        case .light: return Color(.sRGB, red: 208 / 255, green: 215 / 255, blue: 222 / 255)
        case .dark: return Color(.sRGB, red: 48 / 255, green: 54 / 255, blue: 61 / 255)
        }
    }

    var scheme: ColorScheme { self == .dark ? .dark : .light }
}

@MainActor
struct MediaTests {

    /// 30 ms a frame (GIF delays are in centiseconds).
    static let frameStep = 0.03

    /// How one clip loops: `loop` frames from `start` seconds, plus `seam`
    /// frames rendered past the end and crossfaded into the opening, so a
    /// design that never repeats still loops without a jump.
    struct Clip {
        var start = 0.0
        var loop = 134          // 4.02 s
        var seam = 10           // 0.3 s
    }

    /// Designs that do repeat get exactly one cycle. Shaping loops cleanly with
    /// no seam at all. Solving shows its whole scramble and solve, with the
    /// seam placed in the solved rest, where the two ends match.
    static func clip(for design: OrbDesign, size: OrbSize) -> Clip {
        let speed = OrbPresets.resolve(design, size).speed
        switch design {
        case .shaping:
            let cycle = (1.4 + 0.9) * 3 / speed
            return Clip(start: 0, loop: Int((cycle / frameStep).rounded()), seam: 0)
        case .solving:
            let cycle = (2 * 14 * 0.42 + 1.2) / speed
            return Clip(start: 11.9 / speed, loop: Int((cycle / frameStep).rounded()), seam: 10)
        default:
            return Clip()
        }
    }

    @Test(.enabled(if: env["ORBS_MEDIA_OUT"] != nil))
    func rendersReadmeMedia() throws {
        let root = URL(fileURLWithPath: env["ORBS_MEDIA_OUT"]!)

        for page in Page.allCases {
            // one clip per design and size, for the table
            // (every second row of the README table sits on GitHub's stripe)
            for (row, design) in OrbDesign.allCases.enumerated() {
                for size in OrbSize.allCases {
                    let name = "\(design.rawValue)-\(size == .regular ? "regular" : "small")-\(page.rawValue)"
                    try render(name, into: root, clip: Self.clip(for: design, size: size)) {
                        ThinkingOrb(design, size: size)
                            .frame(width: size.points, height: size.points)
                            .background(row.isMultiple(of: 2) ? page.background : page.stripe)
                    }
                }
            }

            // the banner: all nine side by side
            try render("banner-\(page.rawValue)", into: root, scale: 2) {
                HStack(spacing: 0) {
                    ForEach(OrbDesign.allCases) { design in
                        VStack(spacing: 10) {
                            ThinkingOrb(design)
                            Text(design.title)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .frame(width: 92)
                    }
                }
                .padding(.vertical, 22)
                .padding(.horizontal, 18)
                .background(page.background)
            }

            // labels in context: a status pill and inline chips
            try render("labels-\(page.rawValue)", into: root, scale: 2) {
                VStack(alignment: .leading, spacing: 14) {
                    ThinkingOrbLabel("Thinking…", design: .composing, size: .regular, diameter: 48)
                        .font(.system(size: 19))
                        .padding(7)
                        .padding(.trailing, 22)
                        .background(page.surface, in: .capsule)
                        .overlay(Capsule().stroke(page.hairline, lineWidth: 1))
                    HStack(spacing: 8) {
                        chip("Searching the web…", .searching, page)
                        chip("Reading 14 files…", .working, page)
                    }
                    HStack(spacing: 8) {
                        chip("Planning next steps…", .weaving, page)
                        chip("Calling tools…", .connecting, page)
                    }
                }
                .padding(22)
                .background(page.background)
            }
        }
    }

    private func chip(_ title: String, _ design: OrbDesign, _ page: Page) -> some View {
        ThinkingOrbLabel(title, design: design)
            .font(.system(size: 13))
            .padding(.leading, 8)
            .padding(.trailing, 13)
            .frame(height: 34)
            .background(page.surface, in: .capsule)
            .overlay(Capsule().stroke(page.hairline, lineWidth: 1))
    }

    /// Renders a clip's frames with the clock pinned, as `<name>/0000.png` …,
    /// in the page's colour scheme, with a `clip.json` saying how it loops.
    private func render<Content: View>(_ name: String, into root: URL, scale: CGFloat = 3, clip: Clip = Clip(),
                                       @ViewBuilder content: () -> Content) throws {
        let dir = root.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try #"{"loop": \#(clip.loop), "seam": \#(clip.seam)}"#.write(
            to: dir.appendingPathComponent("clip.json"), atomically: true, encoding: .utf8)
        let scheme: ColorScheme = name.hasSuffix("-dark") ? .dark : .light
        let view = content()
        for i in 0..<(clip.loop + clip.seam) {
            let renderer = ImageRenderer(content: view
                .environment(\.colorScheme, scheme)
                .environment(\.orbClockOverride, clip.start + Double(i) * Self.frameStep))
            renderer.scale = scale
            let image = try #require(renderer.cgImage, "\(name) frame \(i)")
            let url = dir.appendingPathComponent(String(format: "%04d.png", i))
            let dest = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
            CGImageDestinationAddImage(dest, image, nil)
            #expect(CGImageDestinationFinalize(dest))
        }
    }
}
