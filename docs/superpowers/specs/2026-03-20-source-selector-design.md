# Source Selector Design

**Author:** Claude
**Date:** 2026-03-20
**Status:** Approved - Phased Implementation

## Overview

Create a modal sheet window that allows users to select their video source before recording or editing. The source selector provides four input types: screen recording, window recording, webcam recording, and importing existing video files.

**Implementation Phases:**
- **Phase 1**: Screen selector (multi-monitor support)
- **Phase 2**: Import video file
- **Phase 3**: Webcam recording infrastructure
- **Phase 4**: Window recording (requires different technical approach)

**User Flow:**
1. App launches → WindowManager transitions to `.sourceSelector` state
2. Modal sheet appears with tabbed interface
3. User selects a source:
   - Screen/Window/Webcam → Sheet closes, transitions to `.recording`, recording starts
   - Import → Sheet closes, transitions to `.editing`, video loads into timeline

## Phased Implementation

### Phase 1: Screen Selector (Initial Implementation)

**Scope:**
- Tab 1: Screen selection - List all connected displays with thumbnails
- Tab 2-4: "Coming Soon" placeholders with descriptions
- Pure AppKit implementation (NSTabView)
- Update RecordingController to accept displayID parameter
- Add WindowState transition: `.sourceSelector → .editing`

**Technical Approach:**
- Use `CGDisplay` APIs to enumerate displays
- Capture thumbnails with `CGWindowListCreateImage`
- Modify `RecordingController.startRecording()` to accept `CGDirectDisplayID?`
- Modal sheet with NSWindowController + NSTabViewController

**Success Criteria:**
- User can select from multiple displays
- Recording starts on selected display
- Window state transitions work correctly

### Phase 2: Import Video File

**Scope:**
- Enable Import tab with file browser and drag-drop
- Add WindowState transition support
- Load video into EditorWindowController
- Recent files tracking

**Technical Approach:**
- NSOpenPanel for file selection
- SwiftUI `onDrop` for drag-drop
- UserDefaults for recent files
- AVFoundation for video validation

**Success Criteria:**
- User can import video files
- Video loads directly into editing timeline
- Recent files persist across app launches

### Phase 3: Webcam Recording

**Scope:**
- Full webcam recording infrastructure
- AVCaptureDeviceInput integration
- Live camera previews
- Audio/video sync

**Technical Approach:**
- AVCaptureSession for camera capture
- AVCaptureDeviceInput for video
- Separate audio recording pipeline
- Preview layers using SwiftUI UIViewRepresentable

**Success Criteria:**
- User can select and record from webcam
- Live preview shows camera feed
- Recording includes audio and video

### Phase 4: Window Recording (Research Required)

**Note:** AVFoundation screen capture API doesn't support individual window capture. This phase requires research into alternative approaches:

**Options to Research:**
- CGWindowListCreateImage for screenshots (not video)
- AVCaptureScreenInput with crop rectangles (complex)
- Third-party libraries or frameworks
- macOS Accessibility API integration

**Decision:** Postpone until Phase 1-3 complete, then research feasibility

## Architecture

**Phase 1 Components (AppKit-based):**

```
SourceSelectorWindowController (AppKit)
├── Manages NSWindow lifecycle
├── Handles modal sheet presentation
└── Contains NSTabViewController

NSTabViewController
├── Tab 1: ScreenSourceViewController (implemented)
├── Tab 2: WindowSourceViewController (placeholder)
├── Tab 3: WebcamSourceViewController (placeholder)
└── Tab 4: VideoImportViewController (placeholder)

ScreenSourceViewController
├── NSCollectionView for display list
├── Thumbnail generation
└── Selection handling
```

**Future Components (Phase 2-3):**
- Additional view controllers for each tab
- Webcam recording infrastructure (Phase 3)
- File import system (Phase 2)

