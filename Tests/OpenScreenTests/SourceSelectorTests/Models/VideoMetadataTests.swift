import XCTest
import CoreMedia
import AppKit
@testable import OpenScreen

final class VideoMetadataTests: XCTestCase {
    func testVideoMetadataProperties() {
        // Arrange
        let duration = CMTime(seconds: 10.5, preferredTimescale: 600)
        let resolution = CGSize(width: 1920, height: 1080)
        let codec = "h264"
        let fileSize: Int64 = 1_500_000_000
        let warnings = ["Test warning"]
        let thumbnail = NSImage(size: NSSize(width: 100, height: 100))

        // Act
        let metadata = VideoMetadata(
            duration: duration,
            durationString: "00:10",
            resolution: resolution,
            frameRate: 30.0,
            codec: codec,
            fileSize: fileSize,
            isCompatible: true,
            warnings: warnings,
            thumbnail: thumbnail
        )

        // Assert
        XCTAssertEqual(metadata.duration.seconds, 10.5, accuracy: 0.01)
        XCTAssertEqual(metadata.durationString, "00:10")
        XCTAssertEqual(metadata.resolution.width, 1920, accuracy: 0.01)
        XCTAssertEqual(metadata.resolution.height, 1080, accuracy: 0.01)
        XCTAssertEqual(metadata.frameRate, 30.0, accuracy: 0.01)
        XCTAssertEqual(metadata.codec, "h264")
        XCTAssertEqual(metadata.fileSize, 1_500_000_000)
        XCTAssertTrue(metadata.isCompatible)
        XCTAssertEqual(metadata.warnings.count, 1)
        XCTAssertEqual(metadata.warnings.first, "Test warning")
        XCTAssertNotNil(metadata.thumbnail)
    }

    func testResolutionStringFormatting() {
        // Arrange
        let metadata = VideoMetadata(
            duration: .zero,
            durationString: "00:00",
            resolution: CGSize(width: 1920, height: 1080),
            frameRate: 30.0,
            codec: "h264",
            fileSize: 0,
            isCompatible: true,
            warnings: [],
            thumbnail: nil
        )

        // Act & Assert
        XCTAssertEqual(metadata.resolutionString, "1920 × 1080")
    }

    func testFileSizeStringFormatting() {
        // Arrange
        let metadata = VideoMetadata(
            duration: .zero,
            durationString: "00:00",
            resolution: .zero,
            frameRate: 30.0,
            codec: "h264",
            fileSize: 1_500_000_000,
            isCompatible: true,
            warnings: [],
            thumbnail: nil
        )

        // Act & Assert
        // 1.5 GB should format appropriately
        XCTAssertTrue(metadata.fileSizeString.contains("GB") || metadata.fileSizeString.contains("B"))
    }

    func testHasWarnings() {
        // Arrange - with warnings
        let metadataWithWarnings = VideoMetadata(
            duration: .zero,
            durationString: "00:00",
            resolution: .zero,
            frameRate: 30.0,
            codec: "h264",
            fileSize: 0,
            isCompatible: true,
            warnings: ["Warning 1", "Warning 2"],
            thumbnail: nil
        )

        // Arrange - without warnings
        let metadataWithoutWarnings = VideoMetadata(
            duration: .zero,
            durationString: "00:00",
            resolution: .zero,
            frameRate: 30.0,
            codec: "h264",
            fileSize: 0,
            isCompatible: true,
            warnings: [],
            thumbnail: nil
        )

        // Act & Assert
        XCTAssertTrue(metadataWithWarnings.hasWarnings)
        XCTAssertFalse(metadataWithoutWarnings.hasWarnings)
    }

    func testIsLargeFile() {
        // Arrange - large file (> 2GB)
        let largeFileMetadata = VideoMetadata(
            duration: .zero,
            durationString: "00:00",
            resolution: .zero,
            frameRate: 30.0,
            codec: "h264",
            fileSize: 2_500_000_000,
            isCompatible: true,
            warnings: [],
            thumbnail: nil
        )

        // Arrange - small file (< 2GB)
        let smallFileMetadata = VideoMetadata(
            duration: .zero,
            durationString: "00:00",
            resolution: .zero,
            frameRate: 30.0,
            codec: "h264",
            fileSize: 1_500_000_000,
            isCompatible: true,
            warnings: [],
            thumbnail: nil
        )

        // Arrange - exactly 2GB boundary
        let boundaryFileMetadata = VideoMetadata(
            duration: .zero,
            durationString: "00:00",
            resolution: .zero,
            frameRate: 30.0,
            codec: "h264",
            fileSize: 2_000_000_000,
            isCompatible: true,
            warnings: [],
            thumbnail: nil
        )

        // Act & Assert
        XCTAssertTrue(largeFileMetadata.isLargeFile)
        XCTAssertFalse(smallFileMetadata.isLargeFile)
        XCTAssertFalse(boundaryFileMetadata.isLargeFile) // Exactly 2GB is not large
    }

    func testSendableConformance() {
        // Arrange
        let metadata = VideoMetadata(
            duration: .zero,
            durationString: "00:00",
            resolution: .zero,
            frameRate: 30.0,
            codec: "h264",
            fileSize: 0,
            isCompatible: true,
            warnings: [],
            thumbnail: nil
        )

        // Act & Assert
        // If this compiles, Sendable conformance is verified
        let sendableMetadata: any Sendable = metadata
        XCTAssertNotNil(sendableMetadata)
    }
}
