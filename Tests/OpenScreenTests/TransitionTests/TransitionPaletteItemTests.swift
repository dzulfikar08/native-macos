import XCTest
import AppKit
@testable import OpenScreen

final class TransitionPaletteItemTests: XCTestCase {
    func testDisplayName() {
        let preset = TransitionPreset(
            id: UUID(),
            name: "Quick Dissolve",
            isBuiltIn: true,
            transitionType: .crossfade,
            parameters: .crossfade,
            duration: CMTime(seconds: 0.5, preferredTimescale: 600)
        )

        let item = TransitionPaletteItem(
            preset: preset,
            category: .basic
        )

        XCTAssertTrue(item.displayName.contains("Quick Dissolve"))
    }

    func testIconName() {
        let preset = TransitionPreset(
            id: UUID(),
            name: "Wipe Left",
            isBuiltIn: true,
            transitionType: .wipe,
            parameters: .wipe(direction: .left, softness: 0.2, borderWidth: 0),
            duration: CMTime(seconds: 1.0, preferredTimescale: 600)
        )

        let item = TransitionPaletteItem(
            preset: preset,
            category: .directional
        )

        XCTAssertEqual(item.iconName, "arrow.right.circle.fill")
    }

    func testCategoryColor() {
        let item = TransitionPaletteItem(
            preset: TransitionPreset(
                id: UUID(),
                name: "Test",
                isBuiltIn: true,
                transitionType: .iris,
                parameters: .iris(shape: .circle, position: .zero, softness: 0.3),
                duration: CMTime(seconds: 1.0, preferredTimescale: 600)
            ),
            category: .shape
        )

        XCTAssertEqual(item.categoryColor, .systemOrange)
    }
}
