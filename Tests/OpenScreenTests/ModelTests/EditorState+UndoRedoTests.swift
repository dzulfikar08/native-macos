import XCTest
@testable import OpenScreen

@MainActor
final class EditorStateUndoRedoTests: XCTestCase {

    // MARK: - Test Undo Manager Integration

    func testUndoManagerIntegration() {
        let state = EditorState.createTestState()

        // Initialize undo manager
        state.initializeUndoManager()

        // Verify undo manager is initialized
        XCTAssertNotNil(state.undoManager, "Undo manager should be initialized")

        // Verify initial state
        XCTAssertFalse(state.canUndo, "Should not be able to undo initially")
        XCTAssertFalse(state.canRedo, "Should not be able to redo initially")
        XCTAssertNil(state.undoDescription, "Undo description should be nil initially")
        XCTAssertNil(state.redoDescription, "Redo description should be nil initially")
    }

    // MARK: - Test Undo Convenience Method

    func testUndoConvenienceMethod() {
        let state = EditorState.createTestState()

        // Initialize undo manager
        state.initializeUndoManager()

        // Attempt to undo when there's nothing to undo
        XCTAssertThrowsError(try state.undo(), "Should throw error when nothing to undo") { error in
            XCTAssertTrue(error is UndoError, "Error should be UndoError")
            if let undoError = error as? UndoError {
                switch undoError {
                case .nothingToUndo:
                    XCTAssertTrue(true, "Correct error type")
                default:
                    XCTFail("Expected .nothingToUndo error")
                }
            }
        }

        // Verify canUndo is still false
        XCTAssertFalse(state.canUndo, "Should still not be able to undo")

        // Attempt to redo when there's nothing to redo
        XCTAssertThrowsError(try state.redo(), "Should throw error when nothing to redo") { error in
            XCTAssertTrue(error is UndoError, "Error should be UndoError")
            if let undoError = error as? UndoError {
                switch undoError {
                case .nothingToRedo:
                    XCTAssertTrue(true, "Correct error type")
                default:
                    XCTFail("Expected .nothingToRedo error")
                }
            }
        }

        // Verify canRedo is still false
        XCTAssertFalse(state.canRedo, "Should still not be able to redo")
    }
}
