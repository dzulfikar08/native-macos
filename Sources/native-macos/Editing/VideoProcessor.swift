import AVFoundation
import CoreMedia

/// Processes video files and extracts frames
@MainActor
final class VideoProcessor {
    let assetURL: URL
    private(set) var asset: AVAsset?
    private nonisolated(unsafe) var assetReader: AVAssetReader?
    private var videoTrackOutput: AVAssetReaderTrackOutput?

    // MARK: - Playback Rate Properties
    var playbackRate: Float = 1.0
    var audioRate: Float = 1.0
    private var frameSkipCount: Int = 0
    private var isReversePlayback: Bool = false
    private var reverseReader: AVAssetReader?

    // MARK: - Testing Properties
    var mockFrameDurations: [CMTime] = []

    init(assetURL: URL) {
        self.assetURL = assetURL
    }

    func loadAsset() async throws {
        let asset = AVAsset(url: assetURL)
        self.asset = asset

        // Load asset properties asynchronously
        _ = try await asset.load(.duration)
        let tracks = try await asset.load(.tracks)

        guard !tracks.isEmpty else {
            throw VideoError.noVideoTrack
        }
    }

    func createAssetReader() async throws {
        guard let asset = asset else {
            throw VideoError.assetNotLoaded
        }

        let assetReader = try AVAssetReader(asset: asset)
        self.assetReader = assetReader

        // Configure video track output using modern async API
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = videoTracks.first else {
            throw VideoError.noVideoTrack
        }

        let outputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]

        let trackOutput = AVAssetReaderTrackOutput(
            track: videoTrack,
            outputSettings: outputSettings
        )
        trackOutput.alwaysCopiesSampleData = false
        self.videoTrackOutput = trackOutput

