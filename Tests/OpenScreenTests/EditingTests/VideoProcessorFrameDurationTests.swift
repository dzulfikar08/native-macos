import XCTest
@testable import OpenScreen

@MainActor
final class VideoProcessorFrameDurationTests: XCTestCase {

    var videoProcessor: VideoProcessor!

    override func setUp() async throws {
        let url = TestDataFactory.makeTestRecordingURL()
        videoProcessor = VideoProcessor(assetURL: url)
    }

    override func tearDown() async throws {
        videoProcessor = nil
    }

    // MARK: - Constant Frame Rate Detection Tests

    func testIsConstantFrameRateWithConstantFrames() async throws {
        // Mock a constant frame rate scenario
        videoProcessor.mockFrameDurations = [
            CMTime(seconds: 1/30.0, preferredTimescale: 600), // 33.33ms
            CMTime(seconds: 1/30.0, preferredTimescale: 600), // 33.33ms
            CMTime(seconds: 1/30.0, preferredTimescale: 600), // 33.33ms
            CMTime(seconds: 1/30.0, preferredTimescale: 600), // 33.33ms
            CMTime(seconds: 1/30.0, preferredTimescale: 600), // 33.33ms
        ]

        let result = await videoProcessor.isConstantFrameRate()
        XCTAssertTrue(result, "Should detect constant frame rate for uniform frame durations")
    }

    func testIsConstantFrameRateWithVaryingFrames() async throws {
        // Mock a variable frame rate scenario
        videoProcessor.mockFrameDurations = [
            CMTime(seconds: 1/30.0, preferredTimescale: 600), // 33.33ms
            CMTime(seconds: 1/25.0, preferredTimescale: 600), // 40.00ms
            CMTime(seconds: 1/30.0, preferredTimescale: 600), // 33.33ms
            CMTime(seconds: 1/30.0, preferredTimescale: 600), // 33.33ms
            CMTime(seconds: 1/24.0, preferredTimescale: 600), // 41.67ms
        ]

        let result = await videoProcessor.isConstantFrameRate()
        XCTAssertFalse(result, "Should detect variable frame rate for varying frame durations")
    }

    func testIsConstantFrameRateWithTolerance() async throws {
        // Mock frames within 1ms tolerance of each other
        videoProcessor.mockFrameDurations = [
            CMTime(seconds: 1/30.0, preferredTimescale: 600), // 33.33ms
            CMTime(seconds: 1/30.0 + 0.0001, preferredTimescale: 600), // 33.43ms (within 1ms tolerance)
            CMTime(seconds: 1/30.0 - 0.0001, preferredTimescale: 600), // 33.23ms (within 1ms tolerance)
        ]

        let result = await videoProcessor.isConstantFrameRate()
        XCTAssertTrue(result, "Should detect constant frame rate within 1ms tolerance")
    }

    func testIsConstantFrameRateWithSmallSample() async throws {
        // Test with exactly 30 frames (minimum required)
        videoProcessor.mockFrameDurations = Array(repeating: CMTime(seconds: 1/30.0, preferredTimescale: 600), count: 30)

        let result = await videoProcessor.isConstantFrameRate()
        XCTAssertTrue(result, "Should detect constant frame rate with exactly 30 frames")
    }

    // MARK: - Average Frame Duration Calculation Tests

    func testCalculateAverageFrameDurationWithConstantFrames() async throws {
        videoProcessor.mockFrameDurations = [
            CMTime(seconds: 1/30.0, preferredTimescale: 600), // 33.33ms
            CMTime(seconds: 1/30.0, preferredTimescale: 600), // 33.33ms
            CMTime(seconds: 1/30.0, preferredTimescale: 600), // 33.33ms
            CMTime(seconds: 1/30.0, preferredTimescale: 600), // 33.33ms
            CMTime(seconds: 1/30.0, preferredTimescale: 600), // 33.33ms
        ]

        let avgDuration = await videoProcessor.calculateAverageFrameDuration()
        let expectedAvg = CMTime(seconds: 1/30.0, preferredTimescale: 600)
        XCTAssertEqual(avgDuration, expectedAvg, "Average duration should match individual frame duration")
    }

    func testCalculateAverageFrameDurationWithVaryingFrames() async throws {
        // Mix of 30fps and 24fps frames
        videoProcessor.mockFrameDurations = [
            CMTime(seconds: 1/30.0, preferredTimescale: 600), // 33.33ms
            CMTime(seconds: 1/24.0, preferredTimescale: 600), // 41.67ms
            CMTime(seconds: 1/30.0, preferredTimescale: 600), // 33.33ms
            CMTime(seconds: 1/24.0, preferredTimescale: 600), // 41.67ms
            CMTime(seconds: 1/30.0, preferredTimescale: 600), // 33.33ms
        ]

        let avgDuration = await videoProcessor.calculateAverageFrameDuration()
        // Expected average: (33.33 + 41.67 + 33.33 + 41.67 + 33.33) / 5 = 36.66ms
        let expectedAvg = CMTime(seconds: 1/27.3, preferredTimescale: 600) // Approximately 36.6ms
        XCTAssertEqual(avgDuration, expectedAvg, accuracy: CMTime(seconds: 0.01, preferredTimescale: 600))
    }

