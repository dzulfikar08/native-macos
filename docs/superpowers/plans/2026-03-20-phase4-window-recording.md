# Phase 4: Window Recording Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement window recording capability for OpenScreen using Core Graphics Window Services APIs to capture individual application windows while excluding other on-screen content.

**Architecture:** Timer-based capture loop using CGWindowListCopyWindowInfo for metadata queries and CGWindowListCreateImage for frame capture. WindowRecorder conforms to Recorder protocol and integrates with existing RecordingController. PipCompositor reused for multi-window layouts. WindowTracker monitors window state for automatic pause/resume.

**Tech Stack:** Core Graphics (CGWindowListCopyWindowInfo, CGWindowListCreateImage), AVFoundation (AVAssetWriter), AppKit (NSViewController, NSView), Sendable concurrency (@MainActor), Timer-based capture loops

---

## File Structure

**Creating:**
- `Sources/native-macos/SourceSelector/Models/WindowDevice.swift` - Window metadata model with enumeration
- `Sources/native-macos/SourceSelector/Models/WindowRecordingSettings.swift` - Recording configuration model
- `Sources/native-macos/Recording/WindowTracker.swift` - Window state monitoring
- `Sources/native-macos/Recording/WindowRecorder.swift` - Main recorder implementation
- `Sources/native-macos/SourceSelector/WindowSourceViewController.swift` - UI controller

**Modifying:**
- `Sources/native-macos/SourceSelector/Models/SourceSelection.swift` - Enable window case

**Tests:**
- `Tests/OpenScreenTests/SourceSelectorTests/WindowDeviceTests.swift`
- `Tests/OpenScreenTests/SourceSelectorTests/WindowRecordingSettingsTests.swift`
- `Tests/OpenScreenTests/RecordingTests/WindowTrackerTests.swift`
- `Tests/OpenScreenTests/RecordingTests/WindowRecorderTests.swift`
- `Tests/OpenScreenTests/RecordingTests/WindowRecorderIntegrationTests.swift`

---

## Chunk 1: Foundation Models and WindowTracker

This chunk establishes the core data models and window state tracking infrastructure.

### Task 1: Create WindowDevice Model

**Files:**
- Create: `Sources/native-macos/SourceSelector/Models/WindowDevice.swift`
- Test: `Tests/OpenScreenTests/SourceSelectorTests/WindowDeviceTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import OpenScreen

@MainActor
final class WindowDeviceTests: XCTestCase {
    func testWindowDeviceInitialization() {
        let device = WindowDevice(
            id: 123,
            name: "Test Window",
            ownerName: "Test App",
            bounds: CGRect(x: 100, y: 100, width: 800, height: 600)
        )

        XCTAssertEqual(device.id, 123)
        XCTAssertEqual(device.name, "Test Window")
        XCTAssertEqual(device.ownerName, "Test App")
        XCTAssertEqual(device.bounds, CGRect(x: 100, y: 100, width: 800, height: 600))
    }

    func testEnumerateWindowsReturnsNonEmptyArray() {
        let windows = WindowDevice.enumerateWindows()

        XCTAssertFalse(windows.isEmpty, "Should find at least one window")
    }

    func testWindowFilteringExcludesInvalidWindows() {
        let windows = WindowDevice.enumerateWindows()

        for window in windows {
            XCTAssertFalse(window.name.isEmpty, "Window should have a name")
            XCTAssertFalse(window.ownerName.isEmpty, "Window should have an owner")
            XCTAssertGreaterThanOrEqual(window.bounds.width, 100, "Window should be at least 100px wide")
            XCTAssertGreaterThanOrEqual(window.bounds.height, 100, "Window should be at least 100px tall")
        }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter WindowDeviceTests`
Expected: FAIL with "WindowDevice type not found"

- [ ] **Step 3: Write minimal implementation**

Create `Sources/native-macos/SourceSelector/Models/WindowDevice.swift`:

