import Foundation

/// File system utilities for OpenScreen
enum FileUtils {
    /// Creates a directory at the specified URL if it doesn't exist
    static func createDirectory(at url: URL) throws {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false

        if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            if !isDirectory.boolValue {
                throw CocoaError(.fileWriteFileExists)
            }
            return
        }

        try fileManager.createDirectory(
            at: url,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    /// Returns the default recordings directory
    static func recordingsDirectory() throws -> URL {
        let fileManager = FileManager.default
        guard let moviesDir = fileManager.urls(for: .moviesDirectory, in: .userDomainMask).first else {
            throw CocoaError(.fileReadNoSuchFile)
        }

        let recordingsDir = moviesDir.appendingPathComponent("OpenScreenNative", isDirectory: true)
        try createDirectory(at: recordingsDir)

        return recordingsDir
    }

    /// Generates a unique filename for a recording
    static func generateRecordingFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss-SSS"
        let timestamp = formatter.string(from: Date())
        return "Recording_\(timestamp).mov"
    }

    /// Returns a unique URL for a new recording
    static func uniqueRecordingURL() throws -> URL {
        let directory = try recordingsDirectory()
        let filename = generateRecordingFilename()
        return directory.appendingPathComponent(filename)
    }
}