**Key Classes (Phase 1):**
- `SourceSelectorWindowController` - NSWindowController subclass
- `ScreenSourceViewController` - NSViewController for screen selection
- `DisplayItem` - Model for display information (ID, name, thumbnail)
- `SourceSelection` - Enum representing selected source type (Phase 1: screen only)

**Data Flow:**

**Launch Flow:**
```
AppDelegate.applicationDidFinishLaunching
    ↓
WindowManager.transition(to: .sourceSelector)
    ↓
WindowManager.setupWindows(for: .sourceSelector)
    ↓
WindowManager.showSourceSelector()
    ↓
Create SourceSelectorWindowController
    ↓
Present as modal sheet on main window
```

**Selection Flow:**
```
User interacts with SwiftUI view
    ↓
SourceSelectorView.onSourceSelected(selection)
    ↓
Pass to SourceSelectorWindowController
    ↓
WindowManager receives callback
    ↓
Branch based on selection type:
    ├─ .screen/.window/.webcam → transition(to: .recording)
    │   ↓
    │   Configure RecordingController with source
    │   ↓
    │   showHUD() → Start recording
    │
    └─ .videoFile → transition(to: .editing)
        ↓
        Create EditorWindowController with video URL
        ↓
        Show editor window
```

## Components

### SourceSelectorWindowController (AppKit)

```swift
final class SourceSelectorWindowController: NSWindowController {
    private var onSourceSelected: ((SourceSelection) -> Void)?
    private var onCancelled: (() -> Void)?

    func presentAsSheet(on window: NSWindow,
                       onSelected: @escaping (SourceSelection) -> Void,
                       onCancelled: @escaping () -> Void)
}
```

- Creates modal sheet window (600x500 fixed size)
- Wraps `SourceSelectorView` in NSHostingController
- Handles ESC key for cancel
- Lightweight coordinator between SwiftUI and AppKit

### SourceSelection Model

```swift
enum SourceSelection {
    case screen(displayID: CGDirectDisplayID, displayName: String)
    case window(windowID: CGWindowID, windowName: String, ownerName: String)
    case webcam(deviceID: String, deviceName: String)
    case videoFile(url: URL)
}
```

### Tab Views - Common Pattern

Each tab follows this structure:
- State: `@State private var selectedItem: ItemType?`
- Preview: Async/thumbnail generation for visual selection
- Selection: Single-selection with visual highlight
- Confirm: "Start" or "Import" button (enabled when selection made)

**Screen Tab:**
- Uses `CGDisplay` APIs to enumerate displays
- Captures thumbnails using `CGWindowListCreateImage`
- Shows display name, resolution, thumbnail preview

**Window Tab:**
- Uses `CGWindowListCopyWindowInfo` to enumerate windows
- Shows app icon, window name, owner name
- Filters out own app windows

**Webcam Tab:**
- Uses `AVCaptureDevice` to enumerate cameras
- Live preview using `AVCaptureVideoPreviewLayer`
- Shows device name, resolution, live feed

**Import Tab:**
- NSOpenPanel for file browsing
- Drag-drop zone using `onDrop` modifier
- Recent files list from UserDefaults

## Error Handling

### Source Detection Errors

- **No displays detected**: Show message "No displays available. Check your display connections."
- **No windows detected**: Show message "No windows found. Some apps may be running in full-screen mode."
- **No cameras detected**: Show message "No cameras found. Connect a camera and try again."
- **Permission denied**: Screen/camera access denied → Show button to open System Settings

### File Import Errors

- **Invalid file format**: "Unsupported video format. Please select MP4, MOV, or MKV files."
- **File too large**: "This file is very large (X GB). Import may take a while."
- **File corrupted**: "Unable to read this video file. It may be corrupted."

### User Actions

- **Cancel**: ESC key or Cancel button → returns to `.idle` state
- **No selection**: Start/Import buttons disabled until selection made
- **Retry**: "Refresh" button on each tab to re-enumerate sources

### Error Presentation