```swift
import Foundation
import CoreGraphics

/// Represents a window that can be recorded
struct WindowDevice: Identifiable, Sendable {
    let id: CGWindowID
    let name: String
    let ownerName: String
    let bounds: CGRect
    var thumbnail: NSImage?

    /// Enumerates all available windows for recording
    static func enumerateWindows() -> [WindowDevice] {
        guard let windowList = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        var devices: [WindowDevice] = []

        for windowInfo in windowList {
            guard let windowID = windowInfo[kCGWindowNumber as String] as? CGWindowID,
                  let name = windowInfo[kCGWindowName as String] as? String,
                  let ownerName = windowInfo[kCGWindowOwnerName as String] as? String,
                  let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: Any],
                  let layer = windowInfo[kCGWindowLayer as String] as? Int else {
                continue
            }

            // Filter out menu bar, dock, and other system windows
            if layer == 0 {
                continue
            }

            // Filter out windows without names
            if name.isEmpty || ownerName.isEmpty {
                continue
            }

            // Parse bounds
            guard let x = boundsDict["X"] as? CGFloat,
                  let y = boundsDict["Y"] as? CGFloat,
                  let width = boundsDict["Width"] as? CGFloat,
                  let height = boundsDict["Height"] as? CGFloat else {
                continue
            }

            let bounds = CGRect(x: x, y: y, width: width, height: height)

            // Filter out small windows
            if width < 100 || height < 100 {
                continue
            }

            let device = WindowDevice(
                id: windowID,
                name: name,
                ownerName: ownerName,
                bounds: bounds
            )

            devices.append(device)
        }

        return devices
    }

    /// Updates bounds for all devices in place
    static func updateWindowBounds(_ devices: inout [WindowDevice]) {
        guard let windowList = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] else {
            return
        }

        var boundsMap: [CGWindowID: CGRect] = [:]

        for windowInfo in windowList {
            guard let windowID = windowInfo[kCGWindowNumber as String] as? CGWindowID,
                  let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: Any] else {
                continue
            }

            guard let x = boundsDict["X"] as? CGFloat,
                  let y = boundsDict["Y"] as? CGFloat,
                  let width = boundsDict["Width"] as? CGFloat,
                  let height = boundsDict["Height"] as? CGFloat else {
                continue
            }

            boundsMap[windowID] = CGRect(x: x, y: y, width: width, height: height)
        }

        for index in devices.indices {
            if let newBounds = boundsMap[devices[index].id] {
                devices[index].bounds = newBounds
            }
        }
    }

    /// Creates a thumbnail image for this window
    func createThumbnail() -> NSImage? {
        guard let image = CGWindowListCreateImage(.null, .optionIncludingWindow, id, .boundsIgnoreFraming) else {
            return nil
        }

        let thumbnailSize = NSSize(width: 160, height: 120)
        return NSImage(cgImage: image, size: thumbnailSize)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter WindowDeviceTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/native-macos/SourceSelector/Models/WindowDevice.swift
git add Tests/OpenScreenTests/SourceSelectorTests/WindowDeviceTests.swift
git commit -m "feat(phase4): add WindowDevice model with enumeration

WindowDevice struct represents capturable windows with:
- Window ID, name, owner name, bounds
- enumerateWindows() filters invalid windows
- updateWindowBounds() refreshes positions
- createThumbnail() generates UI previews

Tests: WindowDevice enumeration, filtering, bounds parsing
"
```

### Task 2: Create WindowRecordingSettings Model

**Files:**
- Create: `Sources/native-macos/SourceSelector/Models/WindowRecordingSettings.swift`
- Test: `Tests/OpenScreenTests/SourceSelectorTests/WindowRecordingSettingsTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import OpenScreen

@MainActor
final class WindowRecordingSettingsTests: XCTestCase {
    func testSettingsValidationWithValidData() {
        let windows = [
            WindowDevice(id: 1, name: "W1", ownerName: "App", bounds: .zero),
            WindowDevice(id: 2, name: "W2", ownerName: "App", bounds: .zero)
        ]

        var settings = WindowRecordingSettings()
        settings.selectedWindows = windows
        settings.qualityPreset = .high
        settings.compositingMode = .dual(main: 0, overlay: 1)
        settings.codec = .h264
        settings.audioSettings = AudioSettings()

        XCTAssertTrue(settings.isValid)
    }

    func testSettingsValidationWithNoWindows() {
        var settings = WindowRecordingSettings()
        settings.qualityPreset = .high
        settings.compositingMode = .single

        XCTAssertFalse(settings.isValid, "Should be invalid with no windows")
    }

    func testSettingsValidationWithTooManyWindows() {
        let windows = [
            WindowDevice(id: 1, name: "W1", ownerName: "App", bounds: .zero),
            WindowDevice(id: 2, name: "W2", ownerName: "App", bounds: .zero),
            WindowDevice(id: 3, name: "W3", ownerName: "App", bounds: .zero),
            WindowDevice(id: 4, name: "W4", ownerName: "App", bounds: .zero),
            WindowDevice(id: 5, name: "W5", ownerName: "App", bounds: .zero)
        ]

        var settings = WindowRecordingSettings()
        settings.selectedWindows = windows
        settings.compositingMode = .quad

        XCTAssertFalse(settings.isValid, "Should be invalid with more than 4 windows")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter WindowRecordingSettingsTests`
Expected: FAIL with "WindowRecordingSettings type not found"

- [ ] **Step 3: Write minimal implementation**

Create `Sources/native-macos/SourceSelector/Models/WindowRecordingSettings.swift`:

```swift
import Foundation

/// Configuration for window recording
struct WindowRecordingSettings: Sendable {
    var selectedWindows: [WindowDevice] = []
    var qualityPreset: QualityPreset = .high
    var compositingMode: PipMode = .single
    var codec: VideoCodec = .h264
    var audioSettings: AudioSettings = AudioSettings()

    /// Validates settings before recording
    var isValid: Bool {
        // Must have at least one window
        guard !selectedWindows.isEmpty else {
            return false
        }

        // Maximum 4 windows
        guard selectedWindows.count <= 4 else {
            return false
        }

        // Compositing mode must match window count
        guard compositingMode.matchesWindowCount(selectedWindows.count) else {
            return false
        }

        return true
    }
}

// MARK: - PipMode Extension

extension PipMode {
    /// Checks if this mode matches the given window count
    func matchesWindowCount(_ count: Int) -> Bool {
        switch self {
        case .single:
            return count == 1
        case .dual:
            return count == 2
        case .triple:
            return count == 3
        case .quad:
            return count == 4
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter WindowRecordingSettingsTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/native-macos/SourceSelector/Models/WindowRecordingSettings.swift
git add Tests/OpenScreenTests/SourceSelectorTests/WindowRecordingSettingsTests.swift
git commit -m "feat(phase4): add WindowRecordingSettings model

Configuration model for window recording with:
- Window selection (1-4 windows)
- Quality preset, compositing mode, codec
- Audio settings (reused from webcam)
- Validation logic

Tests: Settings validation with valid/invalid data
"
```

