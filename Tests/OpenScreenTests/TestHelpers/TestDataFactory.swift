import Foundation
import CoreMedia
import CoreGraphics
import AVFoundation
@testable import OpenScreen

/// Factory for creating test data
enum TestDataFactory {
    /// Creates a test recording
    static func makeTestRecording(
        id: UUID = UUID(),
        url: URL? = nil,
        duration: TimeInterval = 60,
        hasAudio: Bool = true
    ) -> Recording {
        let testURL = url ?? FileManager.default.temporaryDirectory
            .appendingPathComponent("test_\(UUID().uuidString).mov")

        return Recording(
            id: id,
            url: testURL,
            createdAt: Date(),
            duration: CMTime(seconds: duration, preferredTimescale: 600),
            displayID: CGMainDisplayID(),
            frameSize: CGSize(width: 1920, height: 1080),
            hasAudio: hasAudio
        )
    }

    /// Creates a test recording URL
    static func makeTestRecordingURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("test_recording_\(UUID().uuidString).mov")
    }

    /// Creates a test AVComposition (valid asset for testing)
    static func makeTestAVAsset(duration: TimeInterval = 60) -> AVAsset {
        let composition = AVMutableComposition()

        // Add empty video track
        composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)

        // Set composition duration
        let timeRange = CMTimeRange(
            start: .zero,
            duration: CMTime(seconds: duration, preferredTimescale: 600)
        )

        // Note: This creates a valid but empty composition
        // For frame extraction tests, we'll need actual video content
        return composition
    }

    /// Creates a test VideoClip
    static func makeTestVideoClip(
        id: UUID = UUID(),
        name: String = "Test Clip",
        speed: Float = 1.0,
        sourceDuration: TimeInterval = 10,
        timelineStart: CMTime = .zero
    ) -> VideoClip {
        let asset = makeTestAVAsset(duration: sourceDuration)
        let sourceRange = CMTimeRange(
            start: .zero,
            end: CMTime(seconds: sourceDuration, preferredTimescale: 600)
        )
        let timelineRange = CMTimeRange(
            start: timelineStart,
            end: CMTime(seconds: sourceDuration, preferredTimescale: 600)
        )
        let trackID = UUID()

        return VideoClip(
            id: id,
            name: name,
            asset: asset,
            timeRangeInSource: sourceRange,
            timeRangeInTimeline: timelineRange,
            trackID: trackID,
            speed: speed
        )
    }

    // MARK: - Timeline UI Models

    /// Creates a test SnapPoint with default values
    static func makeSnapPoint(
        position: Double = 5.0,
        timescale: CMTimeScale = 600,
        type: SnapPointType = .clipEdge,
        source: String? = nil
    ) -> SnapPoint {
        let time = CMTime(seconds: position, preferredTimescale: timescale)
        return SnapPoint(position: time, type: type, source: source)
    }

    /// Creates a test SnapPoint at time zero
    static func makeSnapPointAtZero(type: SnapPointType = .trackBoundary) -> SnapPoint {
        return SnapPoint(position: .zero, type: type)
    }

    /// Creates a test SnapResult with default values
    static func makeSnapResult(
        snapPosition: Double = 5.0,
        originalPosition: Double = 4.8,
        type: SnapPointType = .clipEdge,
        source: String? = nil
    ) -> SnapResult {
        let snapPoint = makeSnapPoint(position: snapPosition, type: type, source: source)
        let original = CMTime(seconds: originalPosition, preferredTimescale: 600)
        let snapped = CMTime(seconds: snapPosition, preferredTimescale: 600)
        return SnapResult(snapPoint: snapPoint, originalPosition: original, snappedPosition: snapped)
    }

    /// Creates a test ClipLayout with default values
    static func makeClipLayout(
        clipID: UUID = UUID(),
        x: CGFloat = 100,
        y: CGFloat = 0,
        width: CGFloat = 200,
        height: CGFloat = 60,
        startTime: Double = 0,
        duration: Double = 5.0,
        isDirty: Bool = false
    ) -> ClipLayout {
        let frame = CGRect(x: x, y: y, width: width, height: height)
        let timeRange = CMTimeRange(
            start: CMTime(seconds: startTime, preferredTimescale: 600),
            duration: CMTime(seconds: duration, preferredTimescale: 600)
        )
        return ClipLayout(clipID: clipID, frame: frame, timeRange: timeRange, isDirty: isDirty)
    }

    /// Creates a zero ClipLayout (all zeros)
    static func makeZeroClipLayout(clipID: UUID = UUID()) -> ClipLayout {
        return ClipLayout(clipID: clipID, frame: .zero, timeRange: .zero, isDirty: false)
    }

    /// Creates a test ClipTrack
    static func makeTestClipTrack(
        id: UUID = UUID(),
        name: String = "Test Track",
        type: TrackType = .video,
        clips: [VideoClip] = []
    ) -> ClipTrack {
        let track = ClipTrack(id: id, name: name, type: type)
        track.clips = clips
        return track
    }

    // MARK: - Timeline Coordinators

    /// Creates a test ClipLayoutCache with default settings
    static func makeClipLayoutCache() -> ClipLayoutCache {
        return ClipLayoutCache()
    }

    /// Creates a test SnappingCoordinator with default settings
    static func makeSnappingCoordinator(
        snapTolerance: TimeInterval = 0.5,
        timeIncrement: TimeInterval = 1.0
    ) -> SnappingCoordinator {
        return SnappingCoordinator(snapTolerance: snapTolerance, timeIncrement: timeIncrement)
    }

    /// Creates a test UndoRedoCoordinator
    static func makeUndoRedoCoordinator(editorState: EditorState) -> UndoRedoCoordinator {
        return UndoRedoCoordinator(editorState: editorState)
    }

    // MARK: - Transition Test Helpers

    /// Creates a test transition with default values
    static func makeTestTransition(
        type: TransitionType = .crossfade,
        duration: Double = 1.0,
        leadingClipID: UUID? = nil,
        trailingClipID: UUID? = nil,
        isEnabled: Bool = true
    ) -> TransitionClip {
        let leadingID = leadingClipID ?? UUID()
        let trailingID = trailingClipID ?? UUID()

        return TransitionClip(
            type: type,
            duration: CMTime(seconds: duration, preferredTimescale: 600),
            leadingClipID: leadingID,
            trailingClipID: trailingID,
            isEnabled: isEnabled
        )
    }

    /// Creates a test crossfade transition
    static func makeTestCrossfade(
        duration: Double = 1.0,
        leadingClipID: UUID? = nil,
        trailingClipID: UUID? = nil
    ) -> TransitionClip {
        return makeTestTransition(
            type: .crossfade,
            duration: duration,
            leadingClipID: leadingClipID,
            trailingClipID: trailingClipID
        )
    }

    /// Creates a test wipe transition
    static func makeTestWipe(
        direction: WipeDirection = .left,
        duration: Double = 1.0,
        leadingClipID: UUID? = nil,
        trailingClipID: UUID? = nil
    ) -> TransitionClip {
        let transition = makeTestTransition(
            type: .wipe,
            duration: duration,
            leadingClipID: leadingClipID,
            trailingClipID: trailingClipID
        )

        return transition.withParameters(
            .wipe(direction: direction, softness: 0.2, borderWidth: 0)
        )
    }

    /// Creates a test iris transition
    static func makeTestIris(
        shape: IrisShape = .circle,
        duration: Double = 1.5,
        leadingClipID: UUID? = nil,
        trailingClipID: UUID? = nil
    ) -> TransitionClip {
        let transition = makeTestTransition(
            type: .iris,
            duration: duration,
            leadingClipID: leadingClipID,
            trailingClipID: trailingClipID
        )

        return transition.withParameters(
            .iris(shape: shape, position: CGPoint(x: 0.5, y: 0.5), softness: 0.3)
        )
    }

    // MARK: - Enhanced Transition Helpers

    /// Creates a basic transition with full parameter control
    static func makeTransition(
        type: TransitionType = .crossfade,
        duration: CMTime = CMTime(seconds: 1.0, preferredTimescale: 600),
        leadingClipID: UUID = UUID(),
        trailingClipID: UUID = UUID(),
        parameters: TransitionParameters? = nil,
        isEnabled: Bool = true
    ) -> TransitionClip {
        return TransitionClip(
            type: type,
            duration: duration,
            leadingClipID: leadingClipID,
            trailingClipID: trailingClipID,
            parameters: parameters,
            isEnabled: isEnabled
        )
    }

    /// Creates a crossfade transition with specified duration
    static func makeCrossfadeTransition(
        duration: CMTime = CMTime(seconds: 1.0, preferredTimescale: 600)
    ) -> TransitionClip {
        return makeTransition(
            type: .crossfade,
            duration: duration
        )
    }

    /// Creates a fade to color transition
    static func makeFadeToColorTransition(
        color: TransitionColor = .black,
        holdDuration: Double = 0.5,
        duration: CMTime = CMTime(seconds: 1.5, preferredTimescale: 600)
    ) -> TransitionClip {
        return makeTransition(
            type: .fadeToColor,
            duration: duration,
            parameters: .fadeToColor(color: color, holdDuration: holdDuration)
        )
    }

    /// Creates a wipe transition with specified parameters
    static func makeWipeTransition(
        direction: WipeDirection = .left,
        softness: Double = 0.2,
        borderWidth: Double = 0.0,
        duration: CMTime = CMTime(seconds: 1.0, preferredTimescale: 600)
    ) -> TransitionClip {
        return makeTransition(
            type: .wipe,
            duration: duration,
            parameters: .wipe(direction: direction, softness: softness, borderWidth: borderWidth)
        )
    }

    /// Creates an iris transition with specified parameters
    static func makeIrisTransition(
        shape: IrisShape = .circle,
        position: CGPoint = CGPoint(x: 0.5, y: 0.5),
        softness: Double = 0.3,
        duration: CMTime = CMTime(seconds: 1.5, preferredTimescale: 600)
    ) -> TransitionClip {
        return makeTransition(
            type: .iris,
            duration: duration,
            parameters: .iris(shape: shape, position: position, softness: softness)
        )
    }

    /// Creates a blinds transition with specified parameters
    static func makeBlindsTransition(
        orientation: BlindsOrientation = .vertical,
        slatCount: Int = 10,
        duration: CMTime = CMTime(seconds: 1.0, preferredTimescale: 600)
    ) -> TransitionClip {
        return makeTransition(
            type: .blinds,
            duration: duration,
            parameters: .blinds(orientation: orientation, slatCount: slatCount)
        )
    }

    // MARK: - Edge Case Transition Helpers

    /// Creates a transition with invalid (too long) duration
    static func makeTransitionWithInvalidDuration() -> TransitionClip {
        // Duration exceeds typical maximum (e.g., 10 seconds)
        return makeTransition(
            type: .crossfade,
            duration: CMTime(seconds: 10.0, preferredTimescale: 600)
        )
    }

    /// Creates a transition with minimum valid duration (0.1 seconds)
    static func makeTransitionWithMinimumDuration() -> TransitionClip {
        return makeTransition(
            type: .crossfade,
            duration: CMTime(seconds: 0.1, preferredTimescale: 600)
        )
    }

    /// Creates a custom transition with custom parameters
    static func makeTransitionWithCustomParameters() -> TransitionClip {
        return makeTransition(
            type: .custom("myCustomTransition"),
            duration: CMTime(seconds: 1.0, preferredTimescale: 600),
            parameters: .custom(parameters: ["param1": 1.0, "param2": 2.0])
        )
    }

    // MARK: - VideoClip + Transition Helpers

    /// Creates overlapping clips with a valid transition
    /// Leading clip: 0-5s, Trailing clip: 3-8s (2s overlap), Transition: 1s duration
    static func makeOverlappingClipsWithTransition() -> (
        leading: VideoClip,
        trailing: VideoClip,
        transition: TransitionClip
    ) {
        let leadingClip = VideoClip(
            name: "Leading Clip",
            asset: makeTestAVAsset(duration: 5.0),
            timeRangeInSource: CMTimeRange(
                start: .zero,
                end: CMTime(seconds: 5.0, preferredTimescale: 600)
            ),
            timeRangeInTimeline: CMTimeRange(
                start: .zero,
                end: CMTime(seconds: 5.0, preferredTimescale: 600)
            ),
            trackID: UUID()
        )

        let trailingClip = VideoClip(
            name: "Trailing Clip",
            asset: makeTestAVAsset(duration: 5.0),
            timeRangeInSource: CMTimeRange(
                start: .zero,
                end: CMTime(seconds: 5.0, preferredTimescale: 600)
            ),
            timeRangeInTimeline: CMTimeRange(
                start: CMTime(seconds: 3.0, preferredTimescale: 600),
                end: CMTime(seconds: 8.0, preferredTimescale: 600)
            ),
            trackID: UUID()
        )

        let transition = makeTransition(
            type: .crossfade,
            duration: CMTime(seconds: 1.0, preferredTimescale: 600),
            leadingClipID: leadingClip.id,
            trailingClipID: trailingClip.id
        )

        return (leadingClip, trailingClip, transition)
    }

    /// Creates non-overlapping clips with an invalid transition
    /// Leading clip: 0-3s, Trailing clip: 4-7s (no overlap), Transition: 1s duration
    /// This configuration should fail validation
    static func makeNonOverlappingClipsWithTransition() -> (
        leading: VideoClip,
        trailing: VideoClip,
        transition: TransitionClip
    ) {
        let leadingClip = VideoClip(
            name: "Leading Clip",
            asset: makeTestAVAsset(duration: 3.0),
            timeRangeInSource: CMTimeRange(
                start: .zero,
                end: CMTime(seconds: 3.0, preferredTimescale: 600)
            ),
            timeRangeInTimeline: CMTimeRange(
                start: .zero,
                end: CMTime(seconds: 3.0, preferredTimescale: 600)
            ),
            trackID: UUID()
        )

        let trailingClip = VideoClip(
            name: "Trailing Clip",
            asset: makeTestAVAsset(duration: 3.0),
            timeRangeInSource: CMTimeRange(
                start: .zero,
                end: CMTime(seconds: 3.0, preferredTimescale: 600)
            ),
            timeRangeInTimeline: CMTimeRange(
                start: CMTime(seconds: 4.0, preferredTimescale: 600),
                end: CMTime(seconds: 7.0, preferredTimescale: 600)
            ),
            trackID: UUID()
        )

        let transition = makeTransition(
            type: .crossfade,
            duration: CMTime(seconds: 1.0, preferredTimescale: 600),
            leadingClipID: leadingClip.id,
            trailingClipID: trailingClip.id
        )

        return (leadingClip, trailingClip, transition)
    }

    /// Creates a sequence of clips for testing
    @MainActor
    static func makeClipSequence(count: Int) -> [VideoClip] {
        var clips: [VideoClip] = []
        var currentTime = CMTime.zero

        for i in 0..<count {
            let duration = CMTime(seconds: 3.0, preferredTimescale: 600)
            let clip = VideoClip(
                name: "Clip \(i + 1)",
                asset: makeTestAVAsset(duration: 3.0),
                timeRangeInSource: CMTimeRange(start: .zero, end: duration),
                timeRangeInTimeline: CMTimeRange(start: currentTime, end: CMTimeAdd(currentTime, duration)),
                trackID: UUID()
            )
            clips.append(clip)
            currentTime = CMTimeAdd(currentTime, duration)
        }

        return clips
    }

    /// Creates a sequence of overlapping clips for testing multiple transitions
    @MainActor
    static func makeOverlappingClipsSequence(count: Int) -> [VideoClip] {
        var clips: [VideoClip] = []
        var currentTime = CMTime.zero
        let clipDuration = CMTime(seconds: 5.0, preferredTimescale: 600)
        let overlapDuration = CMTime(seconds: 1.0, preferredTimescale: 600)

        for i in 0..<count {
            let clip = VideoClip(
                name: "Clip \(i + 1)",
                asset: makeTestAVAsset(duration: 5.0),
                timeRangeInSource: CMTimeRange(start: .zero, end: clipDuration),
                timeRangeInTimeline: CMTimeRange(start: currentTime, end: CMTimeAdd(currentTime, clipDuration)),
                trackID: UUID()
            )
            clips.append(clip)

            // Overlap by 1 second for next clip
            currentTime = CMTimeAdd(currentTime, CMTimeSubtract(clipDuration, overlapDuration))
        }

        return clips
    }
}