        assetReader.add(trackOutput)
    }

    func startReading() throws {
        assetReader?.startReading()
    }

    func getNextFrame() -> CMSampleBuffer? {
        return videoTrackOutput?.copyNextSampleBuffer()
    }

    nonisolated func cancelReading() {
        assetReader?.cancelReading()
    }

    func seek(to time: CMTime) async throws {
        guard let asset = asset else {
            throw VideoError.assetNotLoaded
        }

        // Cancel current reading
        assetReader?.cancelReading()

        // Create new asset reader at seek position
        let assetReader = try AVAssetReader(asset: asset)
        self.assetReader = assetReader

        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = videoTracks.first else {
            throw VideoError.noVideoTrack
        }

        let outputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]

        let trackOutput = AVAssetReaderTrackOutput(
            track: videoTrack,
            outputSettings: outputSettings
        )
        trackOutput.alwaysCopiesSampleData = false
        self.videoTrackOutput = trackOutput

        assetReader.add(trackOutput)
        assetReader.startReading()
    }

    deinit {
        // Cleanup AVAssetReader to prevent resource leaks
        // AVAssetReader.cancelReading() is thread-safe
        assetReader?.cancelReading()
        // Note: reverseReader is only accessed on main actor
    }

    enum VideoError: LocalizedError {
        case assetNotLoaded
        case noVideoTrack

        var errorDescription: String? {
            switch self {
            case .assetNotLoaded:
                return "Asset not loaded. Call loadAsset() first"
            case .noVideoTrack:
                return "No video track found in asset"
            }
        }
    }

    // MARK: - Playback Rate Methods

    /// Observes EditorState.playbackRate changes and updates processor
    func observePlaybackRate(editorState: EditorState) {
        let newRate = editorState.playbackRate
        setPlaybackRate(newRate)
    }

    /// Sets the playback rate within valid range (-4x to +4x)
    func setPlaybackRate(_ rate: Float) {
        // Clamp rate to valid range [-4, 4]
        let clampedRate = max(-4.0, min(4.0, rate))
        playbackRate = clampedRate
        audioRate = clampedRate

        // Update reverse playback flag
        isReversePlayback = clampedRate < 0

        // Reset frame skip count when changing rate
        if abs(clampedRate - 1.0) < 0.01 {
            frameSkipCount = 0
        }
    }

    /// Increments frame skip count for 2x/4x speeds
    func incrementFrameSkipCount() {
        if abs(playbackRate) > 1.0 {
            frameSkipCount += 1
        }
    }

    /// Checks if loop boundary should be reached
    func checkLoopBoundary(time: CMTime, editorState: EditorState) -> Bool {
        guard let inPoint = editorState.inPoint, let outPoint = editorState.outPoint else {
            return false
        }

        if isReversePlayback {
            // For reverse playback, check if we hit the in-point
            return time <= inPoint
        } else {
            // For normal playback, check if we hit the out-point
            return time >= outPoint
        }
    }

    // MARK: - Frame Duration Detection Methods

    /// Detects frame duration asynchronously
    func detectFrameDuration() async throws -> CMTime {
        do {
            // Try to detect constant frame rate first
            if await isConstantFrameRate() {
                return await calculateAverageFrameDuration()
            } else {
                // Variable frame rate - use first 100 frames
                return try await calculateVFRFrameDuration()
            }
        } catch {
            // Return safe default on failure
            return CMTime(seconds: 1/30.0, preferredTimescale: 600)
        }
    }

    /// Checks if the video has constant frame rate (CFR)
    func isConstantFrameRate() async -> Bool {
        guard let asset = asset else { return false }

        do {
            let videoTracks = try await asset.loadTracks(withMediaType: .video)
            guard let videoTrack = videoTracks.first else { return false }

            // Read first 30 frames to check for consistency
            let frameDurations = await readFrameDurations(from: videoTrack, count: 30)

            guard let expectedDuration = frameDurations.first else { return false }

            // Check if all durations are within 1ms tolerance
            for duration in frameDurations {
                let tolerance = CMTime(seconds: 0.001, preferredTimescale: 600)
                if abs(CMTimeGetSeconds(duration - expectedDuration)) > CMTimeGetSeconds(tolerance) {
                    return false
                }
            }

            return true
        } catch {
            return false
        }
    }

    /// Calculates average frame duration for VFR videos
    func calculateAverageFrameDuration() async -> CMTime {
        guard let asset = asset else { return CMTime(seconds: 1/30.0, preferredTimescale: 600) }

        do {
            let videoTracks = try await asset.loadTracks(withMediaType: .video)
            guard let videoTrack = videoTracks.first else { return CMTime(seconds: 1/30.0, preferredTimescale: 600) }

            // Read first 100 frames or as many as available
            let frameDurations = await readFrameDurations(from: videoTrack, count: 100)

            guard !frameDurations.isEmpty else { return CMTime(seconds: 1/30.0, preferredTimescale: 600) }

            // Calculate average
            let totalSeconds = frameDurations.reduce(0.0) { $0 + CMTimeGetSeconds($1) }
            let avgSeconds = totalSeconds / Double(frameDurations.count)

            return CMTime(seconds: avgSeconds, preferredTimescale: 600)
        } catch {
            return CMTime(seconds: 1/30.0, preferredTimescale: 600)
        }
    }

    // MARK: - Private Methods

    private func readFrameDurations(from track: AVAssetTrack, count: Int) async -> [CMTime] {
        var durations: [CMTime] = []

        do {
            // Create temporary asset reader to read durations
            let assetReader = try AVAssetReader(asset: AVAsset(url: assetURL))
            let outputSettings: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]

            let trackOutput = AVAssetReaderTrackOutput(
                track: track,
                outputSettings: outputSettings
            )

            guard assetReader.canAdd(trackOutput) else { return [] }
            assetReader.add(trackOutput)

            guard assetReader.startReading() else { return [] }

            while durations.count < count, assetReader.status == .reading {
                if let sampleBuffer = trackOutput.copyNextSampleBuffer() {
                    durations.append(sampleBuffer.presentationTimeStamp)
                }
            }

            return durations
        } catch {
            return []
        }
    }

    private func calculateVFRFrameDuration() async throws -> CMTime {
        let avgDuration = await calculateAverageFrameDuration()

        // Validate the duration
        if CMTimeGetSeconds(avgDuration) <= 0 {
            throw FrameDetectionError.invalidFrameDuration
        }

        return avgDuration
    }
}

// MARK: - Frame Detection Errors

enum FrameDetectionError: LocalizedError {
    case invalidFrameDuration

    var errorDescription: String? {
        switch self {
        case .invalidFrameDuration:
            return "Invalid frame duration detected"
        }
    }
}
