import XCTest
@testable import OpenScreen
import CoreMedia

@MainActor
final class EditorStateMultiClipTests: XCTestCase {
    func testMultiClipPropertiesExist() {
        let state = EditorState.createTestState()

        XCTAssertNotNil(state.timelineEditMode)
        XCTAssertNotNil(state.clipTracks)
        XCTAssertNotNil(state.clipOperations)
        XCTAssertNotNil(state.redoStack)
    }

    func testDefaultTimelineModeIsSingleAsset() {
        let state = EditorState.createTestState()
        XCTAssertEqual(state.timelineEditMode, .singleAsset)
    }

    func testClipTracksStartEmpty() {
        let state = EditorState.createTestState()
        XCTAssertTrue(state.clipTracks.isEmpty)
    }

    func testClipOperationsStartEmpty() {
        let state = EditorState.createTestState()
        XCTAssertTrue(state.clipOperations.isEmpty)
        XCTAssertTrue(state.redoStack.isEmpty)
    }

    func testAssetIsPublicForDualModeAccess() {
        let state = EditorState.createTestState()
        // Asset should be accessible (was private(set), now should be public)
        XCTAssertNotNil(state.asset)
    }

    func testTimelineEditModeIsPublished() {
        let state = EditorState.createTestState()

        let expectation = XCTestExpectation(description: "timelineEditMode change notification")
        let center = NotificationCenter.default
        let observer = center.addObserver(
            forName: .timelineEditModeDidChange,
            object: state,
            queue: .main
        ) { _ in
            expectation.fulfill()
        }

        state.timelineEditMode = .multiClip

        wait(for: [expectation], timeout: 1.0)
        center.removeObserver(observer)
    }
}