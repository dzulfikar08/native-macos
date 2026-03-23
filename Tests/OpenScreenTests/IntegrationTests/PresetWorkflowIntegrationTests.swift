import XCTest
import CoreMedia
@testable import OpenScreen

final class PresetWorkflowIntegrationTests: XCTestCase {

    var library: PresetLibrary!
    var storage: TransitionPresetStorage!

    override func setUp() async throws {
        try await super.setUp()
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("preset_integration_\(UUID().uuidString)")
        storage = TransitionPresetStorage(directory: tempDir)
        library = PresetLibrary(storage: storage)
        try library.loadCustomPresets()
    }

    func testSaveApplyDeletePresetWorkflow() {
        let editorState = EditorState()

        // Create transition from inspector
        let transition = TransitionClip(
            type: .wipe,
            duration: CMTime(seconds: 1.5, preferredTimescale: 600),
            leadingClipID: UUID(),
            trailingClipID: UUID(),
            parameters: .wipe(direction: .right, softness: 0.4, border: 2.0),
            isEnabled: true
        )

        // Save as preset
        try! library.savePreset(
            name: "My Custom Wipe",
            folder: "Custom Transitions",
            transition: transition,
            isFavorite: true
        )

        // Verify saved
        XCTAssertEqual(library.allPresets.count, 6) // 5 built-in + 1 custom
        XCTAssertTrue(library.folders.contains("Custom Transitions"))

        // Find and apply preset
        let savedPreset = library.allPresets.first { $0.name == "My Custom Wipe" }
        XCTAssertNotNil(savedPreset)

        // Apply to different clips
        let newClips = (0..<2).map { _ in UUID() }
        let appliedTransition = savedPreset!.makeTransition(
            leadingClipID: newClips[0],
            trailingClipID: newClips[1]
        )

        editorState.addTransition(appliedTransition)
        XCTAssertEqual(editorState.transitions.count, 1)
        XCTAssertEqual(editorState.transitions.first?.parameters, savedPreset!.parameters)

        // Delete preset
        try! library.deletePreset(savedPreset!)
        XCTAssertEqual(library.allPresets.count, 5)
    }

    func testImportExportPresetWorkflow() {
        // Export a built-in preset
        let preset = BuiltInPresets.presets.first!
        let exportURL = FileManager.default.temporaryDirectory.appendingPathComponent("exported_preset.json")

        try! library.exportPreset(preset, to: exportURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: exportURL.path))

        // Import into new library
        let newLibrary = PresetLibrary(storage: storage)

        try! newLibrary.importPreset(from: exportURL, into: "Imported")

        // Verify imported
        XCTAssertTrue(newLibrary.allPresets.contains(where: { $0.name == "\(preset.name) (Imported)" }))
    }

    func testFavoritePresetWorkflow() {
        let transition = TransitionClip(
            type: .iris,
            duration: CMTime(seconds: 1, preferredTimescale: 600),
            leadingClipID: UUID(),
            trailingClipID: UUID(),
            parameters: .iris(shape: .circle, position: CGPoint(x: 0.5, y: 0.5), softness: 0.3),
            isEnabled: true
        )

        try! library.savePreset(
            name: "Favorite Iris",
            folder: "",
            transition: transition,
            isFavorite: false
        )

        let preset = library.allPresets.first { $0.name == "Favorite Iris" }
        XCTAssertNotNil(preset)
        XCTAssertFalse(preset!.isFavorite)

        // Toggle favorite
        library.toggleFavorite(preset!)
        XCTAssertTrue(library.favoritePresets().contains(where: { $0.id == preset!.id }))

        // Verify favorites filter works
        let favorites = library.favoritePresets()
        XCTAssertTrue(favorites.contains(where: { $0.name == "Favorite Iris" }))
    }
}
