# Phase 4: Window Recording Design Specification

> **Status:** Design Approved
> **Created:** 2026-03-20
> **Phase:** 4 - Window Recording

## Overview

Implement window recording capability for OpenScreen, allowing users to record individual application windows while excluding other on-screen content. Supports 1-4 simultaneous windows with picture-in-picture compositing, automatic pause/resume when windows become unavailable, and full audio integration.

## Goals

- **Primary Use Case:** Record specific application windows while excluding all other on-screen content
- **Multi-Window Support:** Record up to 4 windows simultaneously with PIP layouts
- **Seamless Handling:** Automatically pause when windows are hidden/minimized, resume when visible
- **Consistent UX:** Match existing screen/webcam recording UI patterns
- **True Window Isolation:** Capture only the target window(s), not full screen with cropping

## Architecture

### Technical Approach

Use Core Graphics Window Services APIs for window enumeration and capture:

- **CGWindowListCopyWindowInfo** - Query window metadata (bounds, owner name, visibility state)
- **CGWindowListCreateImage** - Capture individual window frames directly
- **AVAssetWriter** - Encode captured frames (reusing existing pipeline)
- **PipCompositor** - Layout multiple windows (existing component)

This approach provides true window isolation - other screen content is never captured, and window movement/resizing is handled automatically.

### System Architecture

```
WindowSourceViewController (UI)
├── Shows live window list with thumbnails
├── Up to 4 windows with checkboxes
├── Quality/codec controls (same as webcam)
└── Start/Stop recording button

WindowRecorder (Recorder Protocol)
├── Capture loop (Timer-based, 30-60 fps)
├── Window bounds tracking per frame
├── Frame capture via CGWindowListCreateImage
├── Multi-window compositing via PipCompositor
└── AVAssetWriter encoding

WindowTracker (State Monitor)
├── Background timer (500ms)
├── Detects window visibility changes
├── Triggers pause/resume notifications
└── Handles window closure

RecordingController (Orchestrator)
├── Accepts WindowRecorder via generic startRecording
├── Manages recording lifecycle
└── Saves final output
```

### Data Flow

1. **Selection Phase**
   - WindowSourceViewController enumerates windows via `WindowDevice.enumerateWindows()`
   - User selects 1-4 windows with checkboxes
   - Quality settings selected (preset, codec, audio)
   - Start button creates `WindowRecorder.Config`

2. **Recording Phase**
   - `RecordingController.startRecording(with: windowRecorder, config:)` called
   - WindowRecorder starts capture loop Timer
   - Each frame (~33ms for 30fps, ~16ms for 60fps):
     - Query window bounds for each window ID
     - Capture window image via CGWindowListCreateImage
     - If multiple windows: Use PipCompositor to layout frames
     - Convert CGImage to CVPixelBuffer
     - Write to AVAssetWriterInput
   - WindowTracker runs background check every 500ms

3. **State Changes**
   - Window minimized/hidden: WindowTracker detects → Pause capture → Show notification
   - Window visible again: WindowTracker detects → Resume capture → Dismiss notification
   - Window closed: WindowTracker detects → Stop recording → Save output

4. **Completion**
   - User clicks Stop (or recording stops automatically)
   - WindowRecorder finishes AVAssetWriter session
   - Returns URL to RecordingController
   - WindowManager transitions to .editing state

## Components

### 1. WindowRecorder

**File:** `Sources/native-macos/Recording/WindowRecorder.swift`

```swift
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

    func startRecording(to url: URL, config: Config) async throws
    func stopRecording() async throws -> URL
    var isRecording: Bool { get }

    // Private helpers
    private func startCaptureLoop()
    private func captureFrame() async
    private func queryWindowBounds(_ windowID: CGWindowID) -> CGRect?
    private func captureWindowImage(_ windowID: CGWindowID, bounds: CGRect) -> CGImage?
    private func pauseRecording()
    private func resumeRecording()
}
```

