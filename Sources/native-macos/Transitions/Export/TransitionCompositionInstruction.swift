import AVFoundation
import CoreMedia
import Foundation

/// Custom AVVideoCompositionInstruction that stores transition metadata
/// This allows us to preserve transition information that cannot be stored in userInfo
final class TransitionVideoCompositionInstruction: AVVideoCompositionInstruction, @unchecked Sendable {
    let transitionID: UUID
    let transitionType: String
    let transitionStart: CMTime
    let transitionDuration: CMTime
    let leadingTrackID: CMPersistentTrackID
    let trailingTrackID: CMPersistentTrackID

    init(
        transitionID: UUID,
        transitionType: String,
        transitionStart: CMTime,
        transitionDuration: CMTime,
        leadingTrackID: CMPersistentTrackID,
        trailingTrackID: CMPersistentTrackID
    ) {
        self.transitionID = transitionID
        self.transitionType = transitionType
        self.transitionStart = transitionStart
        self.transitionDuration = transitionDuration
        self.leadingTrackID = leadingTrackID
        self.trailingTrackID = trailingTrackID

        // Initialize with default time range
        super.init()
        // enablePostProcessing is read-only, defaults to false
    }

    // Required initializer for NSCoding compliance
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

/// Stores transition metadata and creates AVVideoCompositionInstruction instances
///
/// IMPORTANT: Cannot subclass AVMutableVideoCompositionInstruction (it's final in Objective-C runtime).
/// This wrapper class creates instructions and stores metadata separately in userInfo.
final class TransitionCompositionInstruction {

    // Store transition ID so compositor can look up full TransitionClip
    let transitionID: UUID

    // Store transition type and parameters for quick access without lookup
    let transitionType: TransitionType
    let transitionParameters: TransitionParameters

    // Transition timing for progress calculation
    let transitionStart: CMTime
    let transitionDuration: CMTime

    // Track IDs for fetching source frames
    let leadingTrackID: CMPersistentTrackID
    let trailingTrackID: CMPersistentTrackID

    // Time range for this instruction
    let timeRange: CMTimeRange

    init(
        transitionID: UUID,
        transitionType: TransitionType,
        transitionParameters: TransitionParameters,
        transitionStart: CMTime,
        transitionDuration: CMTime,
        leadingTrackID: CMPersistentTrackID,
        trailingTrackID: CMPersistentTrackID
    ) {
        self.transitionID = transitionID
        self.transitionType = transitionType
        self.transitionParameters = transitionParameters
        self.transitionStart = transitionStart
        self.transitionDuration = transitionDuration
        self.leadingTrackID = leadingTrackID
        self.trailingTrackID = trailingTrackID
        self.timeRange = CMTimeRange(start: transitionStart, end: CMTimeAdd(transitionStart, transitionDuration))
    }

    /// Creates the AVVideoCompositionInstruction for AVFoundation
    /// - Returns: Configured instruction with metadata stored in userInfo
    func makeAVInstruction() -> AVVideoCompositionInstruction {
        let instruction = TransitionVideoCompositionInstruction(
            transitionID: transitionID,
            transitionType: transitionType.rawValue,
            transitionStart: transitionStart,
            transitionDuration: transitionDuration,
            leadingTrackID: leadingTrackID,
            trailingTrackID: trailingTrackID
        )
        // Note: timeRange and enablePostProcessing are read-only properties
        // They will be set properly when the instruction is added to the composition
        return instruction
    }
}