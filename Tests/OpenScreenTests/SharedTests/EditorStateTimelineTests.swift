import XCTest
@testable import OpenScreen
import CoreMedia
import AVFoundation

@MainActor
final class EditorStateTimelineTests: XCTestCase {
    func testTimelinePropertiesInitialized() async {
        let state = EditorState(assetURL: TestDataFactory.makeTestRecordingURL())

        XCTAssertEqual(state.zoomLevel, 50.0)
        XCTAssertNotNil(state.visibleTimeRange)
        XCTAssertTrue(state.tracks.isEmpty)
    }

    func testSeekToTime() async throws {
        let state = EditorState(assetURL: TestDataFactory.makeTestRecordingURL())

        // Set up a test duration directly
        let testDuration = CMTime(seconds: 10.0, preferredTimescale: 600)
        try await state.loadTestAsset(duration: testDuration)

        let targetTime = CMTime(seconds: 5.0, preferredTimescale: 600)
        try await state.seek(to: targetTime)

        let currentTime = state.currentTime
        XCTAssertTrue(CMTimeCompare(currentTime, targetTime) == 0)
    }

    func testSeekClampsToDuration() async throws {
        let state = EditorState(assetURL: TestDataFactory.makeTestRecordingURL())

        // Set up a test duration directly
        let testDuration = CMTime(seconds: 10.0, preferredTimescale: 600)
        try await state.loadTestAsset(duration: testDuration)

        let duration = state.duration
        let beyondDuration = CMTimeAdd(duration, CMTime(seconds: 10.0, preferredTimescale: 600))

        try await state.seek(to: beyondDuration)

        let currentTime = state.currentTime
        XCTAssertEqual(currentTime, duration)
    }

    func testZoomLevelClamping() async {
        let state = EditorState(assetURL: TestDataFactory.makeTestRecordingURL())

        await state.setZoomLevel(500.0)  // Above max
        XCTAssertEqual(state.zoomLevel, 200.0)

        await state.setZoomLevel(5.0)  // Below min
        XCTAssertEqual(state.zoomLevel, 10.0)
    }

    func testTogglePlayback() async {
        let state = EditorState(assetURL: TestDataFactory.makeTestRecordingURL())

        XCTAssertFalse(state.isPlaying)

        await state.togglePlayback()
        XCTAssertTrue(state.isPlaying)

        await state.togglePlayback()
        XCTAssertFalse(state.isPlaying)
    }

    func testStepForward() async throws {
        let state = EditorState(assetURL: TestDataFactory.makeTestRecordingURL())

        // Set up a test duration directly
        let testDuration = CMTime(seconds: 10.0, preferredTimescale: 600)
        try await state.loadTestAsset(duration: testDuration)

        let initialTime = state.currentTime
        await state.stepForward()

        let newTime = state.currentTime
        XCTAssertGreaterThan(CMTimeGetSeconds(newTime), CMTimeGetSeconds(initialTime))
    }

    func testStepBackward() async throws {
        let state = EditorState(assetURL: TestDataFactory.makeTestRecordingURL())

        // Set up a test duration directly
        let testDuration = CMTime(seconds: 10.0, preferredTimescale: 600)
        try await state.loadTestAsset(duration: testDuration)

        // First seek to middle
        try await state.seek(to: CMTime(seconds: 5.0, preferredTimescale: 600))

        await state.stepBackward()

        let newTime = state.currentTime
        XCTAssertLessThan(CMTimeGetSeconds(newTime), 5.0)
    }
}

// MARK: - Test Helper Extension

extension EditorState {
    /// Helper method for testing - simulates loading an asset with a specific duration
    func loadTestAsset(duration: CMTime) async throws {
        self.duration = duration
        self.currentTime = .zero

        // Initialize timeline tracks
        tracks = [
            TimelineTrack(id: UUID(), type: .video, name: "Video", height: 120),
            TimelineTrack(id: UUID(), type: .audio, name: "Audio", height: 60)
        ]
        visibleTimeRange = .zero...duration
    }
}
