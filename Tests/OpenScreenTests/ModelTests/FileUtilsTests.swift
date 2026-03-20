import XCTest
@testable import OpenScreen

final class FileUtilsTests: XCTestCase {
    func testCreateDirectory() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_\(UUID().uuidString)")

        try FileUtils.createDirectory(at: tempDir)

        var isDirectory: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempDir.path, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)

        // Cleanup
        try FileManager.default.removeItem(at: tempDir)
    }

    func testCreateDirectoryIdempotent() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_\(UUID().uuidString)")

        try FileUtils.createDirectory(at: tempDir)
        try FileUtils.createDirectory(at: tempDir)  // Should not throw

        // Cleanup
        try FileManager.default.removeItem(at: tempDir)
    }

    func testRecordingsDirectory() throws {
        let dir = try FileUtils.recordingsDirectory()
        XCTAssertTrue(dir.path.contains("Movies"))
        XCTAssertTrue(dir.path.contains("OpenScreenNative"))
    }

    func testGenerateRecordingFilename() {
        let filename = FileUtils.generateRecordingFilename()
        XCTAssertTrue(filename.hasPrefix("Recording_"))
        XCTAssertTrue(filename.hasSuffix(".mov"))
        XCTAssertTrue(filename.contains("_"))
    }

    func testGenerateRecordingFilenameUniqueness() {
        var filenames: [String] = []
        for _ in 0..<10 {
            filenames.append(FileUtils.generateRecordingFilename())
            Thread.sleep(forTimeInterval: 0.002) // Small delay to ensure different timestamps
        }
        let uniqueFilenames = Set(filenames)
        XCTAssertEqual(uniqueFilenames.count, 10, "Filenames should be unique")
    }

    func testUniqueRecordingURL() throws {
        let url = try FileUtils.uniqueRecordingURL()
        XCTAssertTrue(url.path.contains("Movies"))
        XCTAssertTrue(url.path.contains("OpenScreenNative"))
        XCTAssertTrue(url.lastPathComponent.hasPrefix("Recording_"))
        XCTAssertTrue(url.lastPathComponent.hasSuffix(".mov"))
    }
}
