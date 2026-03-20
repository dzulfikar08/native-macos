import XCTest
import AppKit
@testable import OpenScreen

@MainActor
final class ExportProgressDialogTests: XCTestCase {

    // MARK: - Properties

    private var exportDialog: ExportProgressDialog!

    // MARK: - Setup and Teardown

    override func setUp() {
        super.setUp()
        exportDialog = ExportProgressDialog()
    }

    override func tearDown() {
        exportDialog = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialization() {
        XCTAssertNotNil(exportDialog.window)
        XCTAssertEqual(exportDialog.window?.title, "Exporting Video")
        XCTAssertFalse(exportDialog.isExporting)
    }

    func testWindowConfiguration() {
        let window = exportDialog.window

        // Check window style
        XCTAssertTrue(window?.styleMask.contains(.titled) ?? false)
        XCTAssertTrue(window?.styleMask.contains(.closable) ?? false)

        // Check window level
        XCTAssertEqual(window?.level, .floating)

        // Check that window is initially hidden
        XCTAssertFalse(window?.isVisible ?? true)
    }

    func testInitialState() {
        // Check that progress elements are initially hidden
        XCTAssertFalse(exportDialog.isExporting)

        // Verify labels are set to initial state
        XCTAssertEqual(exportDialog.currentFrameLabel.stringValue, "Frame: 0 / 0")
        XCTAssertEqual(exportDialog.timeRemainingLabel.stringValue, "Time remaining: --:--")
    }

    // MARK: - Export Progress Tests

    func testStartExport() {
        let totalFrames = 100
        var cancelCalled = false

        // Start export
        exportDialog.startExport(totalFrames: totalFrames) {
            cancelCalled = true
        }

        // Verify state after starting export
        XCTAssertTrue(exportDialog.isExporting)
        XCTAssertFalse(exportDialog.progressIndicator.isHidden)
        XCTAssertFalse(exportDialog.timeRemainingLabel.isHidden)
        XCTAssertFalse(exportDialog.currentFrameLabel.isHidden)
        XCTAssertTrue(exportDialog.cancelButton.isEnabled)

        // Verify initial label values
        XCTAssertEqual(exportDialog.currentFrameLabel.stringValue, "Frame: 0 / \(totalFrames)")
        XCTAssertEqual(exportDialog.timeRemainingLabel.stringValue, "Time remaining: --:--")

        // Verify window is visible
        XCTAssertTrue(exportDialog.window?.isVisible ?? false)
    }

    func testUpdateProgress() {
        let totalFrames = 150
        let currentFrame = 75
        let timeRemaining: TimeInterval = 30.0

        // Start export first
        exportDialog.startExport(totalFrames: totalFrames) {}

        // Update progress
        exportDialog.updateProgress(
            currentFrame: currentFrame,
            totalFrames: totalFrames,
            timeRemaining: timeRemaining
        )

        // Verify progress indicator
        let expectedProgress = Double(currentFrame) / Double(totalFrames)
        XCTAssertEqual(exportDialog.progressIndicator.doubleValue, expectedProgress, accuracy: 0.001)

        // Verify labels
        XCTAssertEqual(exportDialog.currentFrameLabel.stringValue, "Frame: \(currentFrame) / \(totalFrames)")
        XCTAssertEqual(exportDialog.timeRemainingLabel.stringValue, "Time remaining: 00:30")
    }

    func testUpdateProgressWithHours() {
        let totalFrames = 300
        let currentFrame = 150
        let timeRemaining: TimeInterval = 3661.0 // 1 hour, 1 minute, 1 second

        // Start export first
        exportDialog.startExport(totalFrames: totalFrames) {}

        // Update progress with long duration
        exportDialog.updateProgress(
            currentFrame: currentFrame,
            totalFrames: totalFrames,
            timeRemaining: timeRemaining
        )

        // Verify time label includes hours
        XCTAssertEqual(exportDialog.timeRemainingLabel.stringValue, "Time remaining: 01:01:01")
    }

    func testCompleteExport() {
        // Start export first
        exportDialog.startExport(totalFrames: 100) {}

        // Complete export
        exportDialog.completeExport()

        // Verify state after completion
        XCTAssertFalse(exportDialog.isExporting)
        XCTAssertFalse(exportDialog.cancelButton.isEnabled)

        // Verify progress is complete
        XCTAssertEqual(exportDialog.progressIndicator.doubleValue, 1.0)
        XCTAssertEqual(exportDialog.timeRemainingLabel.stringValue, "Export completed!")

        // Wait for async window close
        let expectation = XCTestExpectation(description: "Window should close after completion")

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.1) {
            XCTAssertFalse(self.exportDialog.window?.isVisible ?? true)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 3.0)
    }