**Responsibilities:**
- Conform to Recorder protocol for integration with RecordingController
- Manage capture loop Timer for frame-by-frame recording
- Query window bounds on each frame to handle movement/resizing
- Capture window images using CGWindowListCreateImage
- Composite multiple windows using PipCompositor
- Encode frames via AVAssetWriter
- Handle pause/resume state
- Manage frame buffering for synchronization

### 2. WindowDevice

**File:** `Sources/native-macos/SourceSelector/Models/WindowDevice.swift`

```swift
struct WindowDevice: Identifiable, Sendable {
    let id: CGWindowID
    let name: String
    let ownerName: String
    let bounds: CGRect
    var thumbnail: NSImage?

    static func enumerateWindows() -> [WindowDevice]
    static func updateWindowBounds(_ devices: inout [WindowDevice])

    func createThumbnail() -> NSImage?
}
```

**Responsibilities:**
- Model window metadata for display in UI
- Provide window enumeration via CGWindowListCopyWindowInfo
- Filter out invalid windows (menu bar, dock, invisible windows)
- Generate thumbnails for window picker UI
- Track window bounds changes

**Window Filtering Rules:**
- Exclude windows with `kCGWindowLayer == 0` (menu bar, dock)
- Exclude windows without a name or owner
- Exclude windows smaller than 100x100 pixels
- Exclude windows owned by OpenScreen itself
- Include windows from all spaces (not just current)

### 3. WindowRecordingSettings

**File:** `Sources/native-macos/SourceSelector/Models/WindowRecordingSettings.swift`

```swift
struct WindowRecordingSettings: Sendable {
    var selectedWindows: [WindowDevice]
    var qualityPreset: QualityPreset  // Reuse from webcam
    var compositingMode: PipMode      // Reuse from webcam
    var codec: VideoCodec             // Reuse from webcam
    var audioSettings: AudioSettings  // Reuse from webcam

    var isValid: Bool {
        !selectedWindows.isEmpty &&
        selectedWindows.count <= 4 &&
        compositingMode.matchesWindowCount(selectedWindows.count)
    }
}
```

**Responsibilities:**
- Encapsulate all recording configuration
- Reuse existing quality/codec/audio models from webcam
- Validate settings before recording starts

### 4. WindowTracker

**File:** `Sources/native-macos/Recording/WindowTracker.swift`

```swift`
@MainActor
final class WindowTracker: ObservableObject {
    @Published var windowState: [CGWindowID: WindowState] = [:]

    private var trackingTimer: Timer?
    var onWindowStateChanged: ((CGWindowID, WindowState) -> Void)?

    func startTracking(windowIDs: [CGWindowID])
    func stopTracking()
    func isWindowAvailable(_ windowID: CGWindowID) -> Bool

    // Private
    private func checkWindowStates()
}

enum WindowState {
    case visible
    case hidden
    case minimized
    case closed
    case onOtherSpace
}
```

**Responsibilities:**
- Monitor window state in background (500ms timer)
- Detect visibility changes (hidden/minimized/closed)
- Trigger pause/resume via callbacks
- Notify UI of state changes

### 5. WindowSourceViewController

**File:** `Sources/native-macos/SourceSelector/WindowSourceViewController.swift`

```swift
@MainActor
final class WindowSourceViewController: NSViewController {
    private var availableWindows: [WindowDevice] = []
    private var selectedWindows: Set<CGWindowID> = []
    private var settings: WindowRecordingSettings
    private var windowTracker: WindowTracker?

    var onSourceSelected: ((SourceSelection) -> Void)?

    // UI Components
    private lazy var scrollView: NSScrollView
    private lazy var stackView: NSStackView
    private lazy var qualityPopUp: NSPopUpButton
    private lazy var codecPopUp: NSPopUpButton
    private lazy var startButton: NSButton
    private lazy var pauseNotification: NSView

    // Lifecycle
    override func viewDidLoad()
    private func setupUI()
    private func loadWindows()

    // Window list
    private func refreshWindowList()
    private func createWindowItem(window: WindowDevice) -> NSView
    private func updateWindowThumbnails()

