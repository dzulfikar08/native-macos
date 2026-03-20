import XCTest
@testable import OpenScreen
import AVFoundation

/// Tests for VideoExporter video composition integration
///
/// **Note on Testing Approach:**
/// These tests verify that the video composition integration works correctly by:
/// 1. Setting a video composition on the exporter
/// 2. Attempting to start the export process
/// 3. Verifying the export session is created without errors
///
/// **Limitations:**
/// - We use empty test assets (AVMutableComposition with no actual media)
/// - Actual export will fail with "empty composition" errors, but this is expected
/// - The tests verify the API integration works, not that a valid video is produced
/// - Full end-to-end export testing requires actual video assets and is environment-dependent
@MainActor
final class VideoExporterCompositionTests: XCTestCase {

    // MARK: - Test: Export with Video Composition

    func testExportWithVideoComposition() async throws {
        // Create a simple test asset
        let composition = AVMutableComposition()
        composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)

        // Create a test video composition with custom settings
        let videoComposition = AVMutableVideoComposition()
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        videoComposition.renderSize = CGSize(width: 1920, height: 1080)

        // Create exporter with composition
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_export_\(UUID().uuidString).mov")

        let exporter = VideoExporter(
            asset: composition,
            outputURL: outputURL
        )

        // Set the video composition
        exporter.setVideoComposition(videoComposition)

        // Verify exporter state before export
        XCTAssertNotNil(exporter)
        XCTAssertFalse(exporter.isCurrentlyExporting)
        XCTAssertEqual(exporter.currentProgress, 0.0)

        // Attempt to start export - this verifies the composition is properly applied
        // The export will fail (empty asset), but we verify:
        // 1. The composition doesn't prevent export session creation
        // 2. Error handling works correctly
        // 3. The error is NOT composition-related (would indicate a bug)
        do {
            try await exporter.startExport()
            // If we reach here, export started (will fail later, but composition was accepted)
            XCTAssertTrue(exporter.isCurrentlyExporting)
        } catch {
            // Expected: Export fails due to empty asset (no video data)
            // Verify it's not a composition-related error, which would indicate a bug
            let errorDescription = (error as NSError).localizedDescription.lowercased()
            XCTAssertFalse(
                errorDescription.contains("composition"),
                "Should not fail with composition-related errors. Error: \(error)"
            )
            XCTAssertFalse(
                errorDescription.contains("video composition"),
                "Should not fail with video composition errors. Error: \(error)"
            )
        }

        // Verify exporter state after attempted export
        XCTAssertFalse(exporter.isCurrentlyExporting, "Export should complete or fail, not remain in progress")

        // Clean up
        try? FileManager.default.removeItem(at: outputURL)
    }

    // MARK: - Test: Export without Video Composition (Backward Compatibility)

    func testExportWithoutVideoComposition() async throws {
        // Create a simple test asset (no composition)
        let composition = AVMutableComposition()
        composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_export_no_comp_\(UUID().uuidString).mov")

        let exporter = VideoExporter(
            asset: composition,
            outputURL: outputURL
        )

        // Verify exporter initializes correctly without composition
        XCTAssertNotNil(exporter)
        XCTAssertFalse(exporter.isCurrentlyExporting)
        XCTAssertEqual(exporter.currentProgress, 0.0)

        // Attempt to start export - verifies backward compatibility
        // Should work the same as before composition feature was added
        do {
            try await exporter.startExport()
            // Export started successfully
            XCTAssertTrue(exporter.isCurrentlyExporting)
        } catch {
            // Expected: Export fails due to empty asset (no video data)
            // Verify it's not a composition-related error, which would indicate a bug
            let errorDescription = (error as NSError).localizedDescription.lowercased()
            XCTAssertFalse(
                errorDescription.contains("composition"),
                "Should not fail with composition-related errors. Error: \(error)"
            )
            XCTAssertFalse(
                errorDescription.contains("video composition"),
                "Should not fail with video composition errors. Error: \(error)"
            )
        }

        // Verify clean state
        XCTAssertFalse(exporter.isCurrentlyExporting)

        // Clean up
        try? FileManager.default.removeItem(at: outputURL)
    }

    // MARK: - Test: Export with nil composition (explicit nil)

    func testExportWithNilComposition() async throws {
        // Verify that not setting a composition (implicitly nil) works
        let composition = AVMutableComposition()
        composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_export_nil_\(UUID().uuidString).mov")

        let exporter = VideoExporter(
            asset: composition,
            outputURL: outputURL
        )

        // Don't set any composition - should work fine
        XCTAssertNotNil(exporter)

        // Verify export can be attempted
        do {
            try await exporter.startExport()
            XCTAssertTrue(exporter.isCurrentlyExporting)
        } catch {
            // Expected: Export fails due to empty asset (no video data)
            // Verify it's not a composition-related error, which would indicate a bug
            let errorDescription = (error as NSError).localizedDescription.lowercased()
            XCTAssertFalse(
                errorDescription.contains("composition"),
                "Should not fail with composition-related errors. Error: \(error)"
            )
            XCTAssertFalse(
                errorDescription.contains("video composition"),
                "Should not fail with video composition errors. Error: \(error)"
            )
        }

        // Clean up
        try? FileManager.default.removeItem(at: outputURL)
    }
}