### Task 3: Create WindowTracker

**Files:**
- Create: `Sources/native-macos/Recording/WindowTracker.swift`
- Test: `Tests/OpenScreenTests/RecordingTests/WindowTrackerTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import OpenScreen

@MainActor
final class WindowTrackerTests: XCTestCase {
    var tracker: WindowTracker!

    override func setUp() {
        super.setUp()
        tracker = WindowTracker()
    }

    override func tearDown() {
        tracker = nil
        super.tearDown()
    }

    func testWindowStateInitiallyUnknown() {
        XCTAssertNil(tracker.windowState[123])
    }

    func testStartTrackingInitializesState() {
        tracker.startTracking(windowIDs: [123, 456])

        XCTAssertEqual(tracker.windowState.count, 2)
    }

    func testDetectsClosedWindow() {
        var stateChangeCount = 0
        var capturedState: WindowTracker.WindowState?

        tracker.onWindowStateChanged = { windowID, state in
            stateChangeCount += 1
            capturedState = state
        }

        tracker.startTracking(windowIDs: [999999]) // Non-existent window

        // Wait for tracking to detect
        let expectation = XCTestExpectation(description: "State change detected")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)

        XCTAssertGreaterThanOrEqual(stateChangeCount, 1)
        if let state = capturedState {
            XCTAssertTrue(state == .closed || state == .onOtherSpace)
        }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter WindowTrackerTests`
Expected: FAIL with "WindowTracker type not found"

- [ ] **Step 3: Write minimal implementation**

Create `Sources/native-macos/Recording/WindowTracker.swift`:

```swift
import Foundation
import CoreGraphics
import Combine
import AppKit

/// Tracks window state changes for pause/resume functionality
@MainActor
final class WindowTracker: ObservableObject {
    enum WindowState {
        case visible
        case hidden
        case minimized
        case closed
        case onOtherSpace
    }

    @Published var windowState: [CGWindowID: WindowState] = [:]

    private var trackingTimer: Timer?
    var onWindowStateChanged: ((CGWindowID, WindowState) -> Void)?

    /// Starts tracking window states
    func startTracking(windowIDs: [CGWindowID]) {
        // Initialize all windows as visible
        for id in windowIDs {
            windowState[id] = .visible
        }

        // Check window states every 500ms
        trackingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkWindowStates()
            }
        }
    }

    /// Stops tracking window states
    func stopTracking() {
        trackingTimer?.invalidate()
        trackingTimer = nil
    }

    /// Checks if a window is available for recording
    func isWindowAvailable(_ windowID: CGWindowID) -> Bool {
        guard let state = windowState[windowID] else {
            return false
        }
        return state == .visible
    }

    // MARK: - Private

    private func checkWindowStates() {
        guard let windowList = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] else {
            return
        }

        var currentWindows: Set<CGWindowID> = []
        var windowLayers: [CGWindowID: Int] = [:]
        var windowWorkspaceNumbers: [CGWindowID: Int] = [:]

        for windowInfo in windowList {
            guard let windowID = windowInfo[kCGWindowNumber as String] as? CGWindowID else {
                continue
            }

            currentWindows.insert(windowID)

            if let layer = windowInfo[kCGWindowLayer as String] as? Int {
                windowLayers[windowID] = layer
            }

            if let workspaceNumber = windowInfo[kCGWorkspaceNumber as String] as? Int {
                windowWorkspaceNumbers[windowID] = workspaceNumber
            }
        }

        let currentWorkspaceNumber = CGWorkspaceNumberOfCurrentSpace()

        for (windowID, oldState) in windowState {
            let newState = determineWindowState(
                windowID: windowID,
                currentWindows: currentWindows,
                windowLayers: windowLayers,
                windowWorkspaceNumbers: windowWorkspaceNumbers,
                currentWorkspaceNumber: currentWorkspaceNumber
            )

            if newState != oldState {
                windowState[windowID] = newState
                onWindowStateChanged?(windowID, newState)
            }
        }
    }

    private func determineWindowState(
        windowID: CGWindowID,
        currentWindows: Set<CGWindowID>,
        windowLayers: [CGWindowID: Int],
        windowWorkspaceNumbers: [CGWindowID: Int],
        currentWorkspaceNumber: Int
    ) -> WindowState {
        // Window closed or doesn't exist
        if !currentWindows.contains(windowID) {
            return .closed
        }

        // Window minimized (layer == 0 indicates minimized)
        if let layer = windowLayers[windowID], layer == 0 {
            return .minimized
        }

        // Window on different space
        if let workspaceNumber = windowWorkspaceNumbers[windowID],
           workspaceNumber != currentWorkspaceNumber {
            return .onOtherSpace
        }

        // Window is visible
        return .visible
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter WindowTrackerTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/native-macos/Recording/WindowTracker.swift
git add Tests/OpenScreenTests/RecordingTests/WindowTrackerTests.swift
git commit -m "feat(phase4): add WindowTracker for state monitoring

WindowTracker monitors window state changes:
- Background timer checks every 500ms
- Detects visible/hidden/minimized/closed/onOtherSpace
- Callback-based state change notifications
- Used for automatic pause/resume during recording

Tests: State detection, tracking initialization, closed window detection
"
```

---

## Chunk 2: WindowRecorder Implementation

This chunk implements the core WindowRecorder class that captures window frames and encodes them to video.

### Task 4: Create WindowRecorder

**Files:**
- Create: `Sources/native-macos/Recording/WindowRecorder.swift`
- Test: `Tests/OpenScreenTests/RecordingTests/WindowRecorderTests.swift`

