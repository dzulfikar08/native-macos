import XCTest
import AVFoundation
import CoreMedia
@testable import OpenScreen

final class VideoValidatorTests: XCTestCase {

    // MARK: - Format Support Tests

    func testIsSupportedFormat_MP4() {
        let mp4URL = URL(fileURLWithPath: "/test/video.mp4")
        XCTAssertTrue(VideoValidator.isSupportedFormat(url: mp4URL))
    }

    func testIsSupportedFormat_MOV() {
        let movURL = URL(fileURLWithPath: "/test/video.mov")
        XCTAssertTrue(VideoValidator.isSupportedFormat(url: movURL))
    }

    func testIsSupportedFormat_Unsupported() {
        let txtURL = URL(fileURLWithPath: "/test/file.txt")
        XCTAssertFalse(VideoValidator.isSupportedFormat(url: txtURL))
    }

    func testIsSupportedFormat_UnknownExtension() {
        let unknownURL = URL(fileURLWithPath: "/test/file.xyz")
        XCTAssertFalse(VideoValidator.isSupportedFormat(url: unknownURL))
    }

    // MARK: - Validation Error Tests

    func testValidate_FileNotFound() {
        let nonExistentURL = URL(fileURLWithPath: "/nonexistent/path/to/video.mp4")

        let result = VideoValidator.validate(url: nonExistentURL)

        switch result {
        case .failure(let error):
            if case .fileNotFound = error {
                XCTAssertTrue(true)
            } else {
                XCTFail("Expected fileNotFound error, got: \(error)")
            }
        case .success:
            XCTFail("Expected failure for non-existent file")
        }
    }

    func testValidate_UnsupportedFormat() {
        // Create a temporary text file to test unsupported format
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_\(UUID().uuidString).txt")

        try? "dummy content".write(to: tempURL, atomically: true, encoding: .utf8)
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        let result = VideoValidator.validate(url: tempURL)

        switch result {
        case .failure(let error):
            if case .unsupportedFormat = error {
                XCTAssertTrue(true)
            } else {
                XCTFail("Expected unsupportedFormat error, got: \(error)")
            }
        case .success:
            XCTFail("Expected failure for unsupported format")
        }
    }

    // MARK: - VideoValidationError Descriptions

    func testVideoValidationErrorDescription_FileNotFound() {
        let url = URL(fileURLWithPath: "/test/video.mp4")
        let error = VideoValidationError.fileNotFound(url)

        let description = error.localizedDescription
        XCTAssertTrue(description.contains("File not found"))
        XCTAssertTrue(description.contains("video.mp4"))
    }

    func testVideoValidationErrorDescription_UnsupportedFormat() {
        let error = VideoValidationError.unsupportedFormat("txt")

        let description = error.localizedDescription
        XCTAssertTrue(description.contains("Unsupported format"))
        XCTAssertTrue(description.contains("txt"))
    }

    func testVideoValidationErrorDescription_CorruptedFile() {
        let error = VideoValidationError.corruptedFile

        let description = error.localizedDescription
        XCTAssertTrue(description.contains("corrupted"))
    }

    func testVideoValidationErrorDescription_TooLarge() {
        let error = VideoValidationError.tooLarge(5_000_000_000)

        let description = error.localizedDescription
        XCTAssertTrue(description.contains("very large"))
        XCTAssertTrue(description.contains("5.0"))
    }

    func testVideoValidationErrorDescription_NoVideoTrack() {
        let error = VideoValidationError.noVideoTrack

        let description = error.localizedDescription
        XCTAssertTrue(description.contains("No video track"))
    }
}
