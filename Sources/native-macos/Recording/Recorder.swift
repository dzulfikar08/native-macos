import Foundation
import AVFoundation

/// Protocol for recording implementations
///
/// Each recorder type (screen, webcam, future types) conforms to this protocol
/// with its own configuration type. This provides type safety while allowing
/// RecordingController to work with any recorder.
@MainActor protocol Recorder: AnyObject, Sendable {
    /// Configuration type for this recorder
    associatedtype Config: Sendable

    /// Start recording to specified URL with given configuration
    /// - Parameters:
    ///   - url: Output file URL
    ///   - config: Recorder-specific configuration
    /// - Throws: RecordingError if recording cannot start
    func startRecording(to url: URL, config: Config) async throws

    /// Stop current recording and return output URL
    /// - Returns: URL where recording was saved
    /// - Throws: RecordingError if stop fails
    func stopRecording() async throws -> URL

    /// Whether currently recording
    var isRecording: Bool { get }
}
