# Source Selector Phase 1: Multi-Monitor Support

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement source selector window that allows users to select which display to record from, supporting multi-monitor setups.

**Architecture:** AppKit-based modal sheet with NSTabView. Phase 1 implements screen selection only; other tabs are placeholders. Updates RecordingController to accept optional displayID parameter for recording from specific displays.

**Tech Stack:** AppKit (NSWindowController, NSTabViewController, NSCollectionView), CoreGraphics (CGDisplay APIs), AVFoundation

---

## Chunk 1: Data Models and State Updates

### Task 1: Create SourceSelection Enum

**Files:**
- Create: `Sources/native-macos/SourceSelector/Models/SourceSelection.swift`
- Create: `Tests/OpenScreenTests/SourceSelectorTests/` (directory)
- Test: `Tests/OpenScreenTests/SourceSelectorTests/SourceSelectionTests.swift`

- [ ] **Step 0: Create test directory**

```bash
mkdir -p Tests/OpenScreenTests/SourceSelectorTests
```

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import OpenScreen

func testSourceSelectionScreen() {
    let selection = SourceSelection.screen(displayID: 123, displayName: "Main Display")
    switch selection {
    case .screen(let displayID, let displayName):
        XCTAssertEqual(displayID, 123)
        XCTAssertEqual(displayName, "Main Display")
    default:
        XCTFail("Should be screen case")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter SourceSelectionTests::testSourceSelectionScreen`
Expected: FAIL with "SourceSelection not found"

- [ ] **Step 3: Write minimal implementation**

```swift
import Foundation

/// Represents a selected source for recording or editing
enum SourceSelection: Equatable, Sendable {
    case screen(displayID: CGDirectDisplayID, displayName: String)
    // Future phases:
    // case window(windowID: CGWindowID, windowName: String, ownerName: String)
    // case webcam(deviceID: String, deviceName: String)
    // case videoFile(url: URL)
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter SourceSelectionTests::testSourceSelectionScreen`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/native-macos/SourceSelector/Models/SourceSelection.swift \
        Tests/OpenScreenTests/SourceSelectorTests/SourceSelectionTests.swift
git commit -m "feat(source-selector): add SourceSelection enum

- Add SourceSelection enum with screen case for Phase 1
- Include displayID and displayName for screen selection
- Add SourceSelectionTests with basic test

Part of Phase 1: Multi-Monitor Support"
```

### Task 2: Create DisplayItem Model

**Files:**
- Create: `Sources/native-macos/SourceSelector/Models/DisplayItem.swift`
- Test: `Tests/OpenScreenTests/SourceSelectorTests/DisplayItemTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import OpenScreen

func testDisplayItemCreation() {
    let item = DisplayItem(
        id: 123,
        name: "Main Display",
        width: 1920,
        height: 1080,
        thumbnail: nil
    )

    XCTAssertEqual(item.id, 123)
    XCTAssertEqual(item.name, "Main Display")
    XCTAssertEqual(item.width, 1920)
    XCTAssertEqual(item.height, 1080)
    XCTAssertNil(item.thumbnail)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter DisplayItemTests::testDisplayItemCreation`
Expected: FAIL with "DisplayItem not found"

- [ ] **Step 3: Write minimal implementation**

```swift
import AppKit

/// Represents a display device with metadata and optional thumbnail
struct DisplayItem: Identifiable, Equatable, Sendable {
    let id: CGDirectDisplayID
    let name: String
    let width: Int
    let height: Int
    var thumbnail: NSImage?

    var resolution: String {
        "\(width) × \(height)"
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter DisplayItemTests::testDisplayItemCreation`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/native-macos/SourceSelector/Models/DisplayItem.swift \
        Tests/OpenScreenTests/SourceSelectorTests/DisplayItemTests.swift
git commit -m "feat(source-selector): add DisplayItem model

- Add DisplayItem struct for display information
- Include id, name, dimensions, and thumbnail
- Add resolution computed property
- Add DisplayItemTests

Part of Phase 1: Multi-Monitor Support"
```

### Task 3: Update WindowState for Editing Transition

**Files:**
- Modify: `Sources/native-macos/Shared/Models/WindowState.swift`
- Test: `Tests/OpenScreenTests/ModelTests/WindowStateTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import OpenScreen

func testSourceSelectorToEditingTransition() {
    let fromState: WindowState = .sourceSelector
    let validTransitions = fromState.canTransitionTo

    XCTAssertTrue(validTransitions.contains(.editing),
                  "sourceSelector should be able to transition to editing")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter WindowStateTests::testSourceSelectorToEditingTransition`
Expected: FAIL - ".editing not in transitions"

- [ ] **Step 3: Update WindowState**

```swift
case .sourceSelector:
    return [.idle, .recording, .editing]
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter WindowStateTests::testSourceSelectorToEditingTransition`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/native-macos/Shared/Models/WindowState.swift
git commit -m "feat(source-selector): add sourceSelector to editing transition

- Update WindowState to allow .sourceSelector → .editing
- Required for video import feature (Phase 2)

Part of Phase 1: Multi-Monitor Support"
```

---

## Chunk 2: Recording Infrastructure Updates

### Task 4: Update ScreenRecorder to Accept Display ID

**Files:**
- Modify: `Sources/native-macos/Recording/ScreenRecorder.swift`
- Test: `Tests/OpenScreenTests/RecordingTests/ScreenRecorderTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
func testStartRecordingWithSpecificDisplay() async throws {
    let recorder = ScreenRecorder()
    let url = try FileUtils.uniqueRecordingURL()
    let displayID = CGMainDisplayID()

    try await recorder.startRecording(to: url, displayID: displayID)

    // Verify recording started with specified display
    XCTAssertNotNil(recorder.currentSession)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter ScreenRecorderTests::testStartRecordingWithSpecificDisplay`
Expected: FAIL - "startRecording(to:displayID:) method not found"

- [ ] **Step 3: Update ScreenRecorder.startRecording() signature**

```swift
/// Starts recording to the specified URL
/// - Parameters:
///   - url: Destination URL for the recorded video
///   - displayID: Display ID to record, or nil for main display
/// - Throws: RecordingError if recording cannot start
func startRecording(to url: URL, displayID: CGDirectDisplayID? = nil) async throws {
    guard !isRecording else { return }

    // Check screen recording permission
    await checkScreenRecordingPermission()

    // Create session
    let session = AVCaptureSession()
    session.sessionPreset = .high

    // Determine which display to use
    let targetDisplayID: CGDirectDisplayID
    if let displayID = displayID {
        targetDisplayID = displayID
    } else {
        // Get main display if none specified
        guard let display = NSScreen.main else {
            throw RecordingError.noDisplayAvailable
        }
        guard let mainDisplayID = display.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
            throw RecordingError.noDisplayAvailable
        }
        targetDisplayID = mainDisplayID
    }

    // Create screen input
    guard let input = AVCaptureScreenInput(displayID: targetDisplayID) else {
        throw RecordingError.recordingInterrupted
    }

    input.capturesCursor = true
    input.capturesMouseClicks = true

    if session.canAddInput(input) {
        session.addInput(input)
    }

    // Create movie output
    let movieOutput = AVCaptureMovieFileOutput()
    if session.canAddOutput(movieOutput) {
        session.addOutput(movieOutput)
    }

    self.session = session
    self.screenInput = input
    self.movieOutput = movieOutput
    self.recordingURL = url

    // Start session
    session.startRunning()

    // Start recording
    movieOutput.startRecording(to: url, recordingDelegate: self)
    isRecording = true

    print("📹 Recording started to: \(url.path) (display: \(targetDisplayID))")
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter ScreenRecorderTests::testStartRecordingWithSpecificDisplay`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/native-macos/Recording/ScreenRecorder.swift \
        Tests/OpenScreenTests/RecordingTests/ScreenRecorderTests.swift
git commit -m "feat(source-selector): add display ID parameter to ScreenRecorder

- Update startRecording(to:displayID:) to accept optional displayID
- Use main display if no displayID specified (backward compatible)
- Add test for specific display recording

Part of Phase 1: Multi-Monitor Support"
```

### Task 5: Update RecordingController to Pass Display ID

**Files:**
- Modify: `Sources/native-macos/Recording/RecordingController.swift`
- Test: `Tests/OpenScreenTests/RecordingTests/RecordingControllerTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
func testStartRecordingWithDisplay() async throws {
    let controller = RecordingController()
    let displayID = CGMainDisplayID()

    _ = try await controller.startRecording(displayID: displayID)

    // Verify recording started
    XCTAssertNotNil(controller.currentRecordingURL)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter RecordingControllerTests::testStartRecordingWithDisplay`
Expected: FAIL - "startRecording(displayID:) method not found"

- [ ] **Step 3: Update RecordingController.startRecording()**

```swift
/// Starts a new recording session
/// - Parameter displayID: Display ID to record, or nil for main display
/// - Returns: URL where recording will be saved
/// - Throws: RecordingError if recording cannot start
func startRecording(displayID: CGDirectDisplayID? = nil) async throws -> URL {
    // Generate unique recording URL in ~/Movies/OpenScreenNative
    let url = try FileUtils.uniqueRecordingURL()
    currentRecordingURL = url

    // Start screen recording with specified display
    try await screenRecorder.startRecording(to: url, displayID: displayID)

    return url
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter RecordingControllerTests::testStartRecordingWithDisplay`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/native-macos/Recording/RecordingController.swift \
        Tests/OpenScreenTests/RecordingTests/RecordingControllerTests.swift
git commit -m "feat(source-selector): add display ID parameter to RecordingController

- Update startRecording(displayID:) to accept optional displayID
- Pass displayID through to ScreenRecorder
- Add RecordingControllerTests

Part of Phase 1: Multi-Monitor Support"
```

---

## Chunk 3: Source Selector UI Components

### Task 6: Create ScreenSourceViewController

**Files:**
- Create: `Sources/native-macos/SourceSelector/ScreenSourceViewController.swift`
- Test: `Tests/OpenScreenTests/SourceSelectorTests/ScreenSourceViewControllerTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
func testEnumerateDisplays() {
    let controller = ScreenSourceViewController()
    let displays = controller.enumerateDisplays()

    XCTAssertTrue(displays.count > 0, "Should detect at least one display")
    XCTAssertTrue(displays.contains { $0.name.contains("Display") })
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter ScreenSourceViewControllerTests::testEnumerateDisplays`
Expected: FAIL with "ScreenSourceViewController not found"

- [ ] **Step 3: Create ScreenSourceViewController with display enumeration**

```swift
import AppKit
import CoreGraphics

/// View controller for screen source selection
@MainActor
final class ScreenSourceViewController: NSViewController {
    private var displays: [DisplayItem] = []
    private var selectedItem: DisplayItem?
    var onSelectionChanged: ((DisplayItem?) -> Void)?

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        enumerateDisplays()
    }

    /// Enumerates available displays
    /// - Returns: Array of DisplayItem objects
    func enumerateDisplays() -> [DisplayItem] {
        var result: [DisplayItem] = []

        // Get number of displays
        let maxDisplays = 32
        var displayIDs = [CGDirectDisplayID](repeating: 0, count: maxDisplays)
        let count = CGGetOnlineDisplayList(maxDisplays, &displayIDs, nil)

        guard count > 0 else {
            print("⚠️ No displays detected")
            return result
        }

        for i in 0..<Int(count) {
            let displayID = displayIDs[i]

            // Get display info
            let name = getDisplayName(for: displayID)
            let width = CGDisplayPixelsWide(displayID)
            let height = CGDisplayPixelsHigh(displayID)

            let item = DisplayItem(
                id: displayID,
                name: name,
                width: width,
                height: height,
                thumbnail: generateThumbnail(for: displayID)
            )
            result.append(item)
        }

        displays = result
        return result
    }

    /// Gets display name
    private func getDisplayName(for displayID: CGDirectDisplayID) -> String {
        // Find matching NSScreen
        if let screen = NSScreen.screens.first(where: { screen in
            guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
                return false
            }
            return id == displayID
        }) {
            return screen.localizedName ?? "Display \(displayID)"
        }

        return "Display \(displayID)"
    }

    /// Generates thumbnail for display
    private func generateThumbnail(for displayID: CGDirectDisplayID) -> NSImage? {
        let width = 320
        let height = 200

        guard let image = CGDisplayCreateImage(displayID) else {
            return nil
        }

        let size = NSSize(width: width, height: height)
        return NSImage(cgImage: image, size: size)
    }

    /// Selects a display
    /// - Parameter item: DisplayItem to select
    func selectDisplay(_ item: DisplayItem) {
        selectedItem = item
        onSelectionChanged?(item)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter ScreenSourceViewControllerTests::testEnumerateDisplays`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/native-macos/SourceSelector/ScreenSourceViewController.swift \
        Tests/OpenScreenTests/SourceSelectorTests/ScreenSourceViewControllerTests.swift
git commit -m "feat(source-selector): add ScreenSourceViewController

- Implement display enumeration using CGDisplay APIs
- Generate thumbnails for each display
- Add selection handling
- Add ScreenSourceViewControllerTests

Part of Phase 1: Multi-Monitor Support"
```

### Task 7: Create Placeholder View Controllers

**Files:**
- Create: `Sources/native-macos/SourceSelector/WindowSourceViewController.swift`
- Create: `Sources/native-macos/SourceSelector/WebcamSourceViewController.swift`
- Create: `Sources/native-macos/SourceSelector/VideoImportViewController.swift`

- [ ] **Step 1: Create WindowSourceViewController placeholder**

```swift
import AppKit

/// Placeholder for window source selection (Phase 4)
@MainActor
final class WindowSourceViewController: NSViewController {
    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        // Create placeholder label
        let label = NSTextField(labelWithString: "Window Recording\n\nComing in Phase 4")
        label.alignment = .center
        label.isEditable = false
        label.isBordered = false
        label.backgroundColor = .clear
        label.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
}
```

- [ ] **Step 2: Create WebcamSourceViewController placeholder**

```swift
import AppKit

/// Placeholder for webcam source selection (Phase 3)
@MainActor
final class WebcamSourceViewController: NSViewController {
    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        let label = NSTextField(labelWithString: "Webcam Recording\n\nComing in Phase 3")
        label.alignment = .center
        label.isEditable = false
        label.isBordered = false
        label.backgroundColor = .clear
        label.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
}
```

- [ ] **Step 3: Create VideoImportViewController placeholder**

```swift
import AppKit

/// Placeholder for video file import (Phase 2)
@MainActor
final class VideoImportViewController: NSViewController {
    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        let label = NSTextField(labelWithString: "Import Video File\n\nComing in Phase 2")
        label.alignment = .center
        label.isEditable = false
        label.isBordered = false
        label.backgroundColor = .clear
        label.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
}
```

- [ ] **Step 4: Commit placeholder controllers**

```bash
git add Sources/native-macos/SourceSelector/WindowSourceViewController.swift \
        Sources/native-macos/SourceSelector/WebcamSourceViewController.swift \
        Sources/native-macos/SourceSelector/VideoImportViewController.swift
git commit -m "feat(source-selector): add placeholder view controllers

- Add WindowSourceViewController (Phase 4)
- Add WebcamSourceViewController (Phase 3)
- Add VideoImportViewController (Phase 2)
- Each shows Coming Soon message

Part of Phase 1: Multi-Monitor Support"
```

---

## Chunk 4: Window Controller Integration

### Task 8: Create SourceSelectorWindowController

**Files:**
- Create: `Sources/native-macos/SourceSelector/SourceSelectorWindowController.swift`
- Test: `Tests/OpenScreenTests/SourceSelectorTests/SourceSelectorWindowControllerTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
func testWindowControllerInitialization() {
    let controller = SourceSelectorWindowController()

    XCTAssertNotNil(controller.window)
    XCTAssertEqual(controller.window?.title, "Select Video Source")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter SourceSelectorWindowControllerTests::testWindowControllerInitialization`
Expected: FAIL with "SourceSelectorWindowController not found"

- [ ] **Step 3: Create SourceSelectorWindowController**

```swift
import AppKit

/// Window controller for source selection modal sheet
@MainActor
final class SourceSelectorWindowController: NSWindowController {
    private var onSourceSelected: ((SourceSelection) -> Void)?
    private var onCancelled: (() -> Void)?
    private var tabViewController: NSTabViewController?

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Select Video Source"
        window.isReleasedWhenClosed = false

        self.init(window: window)

        setupTabView()
    }

    /// Sets up the tab view
    private func setupTabView() {
        let tabVC = NSTabViewController()

        // Screen tab
        let screenVC = ScreenSourceViewController()
        let screenTab = NSTabViewItem(identifier: NSUserInterfaceItemIdentifier(rawValue: "screen"))
        screenTab.label = "Screen"
        screenTab.viewController = screenVC
        screenTab.image = NSImage(systemSymbolName: "display", accessibilityDescription: "Screen")

        // Window tab (placeholder)
        let windowVC = WindowSourceViewController()
        let windowTab = NSTabViewItem(identifier: NSUserInterfaceItemIdentifier(rawValue: "window"))
        windowTab.label = "Window"
        windowTab.viewController = windowVC
        windowTab.image = NSImage(systemSymbolName: "macwindow", accessibilityDescription: "Window")

        // Webcam tab (placeholder)
        let webcamVC = WebcamSourceViewController()
        let webcamTab = NSTabViewItem(identifier: NSUserInterfaceItemIdentifier(rawValue: "webcam"))
        webcamTab.label = "Webcam"
        webcamTab.viewController = webcamVC
        webcamTab.image = NSImage(systemSymbolName: "video.circle", accessibilityDescription: "Webcam")

        // Import tab (placeholder)
        let importVC = VideoImportViewController()
        let importTab = NSTabViewItem(identifier: NSUserInterfaceItemIdentifier(rawValue: "import"))
        importTab.label = "Import"
        importTab.viewController = importVC
        importTab.image = NSImage(systemSymbolName: "square.and.arrow.down", accessibilityDescription: "Import")

        tabVC.tabViewItems = [screenTab, windowTab, webcamTab, importTab]
        tabVC.selectedTabViewItemIndex = 0

        self.tabViewController = tabVC
        window?.contentViewController = tabVC

        // Handle screen selection
        screenVC.onSelectionChanged = { [weak self] displayItem in
            guard let self = self, let item = displayItem else { return }
            self.onSourceSelected?(.screen(displayID: item.id, displayName: item.name))
        }
    }

    /// Presents the window as a modal sheet
    /// - Parameters:
    ///   - parentWindow: Window to attach sheet to
    ///   - onSelected: Callback when source is selected
    ///   - onCancelled: Callback when cancelled
    func presentAsSheet(
        on parentWindow: NSWindow,
        onSelected: @escaping (SourceSelection) -> Void,
        onCancelled: @escaping @Sendable () -> Void
    ) {
        self.onSourceSelected = onSelected
        self.onCancelled = onCancelled

        parentWindow.beginSheet(window!) { [weak self] response in
            guard let self = self else { return }
            if response == .OK {
                // Selection handled via onSourceSelected callback
            } else {
                self.onCancelled?()
            }
            // Window will be cleaned up by WindowManager
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter SourceSelectorWindowControllerTests::testWindowControllerInitialization`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/native-macos/SourceSelector/SourceSelectorWindowController.swift \
        Tests/OpenScreenTests/SourceSelectorTests/SourceSelectorWindowControllerTests.swift
git commit -m "feat(source-selector): add SourceSelectorWindowController

- Implement modal sheet window controller
- Add NSTabView with 4 tabs (Screen, Window, Webcam, Import)
- Screen tab functional, others are placeholders
- Handle sheet presentation and callbacks
- Add SourceSelectorWindowControllerTests

Part of Phase 1: Multi-Monitor Support"
```

### Task 9: Integrate with WindowManager

**Files:**
- Modify: `Sources/native-macos/App/WindowManager.swift`

- [ ] **Step 1: Update showSourceSelector() implementation**

```swift
/// Shows the source selector window
func showSourceSelector() {
    let sourceSelector = SourceSelectorWindowController()

    // Get parent window (or create a temporary one)
    let parentWindow = NSApp.windows.first { $0.canBecomeMain }

    guard let window = parentWindow else {
        print("⚠️ No parent window available for sheet")
        return
    }

    sourceSelector.presentAsSheet(on: window) { [weak self] selection in
        guard let self = self else { return }

        switch selection {
        case .screen(let displayID, let displayName):
            print("✅ Selected display: \(displayName) (ID: \(displayID))")

            // Store selected display for recording
            // Transition to recording
            self.transition(to: .recording)

            // Show HUD and start recording with selected display
            Task { @MainActor in
                self.showHUD()
                guard let recordingController = self.getRecordingController() else {
                    print("⚠️ RecordingController not available")
                    return
                }

                do {
                    _ = try await recordingController.startRecording(displayID: displayID)
                } catch {
                    self.errorPresenter.presentCritical(error, from: window)
                }
            }

        case .window, .webcam, .videoFile:
            // These will be implemented in future phases
            print("ℹ️ Source type not yet implemented: \(selection)")
        }
    } onCancelled: { [weak self] in
        print("ℹ️ Source selector cancelled")
        self?.transition(to: .idle)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Sources/native-macos/App/WindowManager.swift
git commit -m "feat(source-selector): integrate source selector with WindowManager

- Implement showSourceSelector() method
- Present source selector as modal sheet
- Handle source selection and initiate recording
- Support cancel to return to idle state
- Pass displayID to RecordingController

Part of Phase 1: Multi-Monitor Support"
```

---

## Chunk 5: Testing and Verification

### Task 10: Add Integration Tests

**Files:**
- Create: `Tests/OpenScreenTests/IntegrationTests/` (directory)
- Create: `Tests/OpenScreenTests/IntegrationTests/SourceSelectorIntegrationTests.swift`

- [ ] **Step 0: Create integration test directory**

```bash
mkdir -p Tests/OpenScreenTests/IntegrationTests
```

- [ ] **Step 1: Write integration test for source selector flow**

```swift
import XCTest
@testable import OpenScreen

func testSourceSelectorToRecordingFlow() async throws {
    let editorState = EditorState.createTestState()
    let manager = WindowManager(
        resourceCoordinator: ResourceCoordinator(),
        errorPresenter: ErrorPresenter()
    )

    // Start at source selector
    manager.transition(to: .sourceSelector)

    // Simulate screen selection
    // (This would require mocking the UI interactions)

    // Verify transition to recording
    // Verify recording starts with selected display
}
```

- [ ] **Step 2: Commit**

```bash
git add Tests/OpenScreenTests/IntegrationTests/SourceSelectorIntegrationTests.swift
git commit -m "test(source-selector): add integration tests

- Add SourceSelectorIntegrationTests
- Test source selector to recording flow
- Verify state transitions

Part of Phase 1: Multi-Monitor Support"
```

### Task 11: Run All Tests and Verify

- [ ] **Step 1: Run all source selector tests**

```bash
swift test --filter SourceSelector
```

Expected: All tests pass

- [ ] **Step 2: Run integration tests**

```bash
swift test --filter SourceSelectorIntegration
```

Expected: All tests pass

- [ ] **Step 3: Run full test suite**

```bash
swift test
```

Expected: All tests pass, no regressions

- [ ] **Step 4: Build and run app**

```bash
swift build
swift run
```

Expected: App launches, shows source selector when started

- [ ] **Step 5: Test multi-monitor workflow**

1. Build and run app
2. Source selector modal should appear
3. Screen tab should show all connected displays
4. Select a display
5. Recording should start on selected display
6. Verify recording file is created

Expected: All steps work correctly

- [ ] **Step 6: Final commit**

```bash
git add .
git commit -m "test(source-selector): verify Phase 1 completion

- All source selector tests passing
- Integration tests passing
- Multi-monitor recording verified
- Phase 1: Multi-Monitor Support complete

Part of Phase 1: Multi-Monitor Support"
```

- [ ] **Step 7: Manual verification checklist**

- [ ] Launch app and verify source selector appears as modal sheet
- [ ] Verify all 4 tabs are visible (Screen, Window, Webcam, Import)
- [ ] Select Screen tab and verify displays are listed
- [ ] Select a display and verify recording starts on correct display
- [ ] Verify ESC key closes source selector and returns to idle
- [ ] Test with 2+ monitors if available

---

## Summary

**Files Created:**
1. `Sources/native-macos/SourceSelector/Models/SourceSelection.swift`
2. `Sources/native-macos/SourceSelector/Models/DisplayItem.swift`
3. `Sources/native-macos/SourceSelector/ScreenSourceViewController.swift`
4. `Sources/native-macos/SourceSelector/WindowSourceViewController.swift`
5. `Sources/native-macos/SourceSelector/WebcamSourceViewController.swift`
6. `Sources/native-macos/SourceSelector/VideoImportViewController.swift`
7. `Sources/native-macos/SourceSelector/SourceSelectorWindowController.swift`

**Files Modified:**
1. `Sources/native-macos/Shared/Models/WindowState.swift`
2. `Sources/native-macos/Recording/ScreenRecorder.swift`
3. `Sources/native-macos/Recording/RecordingController.swift`
4. `Sources/native-macos/App/WindowManager.swift`

**Test Files Created:**
1. `Tests/OpenScreenTests/SourceSelectorTests/SourceSelectionTests.swift`
2. `Tests/OpenScreenTests/SourceSelectorTests/DisplayItemTests.swift`
3. `Tests/OpenScreenTests/SourceSelectorTests/ScreenSourceViewControllerTests.swift`
4. `Tests/OpenScreenTests/SourceSelectorTests/SourceSelectorWindowControllerTests.swift`
5. `Tests/OpenScreenTests/IntegrationTests/SourceSelectorIntegrationTests.swift`

**Next Steps:**
- Phase 2: Implement video file import
- Phase 3: Implement webcam recording
- Phase 4: Research window recording feasibility
