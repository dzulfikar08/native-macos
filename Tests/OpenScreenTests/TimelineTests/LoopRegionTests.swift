import XCTest
import AVFoundation
@testable import OpenScreen

final class LoopRegionTests: XCTestCase {

    // MARK: - Test 1: LoopRegion Creation

    func testLoopRegionCreation() throws {
        let startTime = CMTime(seconds: 1.0, preferredTimescale: 600)
        let endTime = CMTime(seconds: 3.0, preferredTimescale: 600)
        let timeRange: ClosedRange<CMTime> = startTime...endTime

        let loop = LoopRegion(
            name: "Test Loop",
            timeRange: timeRange,
            color: .blue,
            isActive: true,
            useInOutPoints: false
        )

        XCTAssertEqual(loop.name, "Test Loop")
        XCTAssertEqual(loop.timeRange.lowerBound.seconds, 1.0)
        XCTAssertEqual(loop.timeRange.upperBound.seconds, 3.0)
        XCTAssertTrue(loop.isActive)
        XCTAssertFalse(loop.useInOutPoints)
        XCTAssertEqual(loop.color, .blue)
        XCTAssertNotNil(loop.id)
    }

    // MARK: - Test 2: LoopRegion Codable

    func testLoopRegionCodable() throws {
        let startTime = CMTime(seconds: 1.5, preferredTimescale: 600)
        let endTime = CMTime(seconds: 4.5, preferredTimescale: 600)
        let timeRange: ClosedRange<CMTime> = startTime...endTime

        let original = LoopRegion(
            id: UUID(uuidString: "12345678-1234-1234-1234-123456789012")!,
            name: "Codable Loop",
            timeRange: timeRange,
            color: .green,
            isActive: false,
            useInOutPoints: true
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(LoopRegion.self, from: data)

        XCTAssertEqual(original.id, decoded.id)
        XCTAssertEqual(original.name, decoded.name)
        XCTAssertEqual(original.timeRange.lowerBound.seconds, decoded.timeRange.lowerBound.seconds, accuracy: 0.001)
        XCTAssertEqual(original.timeRange.upperBound.seconds, decoded.timeRange.upperBound.seconds, accuracy: 0.001)
        XCTAssertEqual(original.color, decoded.color)
        XCTAssertEqual(original.isActive, decoded.isActive)
        XCTAssertEqual(original.useInOutPoints, decoded.useInOutPoints)
    }

    // MARK: - Test 3: LoopRegion Identifiable

    func testLoopRegionIdentifiable() throws {
        let id = UUID()
        let startTime = CMTime(seconds: 0.0, preferredTimescale: 600)
        let endTime = CMTime(seconds: 2.0, preferredTimescale: 600)
        let timeRange: ClosedRange<CMTime> = startTime...endTime

        let loop = LoopRegion(
            id: id,
            name: "Identifiable Loop",
            timeRange: timeRange,
            color: .orange
        )

        XCTAssertEqual(loop.id, id)
    }

    // MARK: - Test 4: LoopRegion Equatable

    func testLoopRegionEquatable() throws {
        let startTime = CMTime(seconds: 1.0, preferredTimescale: 600)
        let endTime = CMTime(seconds: 2.0, preferredTimescale: 600)
        let timeRange: ClosedRange<CMTime> = startTime...endTime

        let loop1 = LoopRegion(
            id: UUID(uuidString: "12345678-1234-1234-1234-123456789012")!,
            name: "Loop",
            timeRange: timeRange,
            color: .blue
        )

        let loop2 = LoopRegion(
            id: UUID(uuidString: "12345678-1234-1234-1234-123456789012")!,
            name: "Loop",
            timeRange: timeRange,
            color: .blue
        )

        let loop3 = LoopRegion(
            id: UUID(uuidString: "12345678-1234-1234-1234-123456789013")!,
            name: "Different Loop",
            timeRange: timeRange,
            color: .green
        )

        XCTAssertEqual(loop1, loop2)
        XCTAssertNotEqual(loop1, loop3)
    }

    // MARK: - Test 5: Minimum Duration Validation

    func testMinimumDurationValidation() throws {
        let validator = LoopRegionValidator(minimumDuration: 0.1, maximumCount: 50)

        // Valid duration
        let validStart = CMTime(seconds: 1.0, preferredTimescale: 600)
        let validEnd = CMTime(seconds: 1.2, preferredTimescale: 600)
        let validRange: ClosedRange<CMTime> = validStart...validEnd

        XCTAssertNoThrow(try validator.validate(range: validRange))

        // Invalid duration (too short)
        let shortStart = CMTime(seconds: 1.0, preferredTimescale: 600)
        let shortEnd = CMTime(seconds: 1.05, preferredTimescale: 600)
        let shortRange: ClosedRange<CMTime> = shortStart...shortEnd

        XCTAssertThrowsError(try validator.validate(range: shortRange)) { error in
            guard case LoopError.durationTooShort = error else {
                XCTFail("Expected LoopError.durationTooShort, got \(error)")
                return
            }
        }
    }

    // MARK: - Test 6: Maximum Count Validation

    func testMaximumCountValidation() throws {
        let validator = LoopRegionValidator(minimumDuration: 0.1, maximumCount: 50)

        let validStart = CMTime(seconds: 1.0, preferredTimescale: 600)
        let validEnd = CMTime(seconds: 2.0, preferredTimescale: 600)
        let validRange: ClosedRange<CMTime> = validStart...validEnd

        // Under limit
        XCTAssertNoThrow(try validator.validate(range: validRange, existingCount: 49))

        // At limit
        XCTAssertThrowsError(try validator.validate(range: validRange, existingCount: 50)) { error in
            guard case LoopError.tooManyLoops(let limit) = error else {
                XCTFail("Expected LoopError.tooManyLoops, got \(error)")
                return
            }
            XCTAssertEqual(limit, 50)
        }

        // Over limit
        XCTAssertThrowsError(try validator.validate(range: validRange, existingCount: 60)) { error in
            guard case LoopError.tooManyLoops = error else {
                XCTFail("Expected LoopError.tooManyLoops, got \(error)")
                return
            }
        }
    }

    // MARK: - Test 7: Invalid Range Validation

    func testInvalidRangeValidation() throws {
        let validator = LoopRegionValidator(minimumDuration: 0.1, maximumCount: 50)

        // Same start and end time (will fail duration check since duration is 0)
        let sameTime = CMTime(seconds: 1.0, preferredTimescale: 600)
        let sameRange: ClosedRange<CMTime> = sameTime...sameTime

        XCTAssertThrowsError(try validator.validate(range: sameRange)) { error in
            // Since duration is 0, it fails duration check first (before invalid range check)
            guard case LoopError.durationTooShort = error else {
                XCTFail("Expected LoopError.durationTooShort for zero duration, got \(error)")
                return
            }
        }

        // Valid duration but with upperBound <= lowerBound (edge case)
        // Note: In Swift's ClosedRange, you can't have upperBound < lowerBound,
        // but you can have upperBound == lowerBound which we already tested above
        // The invalidRange check catches cases where duration would be negative or zero

        // Test that a valid range passes validation
        let validStart = CMTime(seconds: 1.0, preferredTimescale: 600)
        let validEnd = CMTime(seconds: 1.5, preferredTimescale: 600)
        let validRange: ClosedRange<CMTime> = validStart...validEnd

        XCTAssertNoThrow(try validator.validate(range: validRange))
    }

    // MARK: - Test 8: Codable Conformance

    func testCodableConformance() throws {
        // Test CMTime encoding/decoding
        let originalTime = CMTime(seconds: 2.5, preferredTimescale: 600)
        let encoder = JSONEncoder()
        let timeData = try encoder.encode(originalTime)
        let decoder = JSONDecoder()
        let decodedTime = try decoder.decode(CMTime.self, from: timeData)

        XCTAssertEqual(originalTime.seconds, decodedTime.seconds, accuracy: 0.001)
        XCTAssertEqual(originalTime.timescale, decodedTime.timescale)

        // Test ClosedRange<CMTime> encoding/decoding
        let start = CMTime(seconds: 1.0, preferredTimescale: 600)
        let end = CMTime(seconds: 3.0, preferredTimescale: 600)
        let originalRange: ClosedRange<CMTime> = start...end

        let rangeData = try encoder.encode(originalRange)
        let decodedRange = try decoder.decode(ClosedRange<CMTime>.self, from: rangeData)

        XCTAssertEqual(originalRange.lowerBound.seconds, decodedRange.lowerBound.seconds, accuracy: 0.001)
        XCTAssertEqual(originalRange.upperBound.seconds, decodedRange.upperBound.seconds, accuracy: 0.001)
    }
}
