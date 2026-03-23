import XCTest
import CoreMedia
@testable import OpenScreen

/// Integration tests for preset save/load/apply workflows
final class PresetWorkflowTests: XCTestCase {

    var library: PresetLibrary!
    var storage: TransitionPresetStorage!

    override func setUp() async throws {
        try await super.setUp()
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("preset_workflow_\(UUID().uuidString)")
        storage = TransitionPresetStorage(directory: tempDir)
        library = PresetLibrary(storage: storage)
    }

    func testSavePresetFromTransition() throws {
        let transition = TransitionClip(
            type: .crossfade,
            duration: CMTime(seconds: 1.2, preferredTimescale: 600),
            leadingClipID: UUID(),
            trailingClipID: UUID(),
            parameters: .crossfade,
            isEnabled: true
        )

        try library.savePreset(
            name: "Test Workflow Preset",
            folder: "Test Folder",
            transition: transition,
            isFavorite: false
        )

        XCTAssertEqual(library.allPresets.count, 6) // 5 built-in + 1 custom
        XCTAssertEqual(library.folders.count, 3) // "My Transitions", "Test Folder", and potentially "All"
    }

    func testLoadAndApplyCustomPreset() throws {
        // Create and save a preset
        let transition = TransitionClip(
            type: .wipe,
            duration: CMTime(seconds: 1.0, preferredTimescale: 600),
            leadingClipID: UUID(),
            trailingClipID: UUID(),
            parameters: .wipe(direction: .right, softness: 0.3, border: 1.0),
            isEnabled: true
        )

        try library.savePreset(
            name: "Right Wipe",
            folder: "",
            transition: transition,
            isFavorite: true
        )

        // Load preset
        guard let savedPreset = library.allPresets.first(where: { $0.name == "Right Wipe" }) else {
            XCTFail("Preset not found")
            return
        }

        XCTAssertEqual(savedPreset.transitionType, .wipe)
        XCTAssertTrue(savedPreset.isFavorite)

        // Apply preset to create new transition
        let newTransition = savedPreset.makeTransition(
            leadingClipID: UUID(),
            trailingClipID: UUID()
        )

        XCTAssertEqual(newTransition.type, .wipe)
        XCTAssertEqual(newTransition.duration, CMTime(seconds: 1.0, preferredTimescale: 600))
    }

    func testPresetPersistsAcrossLaunches() throws {
        // Create a library and save a preset
        let transition = TransitionClip(
            type: .iris,
            duration: CMTime(seconds: 1.5, preferredTimescale: 600),
            leadingClipID: UUID(),
            trailingClipID: UUID(),
            parameters: .iris(shape: .rectangle, position: CGPoint(x: 0.5, y: 0.5), softness: 0.4),
            isEnabled: true
        )

        try library.savePreset(
            name: "Persistent Preset",
            folder: "Persistence Tests",
            transition: transition,
            isFavorite: false
        )

        // Simulate app restart by creating new library with same storage
        let newLibrary = PresetLibrary(storage: storage)
        try newLibrary.loadCustomPresets()

        // Verify preset persists
        XCTAssertEqual(newLibrary.allPresets.count, 6)
        XCTAssertTrue(newLibrary.allPresets.contains(where: { $0.name == "Persistent Preset" }))
        XCTAssertTrue(newLibrary.folders.contains("Persistence Tests"))
    }

    func testSavePresetWithAllTransitionTypes() throws {
        let transitionTypes: [TransitionType] = [.crossfade, .fadeToColor, .wipe, .iris, .blinds]

        for (index, type) in transitionTypes.enumerated() {
            let parameters = TransitionParameters(for: type)
            let transition = TransitionClip(
                type: type,
                duration: CMTime(seconds: 1.0, preferredTimescale: 600),
                leadingClipID: UUID(),
                trailingClipID: UUID(),
                parameters: parameters,
                isEnabled: true
            )

            try library.savePreset(
                name: "Preset \(type.displayName)",
                folder: "All Types",
                transition: transition,
                isFavorite: index % 2 == 0 // Alternate favorites
            )
        }

        XCTAssertEqual(library.allPresets.count, 10) // 5 built-in + 5 custom
        XCTAssertEqual(library.presetsInFolder("All Types").count, 5)
    }
}
