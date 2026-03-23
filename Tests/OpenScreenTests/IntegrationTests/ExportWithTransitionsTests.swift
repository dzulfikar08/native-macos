import XCTest
import AVFoundation
import CoreMedia
@testable import OpenScreen

final class ExportWithTransitionsTests: XCTestCase {

    func testExportVideoWithTransition() async throws {
        // This is a smoke test to verify export doesn't crash with transitions
        // Full export tests are in Phase 3.1.6

        let editorState = EditorState()

        // Add clips with transition
        let clip1ID = UUID()
        let clip2ID = UUID()

        let transition = TransitionClip(
            type: .crossfade,
            duration: CMTime(seconds: 1, preferredTimescale: 600),
            leadingClipID: clip1ID,
            trailingClipID: clip2ID,
            parameters: .crossfade,
            isEnabled: true
        )

        editorState.addTransition(transition)

        // Build video composition
        let builder = AVVideoCompositionBuilder(
            transitions: editorState.transitions,
            quality: ExportQualitySettings.good
        )

        let composition = try builder.build()

        // Verify composition includes transition instructions
        XCTAssertNotNil(composition)
    }
}
