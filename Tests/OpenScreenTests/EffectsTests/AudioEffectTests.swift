// Test AudioEffect data model with type-safe parameters
import XCTest
import AVFoundation
@testable import OpenScreen

@MainActor
final class AudioEffectTests: XCTestCase {

    // MARK: - Creation Tests

    func testAudioEffectCreation() {
        let effect = AudioEffect(
            type: .volumeNormalization,
            parameters: .withVolumeNormalization(-16.0),
            isEnabled: true,
            timeRange: nil
        )

        XCTAssertEqual(effect.type, .volumeNormalization)
        if case .withVolumeNormalization(let targetLUFS) = effect.parameters {
            XCTAssertEqual(targetLUFS, -16.0)
        } else {
            XCTFail("Parameters should be volumeNormalization")
        }
        XCTAssertTrue(effect.isEnabled)
    }

    func testAudioEffectWithEQ() {
        let effect = AudioEffect(
            type: .equalizer,
            parameters: .withEqualizer(bass: 3.0, treble: -2.0),
            isEnabled: true
        )

        XCTAssertEqual(effect.type, .equalizer)
        if case .withEqualizer(let bass, let treble) = effect.parameters {
            XCTAssertEqual(bass, 3.0)
            XCTAssertEqual(treble, -2.0)
        } else {
            XCTFail("Parameters should be equalizer")
        }
    }

    // MARK: - Codable Tests

    func testAudioEffectCodable() {
        let effect = AudioEffect(
            type: .equalizer,
            parameters: .withEqualizer(bass: 0.0, treble: 0.0),
            isEnabled: false
        )

        let encoder = JSONEncoder()
        let data = try? encoder.encode(effect)
        XCTAssertNotNil(data)

        let decoder = JSONDecoder()
        let decoded = try? decoder.decode(AudioEffect.self, from: data!)

        XCTAssertEqual(decoded?.type, .equalizer)
        XCTAssertFalse(decoded?.isEnabled ?? true)
    }

    // MARK: - Parameter Validation Tests

    func testVolumeNormalizationParameterValidation() {
        // Valid values
        let validParam = AudioEffectParameters.withVolumeNormalization(-16.0)
        XCTAssertTrue(validParam.isValid)

        let minValidParam = AudioEffectParameters.withVolumeNormalization(-60.0)
        XCTAssertTrue(minValidParam.isValid, "Minimum valid value should be -60")

        let maxValidParam = AudioEffectParameters.withVolumeNormalization(0.0)
        XCTAssertTrue(maxValidParam.isValid, "Maximum valid value should be 0")

        // Invalid values
        let invalidParam = AudioEffectParameters.withVolumeNormalization(-70.0)  // Out of range
        XCTAssertFalse(invalidParam.isValid)

        let invalidHighParam = AudioEffectParameters.withVolumeNormalization(1.0)  // Out of range
        XCTAssertFalse(invalidHighParam.isValid)
    }

    func testEqualizerParameterValidation() {
        // Valid values
        let validParam = AudioEffectParameters.withEqualizer(bass: 6.0, treble: 3.0)
        XCTAssertTrue(validParam.isValid)

        let minValidParam = AudioEffectParameters.withEqualizer(bass: -12.0, treble: -12.0)
        XCTAssertTrue(minValidParam.isValid, "Minimum valid values should be -12")

        let maxValidParam = AudioEffectParameters.withEqualizer(bass: 12.0, treble: 12.0)
        XCTAssertTrue(maxValidParam.isValid, "Maximum valid values should be 12")

        // Invalid values
        let invalidBass = AudioEffectParameters.withEqualizer(bass: 15.0, treble: 0.0)  // Out of range
        XCTAssertFalse(invalidBass.isValid)

        let invalidTreble = AudioEffectParameters.withEqualizer(bass: 0.0, treble: -15.0)  // Out of range
        XCTAssertFalse(invalidTreble.isValid)

        let bothInvalid = AudioEffectParameters.withEqualizer(bass: 13.0, treble: -13.0)
        XCTAssertFalse(bothInvalid.isValid)
    }

    // MARK: - Validator Tests

    func testAudioEffectValidator() {
        let validator = AudioEffectValidator()

        // Valid effect
        let validEffect = AudioEffect(
            type: .volumeNormalization,
            parameters: .withVolumeNormalization(-16.0),
            isEnabled: true
        )

        XCTAssertNoThrow(try validator.validate(validEffect))

        // Type mismatch
        let invalidEffect = AudioEffect(
            type: .equalizer,
            parameters: .withVolumeNormalization(-16.0),  // Wrong parameter type
            isEnabled: true
        )

        XCTAssertThrowsError(try validator.validate(invalidEffect)) { error in
            guard let audioError = error as? AudioEffectError else {
                XCTFail("Should throw AudioEffectError")
                return
            }
            if case .parameterMismatch = audioError {
                // Expected
            } else {
                XCTFail("Should throw parameterMismatch error")
            }
        }
    }

