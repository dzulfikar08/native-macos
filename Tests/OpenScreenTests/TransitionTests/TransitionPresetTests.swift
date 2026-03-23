import XCTest
import CoreMedia
@testable import OpenScreen

final class TransitionPresetTests: XCTestCase {

    func testPresetWithFolderAndFavorite() {
        let preset = TransitionPreset(
            name: "Test Preset",
            folder: "My Folder",
            isFavorite: true,
            transitionType: .crossfade,
            parameters: .crossfade,
            duration: CMTime(seconds: 1, preferredTimescale: 600)
        )

        XCTAssertEqual(preset.name, "Test Preset")
        XCTAssertEqual(preset.folder, "My Folder")
        XCTAssertTrue(preset.isFavorite)
        XCTAssertFalse(preset.isBuiltIn)
    }

    func testPresetDefaults() {
        let preset = TransitionPreset(
            name: "Test",
            transitionType: .crossfade,
            parameters: .crossfade,
            duration: CMTime(seconds: 1, preferredTimescale: 600)
        )

        XCTAssertEqual(preset.folder, "")
        XCTAssertFalse(preset.isFavorite)
        XCTAssertFalse(preset.isBuiltIn)
    }
}
