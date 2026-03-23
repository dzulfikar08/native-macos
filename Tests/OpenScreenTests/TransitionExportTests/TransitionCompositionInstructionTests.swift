import XCTest
import AVFoundation
import CoreMedia
@testable import OpenScreen

final class TransitionCompositionInstructionTests: XCTestCase {

    func testInitialization() {
        let transitionID = UUID()
        let transitionType = TransitionType.crossfade
        let parameters = TransitionParameters.crossfade
        let start = CMTime(seconds: 0, preferredTimescale: 600)
        let duration = CMTime(seconds: 1, preferredTimescale: 600)
        let leadingTrackID = CMPersistentTrackID(1)
        let trailingTrackID = CMPersistentTrackID(2)

        let instruction = TransitionCompositionInstruction(
            transitionID: transitionID,
            transitionType: transitionType,
            transitionParameters: parameters,
            transitionStart: start,
            transitionDuration: duration,
            leadingTrackID: leadingTrackID,
            trailingTrackID: trailingTrackID
        )

        XCTAssertEqual(instruction.transitionID, transitionID)
        XCTAssertEqual(instruction.transitionType, transitionType)
        XCTAssertEqual(instruction.transitionParameters, parameters)
        XCTAssertEqual(instruction.transitionStart, start)
        XCTAssertEqual(instruction.transitionDuration, duration)
        XCTAssertEqual(instruction.leadingTrackID, leadingTrackID)
        XCTAssertEqual(instruction.trailingTrackID, trailingTrackID)
    }

    func testTimeRangeCalculation() {
        let start = CMTime(seconds: 5, preferredTimescale: 600)
        let duration = CMTime(seconds: 2, preferredTimescale: 600)

        let instruction = TransitionCompositionInstruction(
            transitionID: UUID(),
            transitionType: .crossfade,
            transitionParameters: .crossfade,
            transitionStart: start,
            transitionDuration: duration,
            leadingTrackID: CMPersistentTrackID(1),
            trailingTrackID: CMPersistentTrackID(2)
        )

        XCTAssertEqual(instruction.timeRange.start.seconds, 5.0)
        XCTAssertEqual(instruction.timeRange.duration.seconds, 2.0)
        XCTAssertEqual(instruction.timeRange.end.seconds, 7.0)
    }

    func testMakeAVInstruction() {
        let transitionID = UUID()
        let start = CMTime(seconds: 0, preferredTimescale: 600)
        let duration = CMTime(seconds: 1, preferredTimescale: 600)

        let instructionWrapper = TransitionCompositionInstruction(
            transitionID: transitionID,
            transitionType: .crossfade,
            transitionParameters: .crossfade,
            transitionStart: start,
            transitionDuration: duration,
            leadingTrackID: CMPersistentTrackID(1),
            trailingTrackID: CMPersistentTrackID(2)
        )

        let avInstruction = instructionWrapper.makeAVInstruction()

        XCTAssertTrue(avInstruction is TransitionVideoCompositionInstruction)
        XCTAssertTrue(avInstruction.enablePostProcessing)

        // Cast to our custom instruction to verify metadata
        if let customInstruction = avInstruction as? TransitionVideoCompositionInstruction {
            XCTAssertEqual(customInstruction.transitionID, transitionID)
            XCTAssertEqual(customInstruction.transitionType, "crossfade")
            XCTAssertEqual(customInstruction.transitionStart.seconds, 0.0)
            XCTAssertEqual(customInstruction.transitionDuration.seconds, 1.0)
            XCTAssertEqual(customInstruction.leadingTrackID, 1)
            XCTAssertEqual(customInstruction.trailingTrackID, 2)
        } else {
            XCTFail("Expected TransitionVideoCompositionInstruction")
        }
    }

    func testMakeAVInstructionForWipeTransition() {
        let transitionID = UUID()
        let parameters = TransitionParameters.wipe(
            direction: .left,
            softness: 50.0,
            border: 2.0
        )

        let instructionWrapper = TransitionCompositionInstruction(
            transitionID: transitionID,
            transitionType: .wipe,
            transitionParameters: parameters,
            transitionStart: .zero,
            transitionDuration: CMTime(seconds: 1, preferredTimescale: 600),
            leadingTrackID: CMPersistentTrackID(1),
            trailingTrackID: CMPersistentTrackID(2)
        )

        let avInstruction = instructionWrapper.makeAVInstruction()

        // Cast to our custom instruction to verify metadata
        if let customInstruction = avInstruction as? TransitionVideoCompositionInstruction {
            XCTAssertEqual(customInstruction.transitionType, "wipe")
            XCTAssertEqual(customInstruction.transitionDuration.seconds, 1.0)
        } else {
            XCTFail("Expected TransitionVideoCompositionInstruction")
        }
    }
}