    func testCalculateAverageFrameDurationWithMoreThan100Frames() async throws {
        videoProcessor.mockFrameDurations = Array(repeating: CMTime(seconds: 1/30.0, preferredTimescale: 600), count: 150)

        let avgDuration = await videoProcessor.calculateAverageFrameDuration()
        // Should only use first 100 frames
        let expectedAvg = CMTime(seconds: 1/30.0, preferredTimescale: 600)
        XCTAssertEqual(avgDuration, expectedAvg, "Should only consider first 100 frames")
    }

    // MARK: - Frame Duration Detection Tests

    func testDetectFrameDurationWithCFR() async throws {
        videoProcessor.mockFrameDurations = Array(repeating: CMTime(seconds: 1/30.0, preferredTimescale: 600), count: 30)

        let frameDuration = try await videoProcessor.detectFrameDuration()
        let expectedDuration = CMTime(seconds: 1/30.0, preferredTimescale: 600)
        XCTAssertEqual(frameDuration, expectedDuration, "Should detect 30fps frame duration for CFR video")
    }

    func testDetectFrameDurationWithVFR() async throws {
        // Mix of different frame durations
        videoProcessor.mockFrameDurations = [
            CMTime(seconds: 1/30.0, preferredTimescale: 600), // 33.33ms
            CMTime(seconds: 1/24.0, preferredTimescale: 600), // 41.67ms
            CMTime(seconds: 1/30.0, preferredTimescale: 600), // 33.33ms
            CMTime(seconds: 1/60.0, preferredTimescale: 600), // 16.67ms
        ]

        let frameDuration = try await videoProcessor.detectFrameDuration()
        let expectedAvg = CMTime(seconds: 1/36.0, preferredTimescale: 600) // Average approximation
        XCTAssertEqual(frameDuration, expectedAvg, accuracy: CMTime(seconds: 0.01, preferredTimescale: 600))
    }

    func testDetectFrameDurationHandlesEmptyFrameDurations() async throws {
        videoProcessor.mockFrameDurations = []

        let frameDuration = try await videoProcessor.detectFrameDuration()
        // Should return safe default of 30fps
        let expectedDuration = CMTime(seconds: 1/30.0, preferredTimescale: 600)
        XCTAssertEqual(frameDuration, expectedDuration, "Should return default 30fps for empty frame durations")
    }

    func testDetectFrameDurationHandlesSingleFrame() async throws {
        videoProcessor.mockFrameDurations = [CMTime(seconds: 1/25.0, preferredTimescale: 600)]

        let frameDuration = try await videoProcessor.detectFrameDuration()
        let expectedDuration = CMTime(seconds: 1/25.0, preferredTimescale: 600)
        XCTAssertEqual(frameDuration, expectedDuration, "Should use single frame duration")
    }

    // MARK: - Error Handling Tests

    func testDetectFrameDurationThrowsErrorOnZeroDuration() async throws {
        videoProcessor.mockFrameDurations = [CMTime.zero]

        await XCTAssertThrowsError(
            try await videoProcessor.detectFrameDuration()
        ) { error in
            XCTAssertEqual(error as? VideoProcessor.FrameDetectionError, .invalidFrameDuration)
        }
    }

    func testDetectFrameDurationThrowsErrorOnNegativeDuration() async throws {
        videoProcessor.mockFrameDurations = [CMTime(seconds: -1/30.0, preferredTimescale: 600)]

        await XCTAssertThrowsError(
            try await videoProcessor.detectFrameDuration()
        ) { error in
            XCTAssertEqual(error as? VideoProcessor.FrameDetectionError, .invalidFrameDuration)
        }
    }

    func testDetectFrameDurationHandlesInsufficientFramesForCFR() async throws {
        videoProcessor.mockFrameDurations = Array(repeating: CMTime(seconds: 1/30.0, preferredTimescale: 600), count: 29)

        let frameDuration = try await videoProcessor.detectFrameDuration()
        // Should fall back to VFR calculation
        let expectedDuration = CMTime(seconds: 1/30.0, preferredTimescale: 600)
        XCTAssertEqual(frameDuration, expectedDuration, "Should fall back to VFR for insufficient CFR frames")
    }
}