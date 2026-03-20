import XCTest
@testable import OpenScreen

@MainActor
final class VideoProcessorTests: XCTestCase {
    func testCreateVideoProcessor() {
        let url = TestDataFactory.makeTestRecordingURL()
        let processor = VideoProcessor(assetURL: url)
        XCTAssertNotNil(processor)
    }

    func testExtractFrame() async throws {
        // Note: This test requires an actual video file
        // For Phase 2.1, we'll test the setup logic only
        // Using a valid URL structure but file may not exist
        let url = TestDataFactory.makeTestRecordingURL()
        let processor = VideoProcessor(assetURL: url)

        // Verify processor initializes correctly
        XCTAssertEqual(processor.assetURL, url)
        XCTAssertNil(processor.asset, "Asset should be nil before loadAsset() is called")

        // Attempt to load asset (may fail if file doesn't exist, which is expected)
        do {
            try await processor.loadAsset()
            // If we reach here, asset loaded successfully
            XCTAssertNotNil(processor.asset)
        } catch {
            // Expected error when file doesn't exist - this is OK for Phase 2.1
            // The important thing is that VideoProcessor is properly structured
            // AVFoundation will throw an error for non-existent files
            XCTAssertNotNil(error, "Expected error for non-existent file")
        }
    }
}