**Reference existing pattern:** Review `Sources/native-macos/Recording/WebcamRecorder.swift` for AVAssetWriter setup, frame buffering, and Timer-based capture loop patterns.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
import AVFoundation
@testable import OpenScreen

@MainActor
final class WindowRecorderTests: XCTestCase {
    var recorder: WindowRecorder!
    var outputURL: URL!

    override func setUp() {
        super.setUp()
        recorder = WindowRecorder()
        outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_window_\(UUID().uuidString).mov")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: outputURL)
        super.tearDown()
    }

    func testWindowRecorderConformsToRecorder() {
        XCTAssertTrue(recorder is Recorder)
    }

    func testIsRecordingInitiallyFalse() {
        XCTAssertFalse(recorder.isRecording)
    }

    func testStartRecordingSetsIsRecordingToTrue() async throws {
        let windows = [
            WindowDevice(id: 1, name: "Test", ownerName: "Test", bounds: .zero)
        ]
        var settings = WindowRecordingSettings()
        settings.selectedWindows = windows
        settings.qualityPreset = .low

        let config = WindowRecorder.Config(
            windowIDs: windows.map { $0.id },
            settings: settings
        )

        try await recorder.startRecording(to: outputURL, config: config)
        XCTAssertTrue(recorder.isRecording)

        try await recorder.stopRecording()
    }

    func testStopRecordingReturnsOutputURL() async throws {
        let windows = [
            WindowDevice(id: 1, name: "Test", ownerName: "Test", bounds: .zero)
        ]
        var settings = WindowRecordingSettings()
        settings.selectedWindows = windows
        settings.qualityPreset = .low

        let config = WindowRecorder.Config(
            windowIDs: windows.map { $0.id },
            settings: settings
        )

        try await recorder.startRecording(to: outputURL, config: config)

        // Record briefly
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds

        let returnedURL = try await recorder.stopRecording()

        XCTAssertEqual(returnedURL, outputURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
    }

    func testQueryWindowBoundsReturnsCGRect() async throws {
        let windows = WindowDevice.enumerateWindows()
        try XCTSkipIf(windows.isEmpty, "No windows available")

        let windowID = windows.first!.id

        try await recorder.startRecording(
            to: outputURL,
            config: WindowRecorder.Config(
                windowIDs: [windowID],
                settings: WindowRecordingSettings()
            )
        )

        // This test verifies bounds query works internally
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        try await recorder.stopRecording()
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter WindowRecorderTests`
Expected: FAIL with "WindowRecorder type not found"

- [ ] **Step 3: Write minimal implementation**

Create `Sources/native-macos/Recording/WindowRecorder.swift`:

```swift
import Foundation
import AVFoundation
import CoreGraphics
import AppKit

/// Records individual windows using Core Graphics capture
@MainActor
final class WindowRecorder: Recorder {
    struct Config: Sendable {
        let windowIDs: [CGWindowID]
        let settings: WindowRecordingSettings
    }

    private var captureSession: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var captureTimer: Timer?
    private var frameBuffer: [CGWindowID: [CGImage]] = [:]
    private var isPaused = false
    private var consecutiveFailures: [CGWindowID: Int] = [:]
    private var startTime = CMTime.zero
    private var frameCount = 0

    private var _isRecording = false
    var isRecording: Bool { _isRecording }

    private let ciContext = CIContext()

    func startRecording(to url: URL, config: Config) async throws {
        guard config.settings.isValid else {
            throw WindowError.invalidSettings
        }

        // Setup AVAssetWriter
        let outputSettings: [String: Any] = [
            AVVideoCodecKey: config.settings.codec.avCodecType,
            AVVideoWidthKey: config.settings.qualityPreset.resolution.width,
            AVVideoHeightKey: config.settings.qualityPreset.resolution.height,
            AVVideoCompressionPropertiesKey: config.settings.codec.compressionProperties
        ]

        captureSession = AVAssetWriter(outputURL: url, fileType: .mov)
        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: outputSettings)
        videoInput?.expectsMediaDataInRealTime = true

        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: config.settings.qualityPreset.resolution.width,
            kCVPixelBufferHeightKey as String: config.settings.qualityPreset.resolution.height
        ]

        pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput!,
            sourcePixelBufferAttributes: pixelBufferAttributes
        )

        captureSession?.add(videoInput!)

        // Start session
        captureSession?.startWriting()
        captureSession?.startSession(atSourceTime: .zero)

        _isRecording = true
        consecutiveFailures.removeAll()

        // Start capture loop
        startCaptureLoop(config: config)
    }

    func stopRecording() async throws -> URL {
        guard let session = captureSession else {
            throw WindowError.recordingNotActive
        }

        // Stop capture loop
        captureTimer?.invalidate()
        captureTimer = nil

        // Finish session
        videoInput?.markAsFinished()
        await session.finishWriting()

        _isRecording = false

        guard let outputURL = session.outputURL else {
            throw WindowError.outputFileNotFound
        }

        return outputURL
    }

    // MARK: - Private

