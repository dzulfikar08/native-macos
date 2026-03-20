// Tests/OpenScreenTests/EffectsTests/PresetStorageTests.swift
import XCTest
@testable import OpenScreen

final class PresetStorageTests: XCTestCase {
    var storage: PresetStorage!
    var tempDirectory: URL!

    override func setUp() async throws {
        try await super.setUp()

        // Create temporary directory for testing
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("OpenScreen_PresetTests_\(UUID().uuidString)")

        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        storage = PresetStorage(directory: tempDirectory)
    }

    override func tearDown() async throws {
        // Clean up temp directory
        try? FileManager.default.removeItem(at: tempDirectory)

        storage = nil
        tempDirectory = nil

        try await super.tearDown()
    }

    func testLoadCustomPresetsEmpty() async throws {
        let presets = try storage.loadCustomPresets()
        XCTAssertTrue(presets.isEmpty)
    }

    func testSaveAndLoadPreset() async throws {
        let preset = EffectPreset(
            name: "Test Preset",
            isBuiltIn: false,
            videoEffects: [
                VideoEffect(type: .brightness, parameters: .brightness(0.2))
            ]
        )

        try storage.savePreset(preset)

        let loadedPresets = try storage.loadCustomPresets()
        XCTAssertEqual(loadedPresets.count, 1)
        XCTAssertEqual(loadedPresets.first?.name, "Test Preset")
    }

    func testDeletePreset() async throws {
        let preset = EffectPreset(
            name: "To Delete",
            isBuiltIn: false,
            videoEffects: []
        )

        try storage.savePreset(preset)
        var presets = try storage.loadCustomPresets()
        XCTAssertEqual(presets.count, 1)

        try storage.deletePreset(preset)
        presets = try storage.loadCustomPresets()
        XCTAssertTrue(presets.isEmpty)
    }

    func testDeleteBuiltInPresetThrows() async throws {
        let builtInPreset = EffectStack.builtInPresets.first!

        XCTAssertThrowsError(try storage.deletePreset(builtInPreset)) { error in
            XCTAssertTrue(error is PresetError)
            XCTAssertEqual(error as? PresetError, .cannotModifyBuiltIn)
        }
    }

    func testMultiplePresets() async throws {
        let preset1 = EffectPreset(name: "Preset 1", isBuiltIn: false, videoEffects: [])
        let preset2 = EffectPreset(name: "Preset 2", isBuiltIn: false, audioEffects: [])

        try storage.savePreset(preset1)
        try storage.savePreset(preset2)

        let presets = try storage.loadCustomPresets()
        XCTAssertEqual(presets.count, 2)
    }
}
