import XCTest
@testable import OpenScreen

@MainActor
final class EditorStateTests: XCTestCase {
    func testInitialState() {
        let state = EditorState(assetURL: TestDataFactory.makeTestRecordingURL())
        XCTAssertEqual(state.currentTime, .zero)
        XCTAssertFalse(state.isPlaying)
        XCTAssertEqual(state.playbackRate, 1.0)
        XCTAssertEqual(state.volume, 1.0)
    }

    func testLoadAssetThrowsOnInvalidURL() async {
        let state = EditorState(assetURL: TestDataFactory.makeTestRecordingURL())

        // loadAsset(from:) should throw an error for non-existent files
        do {
            try await state.loadAsset(from: TestDataFactory.makeTestRecordingURL())
            XCTFail("Expected loadAsset(from:) to throw an error for invalid URL")
        } catch {
            // Expected behavior - loadAsset(from:) properly throws on invalid files
            XCTAssertNotNil(state.asset, "AVAsset should still be created even if loading fails")
        }
    }
}