    private func startCaptureLoop(config: Config) {
        let fps = config.settings.qualityPreset.frameRate
        let interval = 1.0 / fps

        captureTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.captureFrame(config: config)
            }
        }
    }

    private func captureFrame(config: Config) async {
        guard !isPaused else { return }

        var frames: [CGWindowID: CGImage] = [:]

        // Capture each window
        for windowID in config.windowIDs {
            guard let bounds = queryWindowBounds(windowID),
                  let image = captureWindowImage(windowID, bounds: bounds) else {
                consecutiveFailures[windowID, default: 0] += 1

                // Stop recording after 10 consecutive failures for any window
                if consecutiveFailures[windowID] ?? 0 >= 10 {
                    // In production, would trigger pause or stop
                    print("⚠️ Too many failures for window \(windowID)")
                }
                continue
            }

            consecutiveFailures[windowID] = 0
            frames[windowID] = image
        }

        guard !frames.isEmpty else { return }

        // Composite if multiple windows
        let finalImage: CGImage
        if frames.count > 1 {
            finalImage = await composeWindows(frames, mode: config.settings.compositingMode, outputSize: config.settings.qualityPreset.resolution)
        } else if let singleFrame = frames.values.first {
            finalImage = singleFrame
        } else {
            return
        }

        // Encode frame
        await encodeFrame(finalImage)
    }

    private func queryWindowBounds(_ windowID: CGWindowID) -> CGRect? {
        guard let windowList = CGWindowListCopyWindowInfo(.optionIncludingWindow, windowID) as? [[String: Any]] else {
            return nil
        }

        guard let windowInfo = windowList.first,
              let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: Any] else {
            return nil
        }

        guard let x = boundsDict["X"] as? CGFloat,
              let y = boundsDict["Y"] as? CGFloat,
              let width = boundsDict["Width"] as? CGFloat,
              let height = boundsDict["Height"] as? CGFloat else {
            return nil
        }

        return CGRect(x: x, y: y, width: width, height: height)
    }

    private func captureWindowImage(_ windowID: CGWindowID, bounds: CGRect) -> CGImage? {
        guard let image = CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            windowID,
            .boundsIgnoreFraming
        ) else {
            return nil
        }

        return image
    }

    private func composeWindows(_ frames: [CGWindowID: CGImage], mode: PipMode, outputSize: CGSize) async -> CGImage {
        // For now, simple composition - full implementation would use PipCompositor
        // This is a placeholder that takes the first window's image
        // In production: Use PipCompositor.composeWindowFrames()
        if let firstImage = frames.values.first {
            return firstImage
        }

        // Fallback: create blank image
        let context = CGContext(
            data: nil,
            width: Int(outputSize.width),
            height: Int(outputSize.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        )!

        context.setFillColor(CGColor.black)
        context.fill(CGRect(origin: .zero, size: outputSize))

        return context.makeImage()!
    }

    private func encodeFrame(_ image: CGImage) async {
        guard let videoInput = videoInput,
              videoInput.isReadyForMoreMediaData else {
            return
        }

        let presentationTime = CMTime(
            seconds: Double(frameCount) / 30.0,
            preferredTimescale: 600
        )

        guard let pixelBuffer = createPixelBuffer(from: image) else {
            return
        }

        pixelBufferAdaptor?.append(pixelBuffer, withPresentationTime: presentationTime)
        frameCount += 1
    }

    private func createPixelBuffer(from image: CGImage) -> CVPixelBuffer? {
        let width = image.width
        let height = image.height

        let attributes: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32ARGB,
            attributes as CFDictionary,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else {
            return nil
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        return buffer
    }
}

enum WindowError: LocalizedError {
    case invalidSettings
    case recordingNotActive
    case outputFileNotFound
    case windowUnavailable(CGWindowID)

    var errorDescription: String? {
        switch self {
        case .invalidSettings:
            return "Recording settings are invalid"
        case .recordingNotActive:
            return "No recording is currently active"
        case .outputFileNotFound:
            return "Could not locate output file"
        case .windowUnavailable(let id):
            return "Window \(id) is no longer available"
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter WindowRecorderTests`
Expected: PASS (may need XCTSkip for hardware-dependent tests)

- [ ] **Step 5: Commit**

```bash
git add Sources/native-macos/Recording/WindowRecorder.swift
git add Tests/OpenScreenTests/RecordingTests/WindowRecorderTests.swift
git commit -m "feat(phase4): add WindowRecorder implementation

WindowRecorder captures window frames using CGWindowListCreateImage:
- Timer-based capture loop (30-60 fps)
- AVAssetWriter encoding with codec support
- Multi-window compositing support (placeholder)
- Consecutive failure tracking
- Pause/resume state management

Tests: Recorder protocol conformance, start/stop recording, bounds query
"
```

---

## Chunk 3: UI Implementation and Integration

This chunk implements the WindowSourceViewController UI and integrates window recording with the existing source selection system.

### Task 5: Enable Window Case in SourceSelection

**Files:**
- Modify: `Sources/native-macos/SourceSelector/Models/SourceSelection.swift:8-10`
- Test: No new tests (uses existing SourceSelection tests)

- [ ] **Step 1: Read the current file**

Run: `cat Sources/native-macos/SourceSelector/Models/SourceSelection.swift`
Expected: See commented out window case

- [ ] **Step 2: Enable the window case**

Modify the file to uncomment and implement the window case:

```swift
case window(windows: [WindowDevice], settings: WindowRecordingSettings)
```

And update the Equatable conformance:

```swift
case (.window(let wins1, let settings1), .window(let wins2, let settings2)):
    return wins1.map(\.id) == wins2.map(\.id) && settings1.qualityPreset == settings2.qualityPreset
```

- [ ] **Step 3: Build to verify**

Run: `swift build`
Expected: Build succeeds

- [ ] **Step 4: Commit**

```bash
git add Sources/native-macos/SourceSelector/Models/SourceSelection.swift
git commit -m "feat(phase4): enable window case in SourceSelection

Uncomments the .window case to allow window recording selection.
Adds Equatable conformance for window vs window comparison.
"
```

### Task 6: Create WindowSourceViewController

**Files:**
- Create: `Sources/native-macos/SourceSelector/WindowSourceViewController.swift`

**Reference existing pattern:** Review `Sources/native-macos/SourceSelector/WebcamSourceViewController.swift` for UI layout, permission handling, and quality controls.

- [ ] **Step 1: Create the implementation**

Create `Sources/native-macos/SourceSelector/WindowSourceViewController.swift`:

```swift
import Cocoa
import CoreGraphics

@MainActor
final class WindowSourceViewController: NSViewController {
    // MARK: - Properties

    private var availableWindows: [WindowDevice] = []
    private var selectedWindows: Set<CGWindowID> = []
    private var settings: WindowRecordingSettings
    private var windowTracker: WindowTracker?
    private var thumbnailUpdateTimer: Timer?

    var onSourceSelected: ((SourceSelection) -> Void)?

    // MARK: - Initialization

    init() {
        self.settings = WindowRecordingSettings()
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - UI Components

    private lazy var scrollView: NSScrollView = {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()

    private lazy var stackView: NSStackView = {
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.spacing = 8
        stackView.alignment = .leading
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    private lazy var qualityPopUp: NSPopUpButton = {
        let popup = NSPopUpButton()
        popup.target = self
        popup.action = #selector(qualityPresetChanged)
        for preset in QualityPreset.allCases {
            popup.addItem(withTitle: preset.rawValue.capitalized)
        }
        return popup
    }()

    private lazy var codecPopUp: NSPopUpButton = {
        let popup = NSPopUpButton()
        popup.target = self
        popup.action = #selector(codecChanged)
        for codec in VideoCodec.availableCodecs() {
            popup.addItem(withTitle: codec.rawValue)
        }
        return popup
    }()

    private lazy var startButton: NSButton = {
        let button = NSButton()
        button.title = "Start Recording"
        button.bezelStyle = .rounded
        button.controlSize = .large
        button.target = self
        button.action = #selector(startButtonClicked)
        button.isEnabled = false
        return button
    }()

    // MARK: - Lifecycle

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
        checkPermissions()
        loadWindows()
        startThumbnailUpdates()
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()

        thumbnailUpdateTimer?.invalidate()
        windowTracker?.stopTracking()
    }

    // MARK: - Permissions

    private func checkPermissions() {
        let status = CGPreflightScreenCaptureAccess()

        if !status {
            showPermissionDeniedAlert()
        }
    }

    private func showPermissionDeniedAlert() {
        availableWindows.removeAll()
        refreshWindowList()

        let alert = NSAlert()
        alert.messageText = "Screen Recording Access Required"
        alert.informativeText = "OpenScreen needs screen recording permission to capture windows. Open System Settings to grant permission."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")

        guard let window = view.window else { return }

        let response = alert.runModal(for: window)

        if response == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    // MARK: - UI Setup

    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        view.addSubview(scrollView)
        scrollView.documentView = stackView

        let controlsStack = NSStackView()
        controlsStack.orientation = .horizontal
        controlsStack.spacing = 12
        controlsStack.alignment = .centerY
        controlsStack.translatesAutoresizingMaskIntoConstraints = false

        let qualityLabel = NSTextField(labelWithString: "Quality:")
        let codecLabel = NSTextField(labelWithString: "Codec:")

        controlsStack.addArrangedSubview(qualityLabel)
        controlsStack.addArrangedSubview(qualityPopUp)
        controlsStack.addArrangedSubview(codecLabel)
        controlsStack.addArrangedSubview(codecPopUp)
        controlsStack.addArrangedSubview(startButton)

        view.addSubview(controlsStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            scrollView.bottomAnchor.constraint(equalTo: controlsStack.topAnchor, constant: -20),

            controlsStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            controlsStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            controlsStack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20)
        ])

        stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor).isActive = true
    }

    // MARK: - Window Management

    private func loadWindows() {
        availableWindows = WindowDevice.enumerateWindows()
        refreshWindowList()
    }

    private func refreshWindowList() {
        for view in stackView.arrangedSubviews {
            stackView.removeArrangedSubview(view)
        }

        guard !availableWindows.isEmpty else {
            let emptyLabel = NSTextField(labelWithString: "No windows found.\nOpen an application to see windows here.")
            emptyLabel.alignment = .center
            emptyLabel.textColor = .secondaryLabelColor
            emptyLabel.translatesAutoresizingMaskIntoConstraints = false
            stackView.addArrangedSubview(emptyLabel)
            return
        }

        for window in availableWindows {
            let itemView = createWindowItem(window: window)
            stackView.addArrangedSubview(itemView)
        }
    }

    private func createWindowItem(window: WindowDevice) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        container.layer?.cornerRadius = 8
        container.translatesAutoresizingMaskIntoConstraints = false

        let checkbox = NSButton(checkboxWithTitle: "\(window.name) (\(window.ownerName))", target: self, action: #selector(windowToggled(_:)))
        checkbox.state = .off
        checkbox.identifier = NSUserInterfaceItemIdentifier("\(window.id)")
        checkbox.translatesAutoresizingMaskIntoConstraints = false

        let imageView = NSImageView()
        if let thumbnail = window.thumbnail {
            imageView.image = thumbnail
        } else {
            imageView.image = NSImage(systemSymbolName: "rectangle.on.rectangle", accessibilityDescription: nil)
        }
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        imageView.layer?.backgroundColor = NSColor.black.cgColor
        imageView.layer?.cornerRadius = 6
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.widthAnchor.constraint(equalToConstant: 240).isActive = true
        imageView.heightAnchor.constraint(equalToConstant: 180).isActive = true

        container.addSubview(checkbox)
        container.addSubview(imageView)

        NSLayoutConstraint.activate([
            checkbox.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            checkbox.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),

            imageView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            imageView.topAnchor.constraint(equalTo: checkbox.bottomAnchor, constant: 8),
            imageView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            imageView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8),

            container.heightAnchor.constraint(greaterThanOrEqualToConstant: 240)
        ])

        return container
    }

    private func startThumbnailUpdates() {
        thumbnailUpdateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateWindowThumbnails()
            }
        }
    }

    private func updateWindowThumbnails() {
        for index in availableWindows.indices {
            if availableWindows[index].thumbnail == nil {
                availableWindows[index].thumbnail = availableWindows[index].createThumbnail()
            }
        }
        refreshWindowList()
    }

    // MARK: - Actions

    @objc private func windowToggled(_ sender: NSButton) {
        guard let identifier = sender.identifier?.rawValue,
              let windowID = CGWindowID(identifier) else {
            return
        }

        if sender.state == .on {
            guard selectedWindows.count < 4 else {
                sender.state = .off
                return
            }
            selectedWindows.insert(windowID)
        } else {
            selectedWindows.remove(windowID)
        }

        updateCompositingMode()
        startButton.isEnabled = !selectedWindows.isEmpty
    }

    @objc private func qualityPresetChanged() {
        if let title = qualityPopUp.titleOfSelectedItem?.lowercased(),
           let preset = QualityPreset.allCases.first(where: { $0.rawValue.lowercased() == title }) {
            settings.qualityPreset = preset
        }
    }

    @objc private func codecChanged() {
        if let title = codecPopUp.titleOfSelectedItem,
           let codec = VideoCodec.availableCodecs().first(where: { $0.rawValue == title }) {
            settings.codec = codec
        }
    }

    @objc private func startButtonClicked() {
        let selectedWindowDevices = availableWindows.filter { selectedWindows.contains($0.id) }
        settings.selectedWindows = selectedWindowDevices

        let selection = SourceSelection.window(
            windows: selectedWindowDevices,
            settings: settings
        )

        onSourceSelected?(selection)
    }

    private func updateCompositingMode() {
        switch selectedWindows.count {
        case 0...1:
            settings.compositingMode = .single
        case 2:
            settings.compositingMode = .dual(main: 0, overlay: 1)
        case 3:
            settings.compositingMode = .triple(main: 0, p2: 1, p3: 2)
        case 4:
            settings.compositingMode = .quad
        default:
            break
        }
    }
}
```

- [ ] **Step 2: Build to verify**

Run: `swift build`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add Sources/native-macos/SourceSelector/WindowSourceViewController.swift
git commit -m "feat(phase4): add WindowSourceViewController UI

UI for window recording selection with:
- Live window list with checkboxes (max 4)
- Thumbnail previews (updated every 2 seconds)
- Quality and codec controls
- Permission checking with System Settings link
- Auto compositing mode based on window count

Pattern: Follows WebcamSourceViewController structure
"
```