- In-sheet error messages (no separate alerts)
- Red/warning color coding for errors
- Actionable error messages (e.g., "Open System Settings" button)

## Testing Strategy

### Unit Tests

- `SourceSelection` enum encoding/decoding
- Display enumeration logic
- Window filtering logic (exclude own app)
- Camera device enumeration
- File validation (format, size checks)

### Integration Tests

- WindowManager state transitions: `.idle` → `.sourceSelector` → `.recording/.editing`
- Callback propagation from SwiftUI to WindowController
- RecordingController receives correct source configuration
- EditorWindowController receives video file URL

### UI Tests (Manual)

- Each tab loads and displays sources correctly
- Previews render for screens, windows, webcams
- Drag-drop works for import tab
- ESC key cancels the sheet
- Selection buttons enable/disable correctly

### Edge Cases to Test

- Multi-monitor setups (2+ displays)
- No windows available (all apps full-screen)
- No cameras connected
- Very large video files (>5GB)
- Corrupted video files
- Permission denied scenarios

### Performance Considerations

- Thumbnail generation should not block UI
- Webcam previews should run at reasonable FPS
- Window enumeration should complete quickly

## Implementation Notes

**Window Behavior:**
- Modal sheet attached to main window (or centered on screen if no parent)
- Non-resizable
- Closes when selection is made or cancelled
- ESC key or Cancel button returns to `.idle` state

**Preview Generation:**
- **Screen thumbnails**: `CGWindowListCreateImage` → processed asynchronously
- **Window list**: `CGWindowListCopyWindowInfo` → filtered on main thread
- **Webcam previews**: `AVCaptureVideoPreviewLayer` → SwiftUI `UIViewRepresentable`
- **Video file thumbnails**: `AVAssetImageGenerator` → async image generation

**State Management:**
- WindowManager owns `sourceSelectorWindowController` reference
- SwiftUI views are stateless, pass selections up via closures
- No persistent state needed - selections are transient

## Files to Create (Phase 1)

1. `Sources/native-macos/SourceSelector/SourceSelectorWindowController.swift`
2. `Sources/native-macos/SourceSelector/ScreenSourceViewController.swift`
3. `Sources/native-macos/SourceSelector/Models/DisplayItem.swift`
4. `Sources/native-macos/SourceSelector/Models/SourceSelection.swift`

## Files to Modify (Phase 1)

1. `Sources/native-macos/App/WindowManager.swift` - Implement `showSourceSelector()` method
2. `Sources/native-macos/Shared/Models/WindowState.swift` - Add `.sourceSelector → .editing` transition
3. `Sources/native-macos/Recording/RecordingController.swift` - Update API to accept displayID parameter

## Files to Create (Phase 2)

1. `Sources/native-macos/SourceSelector/VideoImportViewController.swift`
2. `Sources/native-macos/SourceSelector/Models/RecentFilesManager.swift`

## Files to Create (Phase 3)

1. `Sources/native-macos/Recording/WebcamRecorder.swift`
2. `Sources/native-macos/SourceSelector/WebcamSourceViewController.swift`
3. `Sources/native-macos/SourceSelector/Views/CameraPreviewView.swift`

## API Changes Required

### RecordingController.startRecording() Update

**Current Signature:**
```swift
func startRecording() async throws -> URL
```

**New Signature (Phase 1):**
```swift
func startRecording(displayID: CGDirectDisplayID? = nil) async throws -> URL
```

**Implementation:**
```swift
func startRecording(displayID: CGDirectDisplayID? = nil) async throws -> URL {
    let targetDisplay = displayID ?? NSScreen.main?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? CGMainDisplayID()
    return try await screenRecorder.startRecording(to: outputURL, displayID: targetDisplay)
}
```

### WindowState Transition Update

**Current:**
```swift
case .sourceSelector:
    return [.idle, .recording]
```

**Updated:**
```swift
case .sourceSelector:
    return [.idle, .recording, .editing]
```
