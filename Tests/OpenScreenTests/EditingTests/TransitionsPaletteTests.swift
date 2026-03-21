import XCTest
@testable import OpenScreen

final class TransitionsPaletteTests: XCTestCase {
    func testPaletteInitialization() {
        let editorState = EditorState()
        let palette = TransitionsPaletteViewController(editorState: editorState)
        XCTAssertNotNil(palette)
    }

    func testOutlineViewDataSource() {
        let editorState = EditorState()
        let palette = TransitionsPaletteViewController(editorState: editorState)
        palette.viewDidLoad()
        XCTAssertNotNil(palette.outlineView)
    }

    func testDragPasteboardType() {
        XCTAssertEqual(
            TransitionsPaletteViewController.DragPasteboardType.transitionType.rawValue,
            "com.openscreen.transitionType"
        )
    }
}
