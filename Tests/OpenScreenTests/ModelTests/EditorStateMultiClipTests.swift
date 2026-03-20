import XCTest
@testable import OpenScreen
import CoreMedia

@MainActor
final class EditorStateMultiClipTests: XCTestCase {

    func testMissingProperties() {
        let state = EditorState.createTestState()

        // These should fail to compile
        _ = state.timelineEditMode
        _ = state.clipTracks
        _ = state.clipOperations
        _ = state.redoStack
    }
}