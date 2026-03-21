import XCTest
import SwiftUI
import CoreMedia
@testable import OpenScreen

@MainActor
final class TransitionViewTests: XCTestCase {
    func testTransitionViewRendering() {
        let transition = TransitionClip(
            type: .crossfade,
            duration: CMTime(seconds: 1.0, preferredTimescale: 600),
            leadingClipID: UUID(),
            trailingClipID: UUID()
        )

        let handleFrame = CGRect(x: 0, y: 0, width: 10, height: 30)

        let view = TransitionView(
            transition: transition,
            isSelected: false,
            showHandles: false,
            leadingHandleFrame: handleFrame,
            trailingHandleFrame: handleFrame,
            onTap: {},
            onLeadingHandleDrag: { _ in },
            onTrailingHandleDrag: { _ in }
        )

        // Basic smoke test
        _ = view.body
    }

    func testTransitionViewWithSelection() {
        let transition = TransitionClip(
            type: .iris,
            duration: CMTime(seconds: 1.5, preferredTimescale: 600),
            leadingClipID: UUID(),
            trailingClipID: UUID()
        )

        let handleFrame = CGRect(x: 0, y: 0, width: 10, height: 30)

        let view = TransitionView(
            transition: transition,
            isSelected: true,
            showHandles: true,
            leadingHandleFrame: handleFrame,
            trailingHandleFrame: handleFrame,
            onTap: {},
            onLeadingHandleDrag: { _ in },
            onTrailingHandleDrag: { _ in }
        )

        _ = view.body
    }

    func testTransitionViewColors() {
        let types: [TransitionType] = [.crossfade, .fadeToColor, .wipe, .iris, .blinds]

        for type in types {
            let transition = TransitionClip(
                type: type,
                duration: CMTime(seconds: 1.0, preferredTimescale: 600),
                leadingClipID: UUID(),
                trailingClipID: UUID()
            )

            let handleFrame = CGRect(x: 0, y: 0, width: 10, height: 30)

            let view = TransitionView(
                transition: transition,
                isSelected: false,
                showHandles: false,
                leadingHandleFrame: handleFrame,
                trailingHandleFrame: handleFrame,
                onTap: {},
                onLeadingHandleDrag: { _ in },
                onTrailingHandleDrag: { _ in }
            )

            // Should render without crashing for each type
            _ = view.body
        }
    }
}