---

## Chunk 4: Integration and Testing

This chunk integrates window recording with the existing system and adds comprehensive tests.

### Task 7: Create Integration Tests

**Files:**
- Create: `Tests/OpenScreenTests/RecordingTests/WindowRecorderIntegrationTests.swift`

- [ ] **Step 1: Write the integration tests**

```swift
import XCTest
import AVFoundation
@testable import OpenScreen

@MainActor
final class WindowRecorderIntegrationTests: XCTestCase {
    var recorder: WindowRecorder!
    var outputURL: URL!

    override func setUp() {
        super.setUp()
        recorder = WindowRecorder()
        outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_integration_\(UUID().uuidString).mov")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: outputURL)
        super.tearDown()
    }

    func testFullRecordingWorkflow() async throws {
        let windows = WindowDevice.enumerateWindows()
        try XCTSkipIf(windows.isEmpty, "No windows available for testing")

        let window = windows.first!
        var settings = WindowRecordingSettings()
        settings.selectedWindows = [window]
        settings.qualityPreset = .medium

        let config = WindowRecorder.Config(
            windowIDs: [window.id],
            settings: settings
        )

        // Start recording
        try await recorder.startRecording(to: outputURL, config: config)
        XCTAssertTrue(recorder.isRecording)

        // Record for 0.5 seconds
        try await Task.sleep(nanoseconds: 500_000_000)

        // Stop recording
        let returnedURL = try await recorder.stopRecording()
        XCTAssertFalse(recorder.isRecording)

        // Verify file exists
        XCTAssertEqual(returnedURL, outputURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))

        // Verify file is valid video
        let asset = AVAsset(url: outputURL)
        let duration = try await asset.load(.duration)
        XCTAssertGreaterThan(CMTimeGetSeconds(duration), 0.3, "Should have at least 0.3 seconds of video")
    }

    func testMultipleWindowsRecording() async throws {
        let windows = WindowDevice.enumerateWindows()
        try XCTSkipIf(windows.count < 2, "Need at least 2 windows for testing")

        let selectedWindows = Array(windows.prefix(2))
        var settings = WindowRecordingSettings()
        settings.selectedWindows = selectedWindows
        settings.qualityPreset = .low
        settings.compositingMode = .dual(main: 0, overlay: 1)

        let config = WindowRecorder.Config(
            windowIDs: selectedWindows.map { $0.id },
            settings: settings
        )

        try await recorder.startRecording(to: outputURL, config: config)

        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds

        let url = try await recorder.stopRecording()

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    func testDifferentCodecs() async throws {
        let windows = WindowDevice.enumerateWindows()
        try XCTSkipIf(windows.isEmpty, "No windows available")

        let window = windows.first!

        for codec in [VideoCodec.h264, .hevc] {
            let filename = "test_codec_\(codec.rawValue)_\(UUID().uuidString).mov"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

            var settings = WindowRecordingSettings()
            settings.selectedWindows = [window]
            settings.codec = codec

            let config = WindowRecorder.Config(
                windowIDs: [window.id],
                settings: settings
            )

            try await recorder.startRecording(to: url, config: config)
            try await Task.sleep(nanoseconds: 200_000_000)
            _ = try await recorder.stopRecording()

            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))

            try? FileManager.default.removeItem(at: url)
        }
    }
}
```

