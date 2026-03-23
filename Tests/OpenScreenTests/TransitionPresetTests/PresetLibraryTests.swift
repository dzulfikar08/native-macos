import XCTest
import CoreMedia
@testable import OpenScreen

final class PresetLibraryTests: XCTestCase {

    var library: PresetLibrary!
    var storage: TransitionPresetStorage!

    override func setUp() async throws {
        try await super.setUp()
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("preset_lib_\(UUID().uuidString)")
        storage = TransitionPresetStorage(directory: tempDir)
        library = PresetLibrary(storage: storage)
    }

    func testLibraryInitializesWithBuiltIns() {
        let presets = library.allPresets

        XCTAssertEqual(presets.count, 5)
        XCTAssertTrue(presets.allSatisfy { $0.isBuiltIn })
    }

    func testAddCustomPreset() throws {
        let transition = TransitionClip(
            type: .crossfade,
            duration: CMTime(seconds: 1, preferredTimescale: 600),
            leadingClipID: UUID(),
            trailingClipID: UUID(),
            parameters: .crossfade,
            isEnabled: true
        )

        try library.savePreset(
            name: "Custom Preset",
            folder: "My Transitions",
            transition: transition,
            isFavorite: false
        )

        XCTAssertEqual(library.allPresets.count, 6) // 5 built-in + 1 custom
        XCTAssertTrue(library.folders.contains("My Transitions"))
    }

    func testPresetNameValidation() {
        let transition = TransitionClip(
            type: .crossfade,
            duration: CMTime(seconds: 1, preferredTimescale: 600),
            leadingClipID: UUID(),
            trailingClipID: UUID(),
            parameters: .crossfade,
            isEnabled: true
        )

        XCTAssertThrowsError(try library.savePreset(
            name: "",  // Empty name
            folder: "Test",
            transition: transition,
            isFavorite: false
        ))

        XCTAssertThrowsError(try library.savePreset(
            name: "Quick Dissolve",  // Built-in name
            folder: "Test",
            transition: transition,
            isFavorite: false
        ))
    }

    func testFavoritePresets() throws {
        let transition = TransitionClip(
            type: .wipe,
            duration: CMTime(seconds: 1, preferredTimescale: 600),
            leadingClipID: UUID(),
            trailingClipID: UUID(),
            parameters: .wipe(direction: .left, softness: 0.5, border: 0),
            isEnabled: true
        )

        try library.savePreset(
            name: "Favorite Preset",
            folder: "",
            transition: transition,
            isFavorite: true
        )

        let favorites = library.favoritePresets()
        XCTAssertEqual(favorites.count, 1)
        XCTAssertTrue(favorites.first?.isFavorite ?? false)
    }

    func testFolderOrganization() throws {
        let transition = TransitionClip(
            type: .iris,
            duration: CMTime(seconds: 1.5, preferredTimescale: 600),
            leadingClipID: UUID(),
            trailingClipID: UUID(),
            parameters: .iris(shape: .circle, position: CGPoint(x: 0.5, y: 0.5), softness: 0.3),
            isEnabled: true
        )

        try library.savePreset(name: "Preset 1", folder: "Folder A", transition: transition, isFavorite: false)
        try library.savePreset(name: "Preset 2", folder: "Folder B", transition: transition, isFavorite: false)

        XCTAssertTrue(library.folders.contains("Folder A"))
        XCTAssertTrue(library.folders.contains("Folder B"))
        XCTAssertEqual(library.presetsInFolder("Folder A").count, 1)
        XCTAssertEqual(library.presetsInFolder("Folder B").count, 1)
    }
}
