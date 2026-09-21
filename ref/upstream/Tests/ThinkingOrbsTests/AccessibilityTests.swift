//
//  AccessibilityTests.swift
//  ThinkingOrbsTests
//
//  What VoiceOver hears, read from the real accessibility tree on iPhone.
//  SwiftUI only builds that tree while application accessibility is on: it is
//  under XCUITest and VoiceOver, and on a simulator after
//  `xcrun simctl spawn <udid> defaults write com.apple.Accessibility
//  ApplicationAccessibilityEnabled -bool true`. Without it the tree is empty
//  and this test has nothing to check, so it returns without asserting.
//

#if canImport(UIKit) && !os(watchOS)
import SwiftUI
import Testing
import UIKit
import ThinkingOrbs

@MainActor
struct AccessibilityTests {

    /// Labels SwiftUI exposes for a hosted view, found by walking the tree.
    private func labels(of view: some View) -> [String] {
        let host = UIHostingController(rootView: view.frame(width: 200, height: 120))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 200, height: 120))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))

        var found: [String] = []
        func walk(_ node: Any, depth: Int) {
            guard depth < 12, let object = node as? NSObject else { return }
            if object.isAccessibilityElement, let label = object.accessibilityLabel, !label.isEmpty {
                found.append(label)
            }
            if let elements = object.accessibilityElements {
                elements.forEach { walk($0, depth: depth + 1) }
            } else if object.accessibilityElementCount() > 0, object.accessibilityElementCount() != NSNotFound {
                for i in 0..<object.accessibilityElementCount() {
                    if let child = object.accessibilityElement(at: i) { walk(child, depth: depth + 1) }
                }
            }
            if let view = object as? UIView { view.subviews.forEach { walk($0, depth: depth + 1) } }
        }
        walk(host.view as Any, depth: 0)
        window.isHidden = true
        return found
    }

    @Test func voiceOverHearsOneClearLabel() {
        let plain = labels(of: ThinkingOrb(.searching))
        guard !plain.isEmpty else { return }   // accessibility is off: nothing to read
        #expect(plain == ["Searching…"])
        #expect(labels(of: ThinkingOrb(.breathing)) == ["Thinking…"])
        // a caller's own label wins over the design's
        #expect(labels(of: ThinkingOrb(.searching).accessibilityLabel("Looking up flights…")) == ["Looking up flights…"])
        // a label reads as one element: its title, not "image" plus the text
        #expect(labels(of: ThinkingOrbLabel("Reading 14 files…", design: .working)) == ["Reading 14 files…"])
    }
}
#endif