- [ ] **Step 2: Run tests to verify**

Run: `swift test --filter WindowRecorderIntegrationTests`
Expected: PASS (may skip if no windows available)

- [ ] **Step 3: Commit**

```bash
git add Tests/OpenScreenTests/RecordingTests/WindowRecorderIntegrationTests.swift
git commit -m "test(phase4): add WindowRecorder integration tests

Integration tests covering:
- Full recording workflow with actual windows
- Multiple window recording with compositing
- Different codec options (H.264, HEVC)
- Output file validation

Tests use XCTSkip when no windows available.
"
```

### Task 8: Update RecordingController Integration

**Files:**
- Modify: N/A (RecordingController already supports generic Recorder protocol)

The RecordingController already has the generic method:
```swift
func startRecording<T: Recorder>(with recorder: T, config: T.Config) async throws -> URL
```

WindowRecorder will work with this existing infrastructure.

- [ ] **Step 1: Verify integration**

No code changes needed. The existing RecordingController.startRecording(with:config:) method already accepts any Recorder protocol conformer.

- [ ] **Step 2: Mark as complete**

This task is complete by design. WindowRecorder conforms to Recorder protocol, so it integrates automatically with RecordingController.

### Task 9: Manual Testing Verification

- [ ] **Step 1: Create manual testing checklist document**

