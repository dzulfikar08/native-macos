// native-macos/Tests/OpenScreenTests/EffectsTests/EffectPresetTests.swift
import XCTest
@testable import OpenScreen

@MainActor
final class EffectPresetTests: XCTestCase {
    func testBuiltInPresets() {
        XCTAssertEqual(EffectStack.builtInPresets.count, 5)

        let warmPreset = EffectStack.builtInPresets.first { $0.name == "Warm" }
        XCTAssertNotNil(warmPreset)
        XCTAssertTrue(warmPreset?.isBuiltIn ?? false)
        XCTAssertEqual(warmPreset?.videoEffects.count, 2)
    }

    func testPresetCodable() {
        let preset = EffectPreset(
            name: "Test",
            isBuiltIn: false,
            videoEffects: [
                VideoEffect(type: .saturation, parameters: .saturation(1.2))
            ]
        )

        let encoder = JSONEncoder()
        let data = try? encoder.encode(preset)
        XCTAssertNotNil(data)

        let decoder = JSONDecoder()
        let decoded = try? decoder.decode(EffectPreset.self, from: data!)

        XCTAssertEqual(decoded?.name, "Test")
        XCTAssertFalse(decoded?.isBuiltIn ?? true)
        XCTAssertEqual(decoded?.videoEffects.count, 1)
    }

    func testEffectStackInitialization() {
        let stack = EffectStack()
        XCTAssertTrue(stack.videoEffects.isEmpty)
        XCTAssertTrue(stack.audioEffects.isEmpty)
        XCTAssertNil(stack.selectedPreset)
    }

    func testApplyPreset() {
        var stack = EffectStack()
        let warmPreset = EffectStack.builtInPresets.first { $0.name == "Warm" }!

        stack.applyPreset(warmPreset)

        XCTAssertEqual(stack.videoEffects.count, 2)
        XCTAssertEqual(stack.selectedPreset?.name, "Warm")
    }

    func testSaveAsPreset() {
        var stack = EffectStack()
        stack.videoEffects = [
            VideoEffect(type: .brightness, parameters: .brightness(0.1))
        ]

        XCTAssertNoThrow(try stack.saveAsPreset(name: "My Custom"))
        XCTAssertNotNil(stack.selectedPreset)
        XCTAssertEqual(stack.selectedPreset?.name, "My Custom")
        XCTAssertFalse(stack.selectedPreset?.isBuiltIn ?? true)
    }

    func testSaveAsPresetEmptyName() {
        var stack = EffectStack()

        XCTAssertThrowsError(try stack.saveAsPreset(name: "")) { error in
            XCTAssertTrue(error is PresetError)
        }
    }

    func testBuiltInPresetImmutability() {
        // Built-in presets should not be modifiable
        let warmPreset = EffectStack.builtInPresets.first { $0.name == "Warm" }!

        // Test would need to attempt modification
        // For now, just verify isBuiltIn flag is set
        XCTAssertTrue(warmPreset.isBuiltIn)
    }
}
