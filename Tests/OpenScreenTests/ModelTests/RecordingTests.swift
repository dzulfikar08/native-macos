import XCTest
import Foundation
import CoreGraphics
import CoreMedia
@testable import OpenScreen

final class RecordingTests: XCTestCase {

    func testRecordingInitialization() {
        // Given
        let id = UUID()
        let url = URL(fileURLWithPath: "/tmp/test.mp4")
        let createdAt = Date()
        let duration = CMTime(value: 60, timescale: 1)
        let displayID = CGMainDisplayID()
        let frameSize = CGSize(width: 1920, height: 1080)
        let hasAudio = true

        // When
        let recording = Recording(
            id: id,
            url: url,
            createdAt: createdAt,
            duration: duration,
            displayID: displayID,
            frameSize: frameSize,
            hasAudio: hasAudio
        )

        // Then
        XCTAssertEqual(recording.id, id)
        XCTAssertEqual(recording.url, url)
        XCTAssertEqual(recording.createdAt, createdAt)
        XCTAssertEqual(recording.duration, duration)
        XCTAssertEqual(recording.displayID, displayID)
        XCTAssertEqual(recording.frameSize, frameSize)
        XCTAssertTrue(recording.hasAudio)
    }

    func testRecordingCodability() {
        // Given
        let originalRecording = Recording(
            id: UUID(),
            url: URL(fileURLWithPath: "/tmp/test.mp4"),
            createdAt: Date(),
            duration: CMTime(value: 60, timescale: 1),
            displayID: CGMainDisplayID(),
            frameSize: CGSize(width: 1920, height: 1080),
            hasAudio: true
        )

        // When
        let encodedData = try! JSONEncoder().encode(originalRecording)
        let decodedRecording = try! JSONDecoder().decode(Recording.self, from: encodedData)

        // Then
        XCTAssertEqual(decodedRecording.id, originalRecording.id)
        XCTAssertEqual(decodedRecording.url, originalRecording.url)
        XCTAssertEqual(decodedRecording.createdAt, originalRecording.createdAt)
        XCTAssertEqual(decodedRecording.duration.value, originalRecording.duration.value)
        XCTAssertEqual(decodedRecording.duration.timescale, originalRecording.duration.timescale)
        XCTAssertEqual(decodedRecording.displayID, originalRecording.displayID)
        XCTAssertEqual(decodedRecording.frameSize.width, originalRecording.frameSize.width)
        XCTAssertEqual(decodedRecording.frameSize.height, originalRecording.frameSize.height)
        XCTAssertEqual(decodedRecording.hasAudio, originalRecording.hasAudio)
    }
}