import XCTest
import CoreImage
@testable import OpenScreen

final class TransitionPreviewViewTests: XCTestCase {
    func testPreviewRendersCrossfade() {
        let transition = TestDataFactory.makeTestTransition(
            leadingClipID: UUID(),
            trailingClipID: UUID()
        )

        let renderer = TransitionPreviewRenderer()
        let previewView = TransitionPreviewView(
            transition: transition,
            renderer: renderer
        )

        // Should render without crashing
        XCTAssertNotNil(previewView.imageView?.image)
    }

    func testPreviewAnimationAdvances() {
        let transition = TestDataFactory.makeTestTransition(
            leadingClipID: UUID(),
            trailingClipID: UUID()
        )

        let renderer = TransitionPreviewRenderer()
        let previewView = TransitionPreviewView(
            transition: transition,
            renderer: renderer
        )

        let initialProgress = previewView.currentProgress

        // Wait for one animation frame (33ms at 30fps)
        Thread.sleep(forTimeInterval: 0.034)

        XCTAssertNotEqual(initialProgress, previewView.currentProgress)
    }

    func testPlayPauseToggle() {
        let transition = TestDataFactory.makeTestTransition(
            leadingClipID: UUID(),
            trailingClipID: UUID()
        )

        let renderer = TransitionPreviewRenderer()
        let previewView = TransitionPreviewView(
            transition: transition,
            renderer: renderer
        )

        previewView.playPauseButton?.performClick(nil)

        XCTAssertFalse(previewView.isPlaying)

        previewView.playPauseButton?.performClick(nil)

        XCTAssertTrue(previewView.isPlaying)
    }
}