    // Actions
    @objc private func windowToggled(_ sender: NSButton)
    @objc private func qualityPresetChanged()
    @objc private func codecChanged()
    @objc private func startButtonClicked()

    // State handling
    private func handleWindowStateChange(_ windowID: CGWindowID, _ state: WindowState)
    private func showPauseNotification()
    private func hidePauseNotification()
}
```

**Responsibilities:**
- Display live window list with real-time thumbnails
- Handle window selection (checkboxes, max 4)
- Show quality/codec controls
- Start/stop recording
- Display pause notification when window unavailable
- Handle permission requests

**UI Layout:**
```
┌─────────────────────────────────────────┐
│ [Scrollable Window List]               │
│ ┌───────────────────────────────────┐  │
│ │ ☑ Safari Browser                 │  │
│ │ [Thumbnail 240x180]              │  │
│ └───────────────────────────────────┘  │
│ ┌───────────────────────────────────┐  │
│ │ ☐ Finder                         │  │
│ │ [Thumbnail 240x180]              │  │
│ └───────────────────────────────────┘  │
├─────────────────────────────────────────┤
│ Quality: [High ▼] Codec: [H.264 ▼]    │
│              [Start Recording]         │
└─────────────────────────────────────────┘
```

### 6. SourceSelection Updates

**File:** `Sources/native-macos/SourceSelector/Models/SourceSelection.swift`

Enable the window case:

```swift
enum SourceSelection: Sendable {
    case screen(displayID: CGDirectDisplayID, displayName: String)
    case webcam(cameras: [CameraDevice], settings: WebcamRecordingSettings)
    case window(windows: [WindowDevice], settings: WindowRecordingSettings)  // NEW
    case videoFile(url: URL)
}
```

## Technical Implementation Details

### Window Capture Loop

**Timer-Based Capture** (similar to WebcamRecorder):

```swift
private func startCaptureLoop() {
    let fps = settings.qualityPreset.frameRate
    let interval = 1.0 / fps

    captureTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
        Task { @MainActor in
            await self.captureFrame()
        }
    }
}

