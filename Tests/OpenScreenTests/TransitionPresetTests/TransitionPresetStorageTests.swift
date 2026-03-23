import XCTest
import Foundation
import CoreMedia
@testable import OpenScreen

final class TransitionPresetStorageTests: XCTestCase {

    var storage: TransitionPresetStorage!
    var tempDir: URL!

    override func setUp() async throws {
        try await super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("preset_storage_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        storage = TransitionPresetStorage(directory: tempDir)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
        storage = nil
        try await super.tearDown()
    }

    func testSaveAndLoadPreset() throws {
        let preset = TransitionPreset(
            name: "Test Preset",
            folder: "Test Folder",
            isFavorite: false,
            transitionType: .crossfade,
            parameters: .crossfade,
            duration: CMTime(seconds: 1.5, preferredTimescale: 600)
        )

        try storage.savePreset(preset)
        let loaded = try storage.loadCustomPresets()

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.name, "Test Preset")
        XCTAssertEqual(loaded.first?.folder, "Test Folder")
    }

    func testDeletePreset() throws {
        let preset = TransitionPreset(
            name: "ToDelete",
            folder: "",
            isFavorite: false,
            transitionType: .wipe,
            parameters: .wipe(direction: .left, softness: 0.5, border: 0),
            duration: CMTime(seconds: 1, preferredTimescale: 600)
        )

        try storage.savePreset(preset)
        var loaded = try storage.loadCustomPresets()
        XCTAssertEqual(loaded.count, 1)

        try storage.deletePreset(preset)
        loaded = try storage.loadCustomPresets()
        XCTAssertEqual(loaded.count, 0)
    }

    func testSaveBuiltInPresetThrows() {
        let builtInPreset = TransitionPreset(
            name: "Quick Dissolve",
            folder: "",
            isFavorite: false,
            isBuiltIn: true,
            transitionType: .crossfade,
            parameters: .crossfade,
            duration: CMTime(seconds: 0.5, preferredTimescale: 600)
        )

        XCTAssertThrowsError(try storage.savePreset(builtInPreset))
    }

    func testLoadFromEmptyDirectory() throws {
        let loaded = try storage.loadCustomPresets()
        XCTAssertTrue(loaded.isEmpty)
    }
}
