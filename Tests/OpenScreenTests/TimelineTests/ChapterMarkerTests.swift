import XCTest
import AVFoundation
@testable import OpenScreen

final class ChapterMarkerTests: XCTestCase {

    // MARK: - Test 1: ChapterMarker Creation

    func testChapterMarkerCreation() throws {
        let time = CMTime(seconds: 5.0, preferredTimescale: 600)

        let marker = ChapterMarker(
            name: "Chapter 1",
            time: time,
            notes: "Introduction",
            color: .blue
        )

        XCTAssertEqual(marker.name, "Chapter 1")
        XCTAssertEqual(marker.time.seconds, 5.0)
        XCTAssertEqual(marker.notes, "Introduction")
        XCTAssertEqual(marker.color, .blue)
        XCTAssertNotNil(marker.id)
    }

    // MARK: - Test 2: ChapterMarker Codable

    func testChapterMarkerCodable() throws {
        let time = CMTime(seconds: 10.5, preferredTimescale: 600)

        let original = ChapterMarker(
            id: UUID(uuidString: "12345678-1234-1234-1234-123456789012")!,
            name: "Codable Marker",
            time: time,
            notes: "Test notes",
            color: .green
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ChapterMarker.self, from: data)

        XCTAssertEqual(original.id, decoded.id)
        XCTAssertEqual(original.name, decoded.name)
        XCTAssertEqual(original.time.seconds, decoded.time.seconds, accuracy: 0.001)
        XCTAssertEqual(original.notes, decoded.notes)
        XCTAssertEqual(original.color, decoded.color)
    }

    // MARK: - Test 3: ChapterMarker Identifiable

    func testChapterMarkerIdentifiable() throws {
        let id = UUID()
        let time = CMTime(seconds: 15.0, preferredTimescale: 600)

        let marker = ChapterMarker(
            id: id,
            name: "Identifiable Marker",
            time: time,
            color: .orange
        )

        XCTAssertEqual(marker.id, id)
    }

    // MARK: - Test 4: ChapterMarker Validation (Time Bounds)

    func testChapterMarkerValidation() throws {
        let validator = ChapterMarkerValidator(maximumCount: 1000)
        let videoDuration = CMTime(seconds: 60.0, preferredTimescale: 600)

        // Valid time within bounds
        let validTime = CMTime(seconds: 30.0, preferredTimescale: 600)
        XCTAssertNoThrow(try validator.validate(time: validTime, videoDuration: videoDuration))

        // Invalid time (negative)
        let negativeTime = CMTime(seconds: -1.0, preferredTimescale: 600)
        XCTAssertThrowsError(try validator.validate(time: negativeTime, videoDuration: videoDuration)) { error in
            guard case MarkerError.invalidTime = error else {
                XCTFail("Expected MarkerError.invalidTime, got \(error)")
                return
            }
        }

        // Invalid time (beyond video duration)
        let beyondTime = CMTime(seconds: 61.0, preferredTimescale: 600)
        XCTAssertThrowsError(try validator.validate(time: beyondTime, videoDuration: videoDuration)) { error in
            guard case MarkerError.invalidTime = error else {
                XCTFail("Expected MarkerError.invalidTime, got \(error)")
                return
            }
        }

        // Boundary case: exactly at duration
        let atBoundaryTime = CMTime(seconds: 60.0, preferredTimescale: 600)
        XCTAssertNoThrow(try validator.validate(time: atBoundaryTime, videoDuration: videoDuration))

        // Boundary case: at zero
        let atZero = CMTime.zero
        XCTAssertNoThrow(try validator.validate(time: atZero, videoDuration: videoDuration))
    }

    // MARK: - Test 5: Maximum Marker Count

    func testMaximumMarkerCount() throws {
        let validator = ChapterMarkerValidator(maximumCount: 1000)

        // Under limit
        XCTAssertNoThrow(try validator.validateCount(existingCount: 999))

        // At limit
        XCTAssertThrowsError(try validator.validateCount(existingCount: 1000)) { error in
            guard case MarkerError.tooManyMarkers(let limit) = error else {
                XCTFail("Expected MarkerError.tooManyMarkers, got \(error)")
                return
            }
            XCTAssertEqual(limit, 1000)
        }

        // Over limit
        XCTAssertThrowsError(try validator.validateCount(existingCount: 1001)) { error in
            guard case MarkerError.tooManyMarkers = error else {
                XCTFail("Expected MarkerError.tooManyMarkers, got \(error)")
                return
            }
        }
    }
}