private func captureFrame() async {
    guard !isPaused else { return }

    var frames: [CGWindowID: CGImage] = [:]

    // Capture each window
    for windowID in config.windowIDs {
        guard let bounds = queryWindowBounds(windowID),
              let image = captureWindowImage(windowID, bounds: bounds) else {
            continue
        }
        frames[windowID] = image
    }

    // Composite if multiple windows
    let finalImage: CGImage
    if frames.count > 1 {
        finalImage = await PipCompositor.shared.composeWindowFrames(
            frames,
            mode: settings.compositingMode,
            outputSize: settings.qualityPreset.resolution
        )
    } else if let singleFrame = frames.values.first {
        finalImage = singleFrame
    } else {
        return  // No frames captured
    }

    // Encode frame
    await encodeFrame(finalImage)
}
```

### Window Bounds Query

```swift
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
```

### Window Image Capture

```swift
private func captureWindowImage(_ windowID: CGWindowID, bounds: CGRect) -> CGImage? {
    // Capture window at its current bounds
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
```

### Frame Buffering Strategy

Reuse WebcamRecorder's approach:
- Buffer up to 3 frames per window
- 100ms timeout before skipping frame
- Use slowest window as master clock
- Prevents out-of-sync frames

### Pause/Resume Mechanism

```swift
private func pauseRecording() {
    isPaused = true
    captureTimer?.invalidate()
    showPauseNotification()
}

private func resumeRecording() {
    isPaused = false
    startCaptureLoop()
    hidePauseNotification()
}
```

During pause:
- Capture timer stops
- AVAssetWriter session continues (freeze last frame)
- Audio continues recording (trimmed in post)

### Thumbnail Generation

```swift
func createThumbnail() -> NSImage? {
    guard let bounds = queryWindowBounds(id),
          let image = CGWindowListCreateImage(.null, .optionIncludingWindow, id, .boundsIgnoreFraming) else {
        return nil
    }

    // Scale to thumbnail size
    let thumbnailSize = NSSize(width: 160, height: 120)
    let scaledImage = NSImage(cgImage: image, size: thumbnailSize)

    return scaledImage
}
```

Thumbnail updates:
- Run every 2 seconds (not real-time)
- Only for visible windows in list
- Update existing WindowDevice objects
- Trigger UI refresh

## Error Handling & Edge Cases

### Permission Handling

**Screen Recording Permission Required**

Same flow as WebcamSourceViewController:
```swift
private func checkPermissions() {
    let status = CGPreflightScreenCaptureAccess()

    if !status {
        // Show permission denied alert
        // Offer to open System Settings
        CGRequestScreenCaptureAccess()
    }
}
```

### Window State Transitions

| Event | Detection | Action |
|-------|-----------|--------|
| Window minimized | `kCGWindowLayer` check | Pause recording, show notification |
| Window hidden | Window bounds query fails | Pause recording, show notification |
| Window closed | WindowID disappears from list | Stop recording, save output |
| Window moves to other Space | `kCGWorkspaceNumber` check | Pause, show "moved to desktop" message |
| Window obscured by other windows | N/A | Continue recording (we capture window, not screen) |

### Multi-Window Scenarios

**Partial Failure:**
If one window fails but others succeed:
- Skip failed window for that frame
- Continue recording other windows
- Log error for debugging
- After 10 consecutive failures: Stop recording

**Window Count Mismatch:**
If user selects 3 windows but compositing mode is dual:
- Auto-switch compositing mode to triple
- Show brief notification

**Windows with Different Sizes:**
- PipCompositor handles resize/scale
- Maintain aspect ratios
- Letterbox/pillarbox as needed

### Transparency and Special Cases

**Transparent Windows:**
- CGWindowListCreateImage preserves alpha channel
- Encode with transparency if codec supports
- Otherwise composite over black background

**Fullscreen Windows:**
- Capture at fullscreen resolution
- No special handling needed

**High DPI/Retina:**
- Use window's backing scale factor
- Capture at native resolution
- Scale down for output if needed

### Fallback Behavior

**Capture Failure Recovery:**
```swift
private var consecutiveFailures: [CGWindowID: Int] = [:]

private func handleCaptureFailure(for windowID: CGWindowID) {
    consecutiveFailures[windowID, default: 0] += 1

    if consecutiveFailures[windowID] ?? 0 >= 10 {
        // Too many failures, stop recording
        stopRecordingWithError(.windowUnavailable(windowID))
    }
}
```

**Bounds Query Failure:**
- If bounds query fails: Skip frame for that window
- If multi-window: Continue with other windows
- If single-window: Pause and notify

## Audio Integration

Reuse existing audio pipeline from WebcamRecorder:
- System audio capture via ScreenRecorder's audio tap
- Microphone capture via AVCaptureDevice
- AudioMixer for combining sources
- Per-source volume/mute controls
- Encoded alongside video by AVAssetWriter

**Audio During Pause:**
- Continue recording audio during window pause
- Creates seamless audio track
- Video freeze-frame during pause
- User can trim pause period in editing

## Testing Strategy

### Unit Tests

**WindowDeviceTests** (`Tests/OpenScreenTests/SourceSelectorTests/WindowDeviceTests.swift`)
- `testEnumerateWindows` - Verify window enumeration
- `testWindowFiltering` - Confirm invalid windows excluded
- `testThumbnailGeneration` - Check thumbnail creation
- `testBoundsExtraction` - Validate bounds parsing

**WindowRecordingSettingsTests** (`Tests/OpenScreenTests/SourceSelectorTests/WindowRecordingSettingsTests.swift`)
- `testValidation` - Settings validity checks
- `testCompositingModeMatch` - Mode matches window count
- `testCodecSupport` - Codec availability

**WindowTrackerTests** (`Tests/OpenScreenTests/RecordingTests/WindowTrackerTests.swift`)
- `testVisibleWindowDetection` - Detect visible windows
- `testMinimizedWindowDetection` - Detect minimized state
- `testClosedWindowDetection` - Detect closed windows
- `testStateChangeCallbacks` - Verify callback triggers

**WindowRecorderTests** (`Tests/OpenScreenTests/RecordingTests/WindowRecorderTests.swift`)
- `testSingleWindowRecording` - Record one window
- `testMultiWindowRecording` - Record multiple windows
- `testBoundsQuery` - Window bounds query
- `testFrameCapture` - Window image capture
- `testPauseResume` - Pause/resume logic
- `testConsecutiveFailureHandling` - Failure recovery

### Integration Tests

**WindowRecorderIntegrationTests**
- Full recording workflow with actual windows
- Verify output file plays correctly
- Check audio sync
- Validate frame timestamps

**MultiWindowRecordingTests**
- 2-window side-by-side layout
- 4-window quad layout
- Layout correctness with different window sizes

**WindowStateChangeTests**
- Minimize window during recording
- Close window during recording
- Switch Spaces during recording
- Resume after state changes

### Hardware Dependencies

Tests requiring actual windows use `XCTSkip`:
```swift
func testWindowRecordingWithActualWindow() throws {
    let windows = WindowDevice.enumerateWindows()
    try XCTSkipIf(windows.isEmpty, "No windows available for testing")
    // Proceed with test
}
```

### Manual Testing Checklist

- [ ] Record single window while moving it around
- [ ] Record window while resizing it
- [ ] Minimize window during recording (should pause)
- [ ] Close window during recording (should stop and save)
- [ ] Record 2 windows side-by-side
- [ ] Record 4 windows in quad layout
- [ ] Record transparent window (verify transparency preserved)
- [ ] Record fullscreen app
- [ ] Switch Spaces during recording
- [ ] Verify audio sync in output
- [ ] Test permission denied flow
- [ ] Test with codec variations (H.264, HEVC, ProRes)
- [ ] Test quality presets (low, medium, high)

## Implementation Notes

### Performance Considerations

**Thumbnail Updates:**
- Limit to 2 updates per second (not real-time)
- Only update windows visible in scroll view
- Use NSCache for thumbnail storage

**Frame Capture:**
- Target 30fps or 60fps based on quality preset
- Reuse frame buffering strategy from WebcamRecorder
- Skip frames if capture takes too long

**Memory Management:**
- Release CGImage objects immediately after use
- Limit frame buffer size (3 frames per window)
- Clear thumbnail cache when view disappears

### Dependencies on Existing Code

**Reuses:**
- `Recorder` protocol (existing)
- `RecordingController` generic method (existing)
- `PipCompositor` (existing)
- `AudioMixer` (existing)
- `QualityPreset`, `VideoCodec`, `AudioSettings` (existing)
- `AVAssetWriter` pipeline (existing pattern)

**New:**
- WindowRecorder implementation
- WindowDevice model
- WindowRecordingSettings
- WindowTracker
- WindowSourceViewController

### Migration Path

No breaking changes to existing code:
- SourceSelection.window case enabled
- WindowRecorder registered with RecordingController
- New tab in SourceSelectorWindowController

## Success Criteria

- [ ] Users can select and record individual windows
- [ ] Supports 1-4 simultaneous windows
- [ ] Automatic pause/resume when windows unavailable
- [ ] Real-time window thumbnails in picker
- [ ] Consistent UI with screen/webcam recording
- [ ] Audio integration works correctly
- [ ] Handles all edge cases (minimize, close, move, resize)
- [ ] Performance acceptable (30fps+ on typical hardware)
- [ ] All tests passing
- [ ] Manual testing checklist complete

## Open Questions

None - design fully specified.

## Future Enhancements (Out of Scope)

- Window region selection (record portion of a window)
- Window-specific audio capture (app audio only)
- Window pre-selection (favorites/quick access)
- Advanced layouts (custom positioning, not just PIP presets)
- Window recording with mouse cursor capture
- OCR-based window detection (select window by clicking)
