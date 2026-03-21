import XCTest
import CoreMedia
@testable import OpenScreen

final class BuiltInPresetsTests: XCTestCase {
    func testPresetCount() {
        XCTAssertEqual(BuiltInPresets.presets.count, 5)
    }

    func testDeterministicUUIDs() {
        let uuids1 = BuiltInPresets.presets.map { $0.id }
        let uuids2 = BuiltInPresets.presets.map { $0.id }

        XCTAssertEqual(uuids1, uuids2, "UUIDs should be deterministic across calls")
    }

    func testAllTransitionTypesRepresented() {
        let types = BuiltInPresets.presets.map { $0.transitionType }
        XCTAssertTrue(types.contains(.crossfade))
        XCTAssertTrue(types.contains(.fadeToColor))
        XCTAssertTrue(types.contains(.wipe))
        XCTAssertTrue(types.contains(.iris))
        XCTAssertTrue(types.contains(.blinds))
    }

    func testQuickDissolvePreset() {
        let quickDissolve = BuiltInPresets.presets.first { $0.name == "Quick Dissolve" }

        XCTAssertNotNil(quickDissolve)
        XCTAssertEqual(quickDissolve?.transitionType, .crossfade)
        XCTAssertEqual(CMTimeGetSeconds(quickDissolve!.duration), 0.5)
    }

    func testWipeLeftPreset() {
        let wipeLeft = BuiltInPresets.presets.first { $0.name == "Wipe Left" }

        XCTAssertNotNil(wipeLeft)
        XCTAssertEqual(wipeLeft?.transitionType, .wipe)

        if case let .wipe(direction, _, _) = wipeLeft?.parameters {
            XCTAssertEqual(direction, .left)
        } else {
            XCTFail("Wipe parameters should be .wipe type")
        }
    }
}