    func testCancelExport() {
        var cancelCalled = false

        // Start export
        exportDialog.startExport(totalFrames: 100) {
            cancelCalled = true
        }

        // Cancel export
        exportDialog.cancelExport()

        // Verify state after cancellation
        XCTAssertFalse(exportDialog.isExporting)
        XCTAssertFalse(exportDialog.cancelButton.isEnabled)

        // Verify labels
        XCTAssertEqual(exportDialog.timeRemainingLabel.stringValue, "Export cancelled")
        XCTAssertEqual(exportDialog.currentFrameLabel.stringValue, "Frame: 0 / 0")

        // Wait for async window close
        let expectation = XCTestExpectation(description: "Window should close after cancellation")

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            XCTAssertFalse(self.exportDialog.window?.isVisible ?? true)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testCancelExportHandler() {
        var cancelCalled = false

        // Start export
        exportDialog.startExport(totalFrames: 100) {
            cancelCalled = true
        }

        // Cancel export via button (simulating button click)
        exportDialog.cancelExport()

        // Verify cancel handler was called
        XCTAssertTrue(cancelCalled)
    }

    // MARK: - Edge Case Tests

    func testUpdateProgressWhenNotExporting() {
        // Don't start export
        exportDialog.updateProgress(
            currentFrame: 50,
            totalFrames: 100,
            timeRemaining: 30.0
        )

        // Verify values remain unchanged
        XCTAssertEqual(exportDialog.progressIndicator.doubleValue, 0.0)
        XCTAssertEqual(exportDialog.currentFrameLabel.stringValue, "Frame: 0 / 0")
        XCTAssertEqual(exportDialog.timeRemainingLabel.stringValue, "Time remaining: --:--")
    }

    func testProgressBounds() {
        // Test minimum value
        exportDialog.progressIndicator.doubleValue = -1.0
        XCTAssertEqual(exportDialog.progressIndicator.doubleValue, 0.0)

        // Test maximum value
        exportDialog.progressIndicator.doubleValue = 2.0
        XCTAssertEqual(exportDialog.progressIndicator.doubleValue, 1.0)

        // Test normal value
        exportDialog.progressIndicator.doubleValue = 0.5
        XCTAssertEqual(exportDialog.progressIndicator.doubleValue, 0.5)
    }

    func testZeroFramesExport() {
        // Start export with zero frames
        exportDialog.startExport(totalFrames: 0) {}

        // Verify state
        XCTAssertTrue(exportDialog.isExporting)
        XCTAssertEqual(exportDialog.currentFrameLabel.stringValue, "Frame: 0 / 0")
    }

    // MARK: - UI Layout Tests

    func testProgressIndicatorStyle() {
        XCTAssertEqual(exportDialog.progressIndicator.style, .bar)
        XCTAssertEqual(exportDialog.progressIndicator.minValue, 0.0)
        XCTAssertEqual(exportDialog.progressIndicator.maxValue, 1.0)
    }

    func testCancelButtonConfiguration() {
        XCTAssertEqual(exportDialog.cancelButton.title, "Cancel")
        XCTAssertEqual(exportDialog.cancelButton.bezelStyle, .rounded)
    }

    func testLabelAlignment() {
        XCTAssertEqual(exportDialog.timeRemainingLabel.alignment, .center)
        XCTAssertEqual(exportDialog.currentFrameLabel.alignment, .center)
        XCTAssertFalse(exportDialog.timeRemainingLabel.isEditable)
        XCTAssertFalse(exportDialog.currentFrameLabel.isEditable)
    }
}