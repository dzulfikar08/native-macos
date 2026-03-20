// Tests/OpenScreenTests/EffectsTests/VideoEffectTests.swift
import XCTest
import AVFoundation
@testable import OpenScreen

@MainActor
final class VideoEffectTests: XCTestCase {
    func testVideoEffectCreation() {
        let effect = VideoEffect(
            type: .brightness,
            parameters: .brightness(0.0),
            isEnabled: true,
            timeRange: nil
        )

        XCTAssertEqual(effect.type, .brightness)
        if case .brightness(let value) = effect.parameters {
            XCTAssertEqual(value, 0.0)
        } else {
            XCTFail("Parameters should be brightness")
        }
        XCTAssertTrue(effect.isEnabled)
        XCTAssertNil(effect.timeRange)
    }

    func testVideoEffectIdentifiable() {
        let effect = VideoEffect(
            type: .contrast,
            parameters: .contrast(1.0),
            isEnabled: true
        )

        XCTAssertNotNil(effect.id)
    }

    func testVideoEffectCodable() {
        let effect = VideoEffect(
            type: .saturation,
            parameters: .saturation(1.0),
            isEnabled: false
        )

        let encoder = JSONEncoder()
        let data = try? encoder.encode(effect)
        XCTAssertNotNil(data)

        let decoder = JSONDecoder()
        let decoded = try? decoder.decode(VideoEffect.self, from: data!)

        XCTAssertEqual(decoded?.type, .saturation)
        XCTAssertEqual(decoded?.isEnabled, false)
        XCTAssertEqual(decoded?.id, effect.id)
        XCTAssertEqual(decoded?.parameters.value, effect.parameters.value)
        XCTAssertNil(decoded?.timeRange)
    }

    func testVideoEffectWithTimeRange() {
        let range = CMTime(seconds: 5, preferredTimescale: 600)...CMTime(seconds: 10, preferredTimescale: 600)
        let effect = VideoEffect(
            type: .brightness,
            parameters: .brightness(0.1),
            timeRange: range
        )

        XCTAssertNotNil(effect.timeRange)
        if let effectRange = effect.timeRange {
            XCTAssertEqual(CMTimeGetSeconds(effectRange.lowerBound), 5.0, accuracy: 0.01)
            XCTAssertEqual(CMTimeGetSeconds(effectRange.upperBound), 10.0, accuracy: 0.01)
        }
    }

    func testBrightnessParameterValidation() {
        let param = VideoEffectParameters.brightness(0.5)
        XCTAssertTrue(param.isValid)

        let invalidParam = VideoEffectParameters.brightness(2.0)  // Out of range
        XCTAssertFalse(invalidParam.isValid)
    }

    func testContrastParameterValidation() {
        let param = VideoEffectParameters.contrast(1.5)
        XCTAssertTrue(param.isValid)

        let invalidParam = VideoEffectParameters.contrast(5.0)  // Out of range
        XCTAssertFalse(invalidParam.isValid)
    }

    func testSaturationParameterValidation() {
        let param = VideoEffectParameters.saturation(1.2)
        XCTAssertTrue(param.isValid)

        let invalidParam = VideoEffectParameters.saturation(3.0)  // Out of range
        XCTAssertFalse(invalidParam.isValid)
    }

    func testParameterTypeMismatch() {
        // Create brightness effect with saturation parameters (should fail validation)
        let effect = VideoEffect(
            type: .brightness,
            parameters: .saturation(1.0),
            isEnabled: true
        )

        let validator = VideoEffectValidator()
        XCTAssertThrowsError(try validator.validate(effect)) { error in
            XCTAssertTrue(error is VideoEffectError)
        }
    }

    func testBoundaryValues() {
        // Test brightness boundaries
        let minBrightness = VideoEffectParameters.brightness(-1.0)
        XCTAssertTrue(minBrightness.isValid)

        let maxBrightness = VideoEffectParameters.brightness(1.0)
        XCTAssertTrue(maxBrightness.isValid)

        // Test contrast boundaries
        let minContrast = VideoEffectParameters.contrast(0.0)
        XCTAssertTrue(minContrast.isValid)

        let maxContrast = VideoEffectParameters.contrast(4.0)
        XCTAssertTrue(maxContrast.isValid)

        // Test saturation boundaries
        let minSaturation = VideoEffectParameters.saturation(0.0)
        XCTAssertTrue(minSaturation.isValid)

        let maxSaturation = VideoEffectParameters.saturation(2.0)
        XCTAssertTrue(maxSaturation.isValid)
    }

    func testInvalidTimeRange() {
        // Test with lowerBound > upperBound
        let invalidRange = CMTime(seconds: 10, preferredTimescale: 600)...CMTime(seconds: 5, preferredTimescale: 600)
        let effect = VideoEffect(
            type: .brightness,
            parameters: .brightness(0.0),
            timeRange: invalidRange
        )

        let validator = VideoEffectValidator()
        XCTAssertThrowsError(try validator.validate(effect)) { error in
            XCTAssertTrue(error is VideoEffectError)
            if case VideoEffectError.timeRangeOutOfBounds = error {
                // Expected error type
            } else {
                XCTFail("Expected timeRangeOutOfBounds error")
            }
        }
    }

    func testNegativeTimeRange() {
        // Test with negative time values
        let negativeRange = CMTime(seconds: -5, preferredTimescale: 600)...CMTime(seconds: 10, preferredTimescale: 600)
        let effect = VideoEffect(
            type: .brightness,
            parameters: .brightness(0.0),
            timeRange: negativeRange
        )

        let validator = VideoEffectValidator()
        XCTAssertThrowsError(try validator.validate(effect)) { error in
            XCTAssertTrue(error is VideoEffectError)
            if case VideoEffectError.timeRangeOutOfBounds = error {
                // Expected error type
            } else {
                XCTFail("Expected timeRangeOutOfBounds error")
            }
        }
    }
}
