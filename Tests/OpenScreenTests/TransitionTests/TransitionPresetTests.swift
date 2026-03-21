import XCTest
import CoreMedia
@testable import OpenScreen

final class TransitionPresetTests: XCTestCase {
    func testPresetInitialization() {
        let preset = TransitionPreset(
            id: UUID(),
            name: "Quick Dissolve",
            isBuiltIn: true,
            transitionType: .crossfade,
            parameters: .crossfade,
            duration: CMTime(seconds: 0.5, preferredTimescale: 600)
        )

        XCTAssertEqual(preset.name, "Quick Dissolve")
        XCTAssertTrue(preset.isBuiltIn)
        XCTAssertEqual(preset.transitionType, .crossfade)
    }

    func testMakeTransition() {
        let preset = TransitionPreset(
            id: UUID(),
            name: "Test",
            isBuiltIn: true,
            transitionType: .wipe,
            parameters: .wipe(direction: .left, softness: 0.2, borderWidth: 0),
            duration: CMTime(seconds: 1.0, preferredTimescale: 600)
        )

        let leadingID = UUID()
        let trailingID = UUID()
        let transition = preset.makeTransition(
            leadingClipID: leadingID,
            trailingClipID: trailingID
        )

        XCTAssertEqual(transition.type, .wipe)
        XCTAssertEqual(transition.leadingClipID, leadingID)
        XCTAssertEqual(transition.trailingClipID, trailingID)
    }

    func testCodable() {
        let preset = TransitionPreset(
            id: UUID(),
            name: "Test Preset",
            isBuiltIn: false,
            transitionType: .iris,
            parameters: .iris(shape: .circle, position: CGPoint(x: 0.5, y: 0.5), softness: 0.3),
            duration: CMTime(seconds: 1.5, preferredTimescale: 600)
        )

        let encoded = try! JSONEncoder().encode(preset)
        let decoded = try! JSONDecoder().decode(TransitionPreset.self, from: encoded)

        XCTAssertEqual(preset.id, decoded.id)
        XCTAssertEqual(preset.name, decoded.name)
        XCTAssertEqual(preset.transitionType, decoded.transitionType)
    }
}