    func testAudioEffectValidatorWithInvalidParameters() {
        let validator = AudioEffectValidator()

        // Invalid volume normalization
        let invalidVolumeEffect = AudioEffect(
            type: .volumeNormalization,
            parameters: .withVolumeNormalization(-70.0),
            isEnabled: true
        )

        XCTAssertThrowsError(try validator.validate(invalidVolumeEffect)) { error in
            guard let audioError = error as? AudioEffectError else {
                XCTFail("Should throw AudioEffectError")
                return
            }
            if case .targetLUFSOutOfRange = audioError {
                // Expected
            } else {
                XCTFail("Should throw targetLUFSOutOfRange error")
            }
        }

        // Invalid equalizer
        let invalidEQEffect = AudioEffect(
            type: .equalizer,
            parameters: .withEqualizer(bass: 15.0, treble: 0.0),
            isEnabled: true
        )

        XCTAssertThrowsError(try validator.validate(invalidEQEffect)) { error in
            guard let audioError = error as? AudioEffectError else {
                XCTFail("Should throw AudioEffectError")
                return
            }
            if case .gainOutOfRange = audioError {
                // Expected
            } else {
                XCTFail("Should throw gainOutOfRange error")
            }
        }
    }

    // MARK: - TimeRange Tests

    func testAudioEffectWithTimeRange() {
        let timeRange = CMTime(seconds: 0.0, preferredTimescale: 600)...CMTime(seconds: 5.0, preferredTimescale: 600)

        let effect = AudioEffect(
            type: .volumeNormalization,
            parameters: .withVolumeNormalization(-16.0),
            isEnabled: true,
            timeRange: timeRange
        )

        XCTAssertNotNil(effect.timeRange)
        XCTAssertEqual(effect.timeRange?.lowerBound.seconds, 0.0)
        XCTAssertEqual(effect.timeRange?.upperBound.seconds, 5.0)
    }

    func testAudioEffectValidatorWithInvalidTimeRange() {
        let validator = AudioEffectValidator()

        // Invalid time range (lowerBound >= upperBound)
        let invalidTimeRange = CMTime(seconds: 5.0, preferredTimescale: 600)...CMTime(seconds: 5.0, preferredTimescale: 600)

        let effect = AudioEffect(
            type: .volumeNormalization,
            parameters: .withVolumeNormalization(-16.0),
            isEnabled: true,
            timeRange: invalidTimeRange
        )

        XCTAssertThrowsError(try validator.validate(effect)) { error in
            guard let audioError = error as? AudioEffectError else {
                XCTFail("Should throw AudioEffectError")
                return
            }
            if case .invalidTimeRange(let message) = audioError {
                XCTAssertTrue(message.contains("lowerBound must be less than upperBound"))
            } else {
                XCTFail("Should throw invalidTimeRange error")
            }
        }
    }

    func testAudioEffectValidatorWithNegativeTimeRange() {
        let validator = AudioEffectValidator()

        // Invalid time range (negative values)
        let negativeTimeRange = CMTime(seconds: -1.0, preferredTimescale: 600)...CMTime(seconds: 5.0, preferredTimescale: 600)

        let effect = AudioEffect(
            type: .volumeNormalization,
            parameters: .withVolumeNormalization(-16.0),
            isEnabled: true,
            timeRange: negativeTimeRange
        )

        XCTAssertThrowsError(try validator.validate(effect)) { error in
            guard let audioError = error as? AudioEffectError else {
                XCTFail("Should throw AudioEffectError")
                return
            }
            if case .invalidTimeRange = audioError {
                // Expected
            } else {
                XCTFail("Should throw invalidTimeRange error")
            }
        }
    }

    // MARK: - Edge Case Tests

    func testAudioEffectBoundaryValues() {
        let validator = AudioEffectValidator()

        // Volume normalization boundary values
        let minVolume = AudioEffect(
            type: .volumeNormalization,
            parameters: .withVolumeNormalization(-60.0),
            isEnabled: true
        )
        XCTAssertNoThrow(try validator.validate(minVolume))

        let maxVolume = AudioEffect(
            type: .volumeNormalization,
            parameters: .withVolumeNormalization(0.0),
            isEnabled: true
        )
        XCTAssertNoThrow(try validator.validate(maxVolume))

        // Equalizer boundary values
        let minEQ = AudioEffect(
            type: .equalizer,
            parameters: .withEqualizer(bass: -12.0, treble: -12.0),
            isEnabled: true
        )
        XCTAssertNoThrow(try validator.validate(minEQ))

        let maxEQ = AudioEffect(
            type: .equalizer,
            parameters: .withEqualizer(bass: 12.0, treble: 12.0),
            isEnabled: true
        )
        XCTAssertNoThrow(try validator.validate(maxEQ))
    }

    func testAudioEffectDefaultValues() {
        let effect = AudioEffect(
            type: .volumeNormalization,
            parameters: .withVolumeNormalization(-16.0)
        )

        XCTAssertTrue(effect.isEnabled, "isEnabled should default to true")
        XCTAssertNil(effect.timeRange, "timeRange should default to nil")
        XCTAssertNotNil(effect.id, "id should be generated")
    }
}