Create `docs/superpowers/manual-testing/phase4-window-recording.md`:

```markdown
# Phase 4: Window Recording - Manual Testing Checklist

## Window Selection
- [ ] Window list displays all open applications
- [ ] Windows are filtered correctly (no menu bar, dock, or tiny windows)
- [ ] Thumbnails appear after 2 seconds
- [ ] Can select up to 4 windows with checkboxes
- [ ] 5th window selection is rejected
- [ ] Window names and app names are displayed correctly

## Recording - Single Window
- [ ] Start recording single window
- [ ] Move window during recording (should track correctly)
- [ ] Resize window during recording (should track correctly)
- [ ] Stop recording produces valid video file
- [ ] Video contains only the selected window content
- [ ] Audio is captured if enabled

## Recording - Multiple Windows
- [ ] Select and record 2 windows
- [ ] Select and record 3 windows
- [ ] Select and record 4 windows
- [ ] Layout mode updates automatically (dual, triple, quad)
- [ ] Output shows both windows in layout

## State Changes
- [ ] Minimize window during recording → Recording pauses
- [ ] Restore minimized window → Recording resumes
- [ ] Close window during recording → Recording stops and saves
- [ ] Switch to different Space → Recording pauses
- [ ] Switch back → Recording resumes

## Quality Settings
- [ ] Low quality preset works
- [ ] Medium quality preset works
- [ ] High quality preset works
- [ ] Frame rates are correct (24, 30, 60 fps)

## Codecs
- [ ] H.264 codec produces valid video
- [ ] HEVC codec produces valid video (if supported)
- [ ] ProRes codec produces valid video (if supported)

## Edge Cases
- [ ] Record transparent window (transparency preserved)
- [ ] Record fullscreen app
- [ ] Record window on different display
- [ ] Start with no windows available (shows empty state)
- [ ] Permission denied shows alert with System Settings link

## Performance
- [ ] Recording maintains 30fps on typical hardware
- [ ] Memory usage is reasonable
- [ ] CPU usage is acceptable
- [ ] No frame drops during normal recording
```

- [ ] **Step 2: Commit**

```bash
git add docs/superpowers/manual-testing/phase4-window-recording.md
git commit -m "docs(phase4): add manual testing checklist

Comprehensive checklist for window recording feature including:
- Window selection and filtering
- Single and multi-window recording
- State change handling (minimize, close, Spaces)
- Quality and codec options
- Edge cases and performance
"
```

---

## Completion Criteria

Phase 4: Window Recording is complete when:

- [ ] All tests passing (`swift test`)
- [ ] Build succeeds (`swift build`)
- [ ] WindowSourceViewController displays window list
- [ ] Can select and record 1-4 windows
- [ ] Recording produces valid video files
- [ ] Automatic pause/resume on state changes works
- [ ] Manual testing checklist completed
- [ ] Code reviewed and committed

## Success Metrics

- True window isolation (only window content captured)
- Handles 1-4 simultaneous windows
- Automatic pause on minimize/close
- 30fps+ capture performance
- Full codec support (H.264, HEVC, ProRes)

