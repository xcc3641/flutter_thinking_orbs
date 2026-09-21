//
//  ReadmeSnippetTests.swift
//  ThinkingOrbsTests
//
//  Every code snippet in README.md, compiled against the PUBLIC API only (a
//  plain import, not @testable), and rendered once. If the README and the
//  package ever disagree, this file stops compiling.
//

import SwiftUI
import Testing
import ThinkingOrbs

// MARK: - Snippets

private struct QuickStart: View {
    var body: some View {
        ThinkingOrbLabel("Searching the web…", design: .searching)
    }
}

private struct Sizes: View {
    var body: some View {
        VStack {
            ThinkingOrb(.working)                  // .regular: 64 pt
            ThinkingOrb(.working, size: .small)    // .small: 20 pt
            ThinkingOrb(.solving, diameter: 56)    // the 64 pt design, drawn at 56 pt
        }
    }
}

private struct Labels: View {
    var body: some View {
        VStack {
            ThinkingOrbLabel("Searching the web…", design: .searching)

            ThinkingOrbLabel("Thinking…", design: .composing, size: .regular, diameter: 48)
                .font(.title3)
                .padding(8)
                .padding(.trailing, 20)
                .background(.thinMaterial, in: .capsule)

            Text("Composing a reply…")
                .thinkingShimmer()
        }
    }
}

private enum AgentPhase: Hashable {
    case idle, searching, reasoning, callingTools, writing

    var orb: OrbDesign {
        switch self {
        case .idle: .breathing
        case .searching: .searching
        case .reasoning: .solving
        case .callingTools: .connecting
        case .writing: .composing
        }
    }
}

private struct AgentStatus: View {
    let phase: AgentPhase

    var body: some View {
        ZStack {   // both orbs share one slot while they crossfade
            ThinkingOrb(phase.orb)
                .id(phase.orb)
                .transition(.opacity.animation(.easeInOut(duration: 0.25)))
        }
    }
}

private struct TypingBubble: View {
    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            ThinkingOrb(.composing, diameter: 36)
            Text("Writing a reply…")
                .thinkingShimmer()
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.fill.tertiary, in: .rect(cornerRadius: 18))
        }
    }
}

private struct ToolbarStatus: View {
    var body: some View {
        NavigationStack {
            Text("Inbox")
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        ThinkingOrbLabel("Syncing…", design: .connecting)
                            .font(.subheadline)
                    }
                }
        }
    }
}

private struct GenerateButton: View {
    @State private var isGenerating = false

    var body: some View {
        Button {
            isGenerating = true
        } label: {
            if isGenerating {
                ThinkingOrbLabel("Generating…", design: .shaping)
            } else {
                Label("Generate", systemImage: "sparkles")
            }
        }
        .buttonStyle(.bordered)
    }
}

private struct ModelLoading: View {
    var body: some View {
        ContentUnavailableView {
            ThinkingOrb(.breathing)
        } description: {
            Text("Warming up the model…")
        }
    }
}

private struct ListRow: View {
    var body: some View {
        List {
            LabeledContent("Indexing photos") {
                ThinkingOrb(.searching, size: .small)
            }
        }
    }
}

private struct Theme: View {
    var body: some View {
        ThinkingOrb(.weaving)
            .environment(\.colorScheme, .dark)   // light dots, for a dark card in a light app
    }
}

private struct SpeedAndPause: View {
    let isRecording: Bool

    var body: some View {
        VStack {
            ThinkingOrb(.listening, speed: 1.5)
            ThinkingOrb(.listening, isPaused: !isRecording)
        }
    }
}

private struct LocalizedLabels: View {
    let modelOutput: String

    var body: some View {
        VStack {
            ThinkingOrbLabel("Searching the web…", design: .searching)                   // localized, like Text
            ThinkingOrbLabel("status.syncing", tableName: "Agent", design: .connecting)   // from your own table
            ThinkingOrbLabel(modelOutput, design: .composing)                             // a String shows as-is
        }
    }
}

private struct CustomLabel: View {
    var body: some View {
        ThinkingOrb(.searching)
            .accessibilityLabel("Looking up flights…")
    }
}

private func drawItYourself(seconds: Double = 2.5) -> Int {
    let frame = OrbDesign.connecting.frame(size: .regular, at: seconds)

    var marks = 0
    for line in frame.lines {       // draw edges first
        _ = (line.x1, line.y1, line.x2, line.y2, line.w)
        _ = (line.white, line.a)    // ink and opacity, as for dots
        marks += 1
    }
    for dot in frame.dots {         // then dots, far to near
        _ = (dot.x, dot.y, dot.r)   // points, in a 64 × 64 box
        _ = (dot.white, dot.a)      // ink (0 is darkest) and opacity
        marks += 1
    }
    return marks
}

private struct AllDesigns: View {
    var body: some View {
        ForEach(OrbDesign.allCases) { design in
            Label {
                Text(design.title)
            } icon: {
                ThinkingOrb(design, size: .small)
            }
        }
    }
}

// MARK: - Render them

@MainActor
struct ReadmeSnippetTests {

    @Test func everySnippetRenders() {
        func renders(_ view: some View) -> Bool {
            let renderer = ImageRenderer(content: view.frame(width: 320, height: 240))
            return renderer.cgImage != nil
        }
        #expect(renders(QuickStart()))
        #expect(renders(Sizes()))
        #expect(renders(Labels()))
        #expect(renders(AgentStatus(phase: .reasoning)))
        #expect(renders(TypingBubble()))
        #expect(renders(ToolbarStatus()))
        #expect(renders(GenerateButton()))
        #expect(renders(ModelLoading()))
        #expect(renders(ListRow()))
        #expect(renders(Theme()))
        #expect(renders(SpeedAndPause(isRecording: true)))
        #expect(renders(CustomLabel()))
        #expect(renders(LocalizedLabels(modelOutput: "Drafting the summary…")))
        #expect(renders(AllDesigns()))
        #expect(drawItYourself() > 40)
    }
}
