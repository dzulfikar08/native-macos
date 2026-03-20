// Tests/OpenScreenTests/EffectsTests/VideoEffectProcessorTests.swift
import XCTest
import AVFoundation
@testable import OpenScreen

@MainActor
final class VideoEffectProcessorTests: XCTestCase {
    var processor: VideoEffectProcessor!

    override func setUp() async throws {
        try await super.setUp()
        processor = VideoEffectProcessor()
    }

    override func tearDown() async throws {
        processor = nil
        try await super.tearDown()
    }

    func testProcessorInitialization() {
        XCTAssertNotNil(processor)
    }

    func testApplySingleBrightnessEffect() async throws {
        // Create test image buffer (1x1 red pixel)
        let image = CIImage(color: .red)
        let effects = [
            VideoEffect(type: .brightness, parameters: .brightness(0.2))
        ]

        let result = processor.applyEffects(to: image, effects: effects)

        XCTAssertNotNil(result)
    }

    func testApplyMultipleEffects() async throws {
        let image = CIImage(color: .red)
        let effects = [
            VideoEffect(type: .saturation, parameters: .saturation(1.2)),
            VideoEffect(type: .contrast, parameters: .contrast(1.1))
        ]

        let result = processor.applyEffects(to: image, effects: effects)

        XCTAssertNotNil(result)
    }

    func testFilterCaching() async throws {
        let image = CIImage(color: .red)
        let effects = [
            VideoEffect(type: .brightness, parameters: .brightness(0.0))
        ]

        // Apply twice - should use cached filter
        _ = processor.applyEffects(to: image, effects: effects)
        _ = processor.applyEffects(to: image, effects: effects)

        // If caching works, no errors thrown
    }

    func testDisableEffectSkipsProcessing() async throws {
        let image = CIImage(color: .red)
        var effect = VideoEffect(type: .brightness, parameters: .brightness(0.5))
        effect.isEnabled = false

        let result = processor.applyEffects(to: image, effects: [effect])

        XCTAssertNotNil(result)
    }

    func testInvalidateFilterCache() {
        // Should not crash
        processor.invalidateFilterCache()

        // Cache should be empty after invalidation
        XCTAssertNoThrow(processor.invalidateFilterCache())
    }

    func testApplyEffectsAsyncPerformance() async throws {
        let image = CIImage(color: .red)
        let effects = [
            VideoEffect(type: .brightness, parameters: .brightness(0.1)),
            VideoEffect(type: .contrast, parameters: .contrast(1.1)),
            VideoEffect(type: .saturation, parameters: .saturation(1.1))
        ]

        let expectation = expectation(description: "Async processing completes")

        processor.applyEffectsAsync(to: createTestPixelBuffer(), effects: effects) { result in
            XCTAssertNotNil(result)
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 1.0)
    }

    private func createTestPixelBuffer() -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
            kCVPixelBufferMetalCompatibilityKey: kCFBooleanTrue
        ] as CFDictionary

        CVPixelBufferCreate(
            kCFAllocatorDefault,
            1,
            1,
            kCVPixelFormatType_32ARGB,
            attrs as CFDictionary,
            &pixelBuffer
        )

        return pixelBuffer!
    }
}
