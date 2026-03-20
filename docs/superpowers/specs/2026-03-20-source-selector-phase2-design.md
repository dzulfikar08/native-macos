# Source Selector Phase 2: Import Video File

**Author:** Claude
**Date:** 2026-03-20
**Status:** Design Complete - Awaiting Implementation

## Overview

Enable users to import existing video files directly into the editor with full validation and system-level recent files tracking.

**Scope:**
- Replace VideoImportViewController placeholder with full implementation
- Integrate NSDocumentController for system-wide file handling
- Add comprehensive video validation (duration, resolution, codec compatibility)
- Support app-wide drag-drop functionality
- Direct loading into editing timeline

**User Flow:**
1. User opens source selector → switches to Import tab
2. Import tab shows recent files + browse button
3. User selects file (recent list, browser, or drag-drop)
4. Video validation runs → metadata displayed
5. User confirms import
6. EditorWindowController created with video URL
7. State transitions to .editing, video loads into timeline

## Architecture

### Components

**1. VideoImportViewController (AppKit-based)**
- Recent files list (top half) - max 8 items
- Browse button with file type filters (bottom half)
- Metadata display panel
- Validation error messages
- Thumbnail generation for recent files

**2. NSDocumentController Integration**
- System-level recent files (File → Open Recent menu)
- App-wide drag-drop support
- Automatic persistence across app launches

**3. VideoValidator (new utility class)**
- AVFoundation-based validation
- Metadata extraction (duration, resolution, codecs)
- Compatibility checking
- Thumbnail generation

**4. WindowManager Updates**
- Handle `.videoFile` selection from source selector
- Create EditorWindowController with video URL
- Transition to `.editing` state

### Data Flow

```
User opens Import tab
    ↓
VideoImportViewController loads recent files
    ↓
User selects file (recent list / browser / drag-drop)
    ↓
VideoValidator.validate(url:) runs
    ↓
Show metadata + import confirmation dialog
    ↓
User confirms → onVideoSelected(url)
    ↓
WindowManager receives .videoFile(url)
    ↓
Validate video again (security check)
    ↓
transition(to: .editing)
    ↓
Create EditorWindowController(recordingURL: url)
    ↓
Show editor window with video loaded
```

### Recent Files Sync

```
After successful import
    ↓
NSDocumentController.noteNewRecentDocumentURL(url)
    ↓
Automatically:
  - Added to File → Open Recent menu
  - Persisted to UserDefaults
  - Appears in Import tab recent files list
```

## Components

### VideoImportViewController

```swift
@MainActor
final class VideoImportViewController: NSViewController {
    // MARK: - Properties
    private var recentFilesURLs: [URL] = []
    private var selectedURL: URL?
    private var metadata: VideoMetadata?
    private var thumbnailCache: [URL: NSImage] = [:]

    // MARK: - UI Components
    private var scrollView: NSScrollView?
    private var recentFilesStack: NSStackView?
    private var browseButton: NSButton?
    private var metadataPanel: NSView?
    private var validationMessage: NSTextField?

    // MARK: - Callbacks
    var onVideoSelected: ((URL) -> Void)?

    // MARK: - Lifecycle
    override func viewDidLoad()
    override func viewWillAppear()

    // MARK: - Recent Files
    private func loadRecentFiles()
    private func createRecentFileItem(for url: URL) -> NSView
    private func refreshRecentFilesList()

    // MARK: - File Browser
    @objc private func browseButtonClicked()
    private func showFileOpenPanel()

    // MARK: - Video Selection
    private func selectVideo(at url: URL)
    private func showImportConfirmation(metadata: VideoMetadata)

    // MARK: - Metadata Display
    private func displayMetadata(_ metadata: VideoMetadata)
    private func createMetadataPanel(for metadata: VideoMetadata) -> NSView

    // MARK: - Validation
    private func handleValidationError(_ error: VideoValidationError)
    private func updateValidationMessage(_ message: String?, isError: Bool)

    // MARK: - Drag & Drop
    private func setupDragAndDrop()
}

// MARK: - Dragging Destination
extension VideoImportViewController {

    /// Sets up drag-drop support for the view
    private func setupDragAndDrop() {
        view.registerForDraggedTypes([.fileURL])
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if let board = sender.draggingPasteboard.pasteboardItems?.first,
           board.types?.contains(.fileURL) == true {
            return .copy
        }
        return []
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let board = sender.draggingPasteboard.pasteboardItems?.first,
              let fileURLString = board.string(forType: .fileURL),
              let fileURL = URL(string: fileURLString) else {
            return false
        }

        // Validate it's a video file
        if VideoValidator.isSupportedFormat(url: fileURL) {
            selectVideo(at: fileURL)
            return true
        }

        return false
    }
}
```

**Responsibilities:**
- Load and display recent files from NSDocumentController
- Handle file selection via recent list, browser, or drag-drop
- Display video metadata (duration, resolution, codec, file size)
- Show validation errors with helpful messages
- Generate and cache thumbnails for recent files
- Call onVideoSelected callback when user confirms import
- Handle drag-drop events (app-wide and in import tab)

**UI Layout:**
```
┌─────────────────────────────────────┐
│  Import Video File                  │
├─────────────────────────────────────┤
│  Recent Files (scrollable, max 10)  │
│  ┌───────────────────────────────┐  │
│  │ [thumb] video1.mp4    00:15  │  │
│  │ [thumb] recording.mov  05:30  │  │
│  │ ...                           │  │
│  └───────────────────────────────┘  │
├─────────────────────────────────────┤
│  [Browse Files...]                 │
├─────────────────────────────────────┤
│  Metadata Panel                     │
│  Duration: 00:05:30                │
│  Resolution: 1920 × 1080           │
│  Size: 125 MB                      │
│                                     │
│  [Import] [Cancel]                 │
└─────────────────────────────────────┘
```

### VideoValidator (New)

```swift
struct VideoMetadata {
    let duration: CMTime
    let durationString: String
    let resolution: CGSize
    let frameRate: Float
    let codec: String
    let fileSize: Int64
    let isCompatible: Bool
    let warnings: [String]
    let thumbnail: NSImage?
}

enum VideoValidationError: Error {
    case fileNotFound(URL)
    case unsupportedFormat(String)
    case corruptedFile
    case tooLarge(Int64) // size in bytes
    case noVideoTrack

    var localizedDescription: String { ... }
}

struct VideoValidator {

    /// Validates a video file and extracts metadata
    /// - Parameter url: URL of video file to validate
    /// - Returns: Result<VideoMetadata, VideoValidationError>
    static func validate(url: URL) -> Result<VideoMetadata, VideoValidationError>

    /// Generates thumbnail for video
    /// - Parameters:
    ///   - url: URL of video file
    ///   - maxDimension: Maximum width/height of thumbnail
    /// - Returns: NSImage thumbnail
    /// - Throws: VideoValidationError
    static func getThumbnail(url: URL, maxDimension: CGFloat) async throws -> NSImage

    /// Checks if file format is supported
    /// - Parameter url: URL to check
    /// - Returns: true if AVFoundation can open the file
    static func isSupportedFormat(url: URL) -> Bool {
        guard let uti = UTType(filenameExtension: url.pathExtension) else {
            return false
        }

        let supportedTypes: [UTType] = [
            .movie,
            .mpeg4Movie,
            .quickTimeMovie,
            .audiovisualContent
        ]

        return supportedTypes.contains { uti.conforms(to: $0) }
    }

    // MARK: - Private Helpers
    private static func extractMetadata(from asset: AVAsset) -> VideoMetadata?
    private static func formatDuration(_ duration: CMTime) -> String
    private static func checkCompatibility(tracks: [AVAssetTrack]) -> (isCompatible: Bool, warnings: [String])
}
```

**Responsibilities:**
- Validate video files using AVFoundation
- Extract comprehensive metadata (duration, resolution, codec, frame rate)
- Generate thumbnails for UI display
- Check codec compatibility and warn about potential issues
- Provide helpful error messages for validation failures

### VideoMetadata Model (New)

```swift
struct VideoMetadata: Sendable {
    let duration: CMTime
    let durationString: String // Formatted as "HH:MM:SS"
    let resolution: CGSize
    let frameRate: Float
    let codec: String
    let fileSize: Int64
    let isCompatible: Bool
    let warnings: [String]
    let thumbnail: NSImage?

    var hasWarnings: Bool { !warnings.isEmpty }
    var isLargeFile: Bool { fileSize > 2_000_000_000 } // > 2GB

    var resolutionString: String {
        "\(Int(resolution.width)) × \(Int(resolution.height))"
    }

    var fileSizeString: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
}
```

### NSDocumentController Setup

**In AppDelegate.applicationDidFinishLaunching:**

```swift
// Enable document controller for recent files
let documentController = NSDocumentController.shared
documentController.sharedDocumentController = true
```

**App-wide file opening:**

```swift
// In AppDelegate
func application(_ sender: NSApplication, openFile filename: String) -> Bool {
    let url = URL(fileURLWithPath: filename)

    // Validate it's a video file
    guard VideoValidator.isSupportedFormat(url: url) else {
        showUnsupportedFormatError(url)
        return false
    }

    // Trigger import flow
    Task { @MainActor in
        await self.windowManager?.importVideo(from: url)
    }

    return true
}
```

### WindowManager Updates

**New method:**

```swift
/// Imports a video file and loads it into the editor
/// - Parameter url: URL of video file to import
func importVideo(from url: URL) async {
    // Validate video
    let result = VideoValidator.validate(url: url)

    switch result {
    case .success(let metadata):
        // Show metadata and confirm
        await showImportConfirmation(url: url, metadata: metadata)

    case .failure(let error):
        // Show error to user
        let window = NSApp.windows.first { $0.canBecomeMain }
        if let window = window {
            errorPresenter.presentCritical(error, from: window)
        }
    }
}

private func showImportConfirmation(url: URL, metadata: VideoMetadata) async {
    // Show confirmation dialog with metadata
    // On confirm: load video into editor

    let alert = NSAlert()
    alert.messageText = "Import Video?"
    alert.informativeText = """
    Duration: \(metadata.durationString)
    Resolution: \(metadata.resolutionString)
    File Size: \(metadata.fileSizeString)

    Would you like to import this video into the editor?
    """

    if metadata.hasWarnings {
        alert.informativeText += "\n\nWarnings:\n" + metadata.warnings.joined(separator: "\n")
    }

    alert.alertStyle = .informational
    alert.addButton(withTitle: "Import")
    alert.addButton(withTitle: "Cancel")

    let window = NSApp.windows.first { $0.canBecomeMain }
    guard let window = window else { return }

    let response = await alert.beginSheetModal(for: window)

    if response == .alertFirstButtonReturn {
        // User confirmed import
        loadVideoIntoEditor(url: url)
    }
}

private func loadVideoIntoEditor(url: URL) {
    // Transition to editing state
    transition(to: .editing)

    // Create editor window with video URL
    let editor = EditorWindowController(recordingURL: url)
    editor.showWindow(nil)

    // Add to recent files
    NSDocumentController.shared.noteNewRecentDocumentURL(url)
}
```

**Update showSourceSelector():**

Update the existing switch statement in showSourceSelector() to handle .videoFile:

```swift
sourceSelector.presentAsSheet(on: window) { [weak self] selection in
    guard let self = self else { return }

    switch selection {
    case .screen(let displayID, let displayName):
        print("✅ Selected display: \(displayName) (ID: \(displayID))")
        // ... existing recording logic ...

    case .videoFile(let url):
        print("✅ Selected video file: \(url.path)")
        // Validate and load video
        Task { @MainActor in
            await self.importVideo(from: url)
        }

    case .window, .webcam:
        // These will be implemented in future phases
        print("ℹ️ Source type not yet implemented: \(selection)")
    }
} onCancelled: { [weak self] in
    print("ℹ️ Source selector cancelled")
    self?.transition(to: .idle)
}
```

## Error Handling

### Validation Errors

**File Not Found:**
- Message: "File Not Found"
- Informative: "The file at {filename} could not be found."
- Action: Clear selection, refresh recent files list

**Unsupported Format:**
- Message: "Unsupported Format"
- Informative: "The file format {extension} is not supported by AVFoundation."
- Supported formats: MP4, MOV, MKV, AVI, and other formats AVFoundation can open
- Action: Return to import selection

**Corrupted File:**
- Message: "Corrupted Video"
- Informative: "This video file appears to be corrupted and cannot be opened."
- Action: Clear selection, suggest trying another file

**Too Large (>2GB):**
- Message: "Large File Warning"
- Informative: "This file is {X.X} GB. Importing may take a while. Continue?"
- Action: Allow user to continue or cancel

**No Video Track:**
- Message: "No Video Found"
- Informative: "This file does not contain a video track."
- Action: Suggest selecting a different file

### Codec Warnings

Display warnings but allow import:

**Non-Standard Codec:**
- "This video uses the {codec} codec. Editing performance may be affected."

**Variable Frame Rate:**
- "This video has a variable frame rate. Playback may not be smooth."

**High Resolution (>4K):**
- "This video has a resolution higher than 4K. Performance may be reduced on this system."

### Import Confirmation Dialog

Show metadata dialog before final import:

```
┌─────────────────────────────────────────┐
│ Import Video?                           │
├─────────────────────────────────────────┤
│ Duration: 00:05:30                      │
│ Resolution: 1920 × 1080                 │
│ Size: 125 MB                            │
│                                         │
│ Warnings:                               │
│ • Variable frame rate detected          │
│                                         │
│        [Import] [Cancel]                │
└─────────────────────────────────────────┘
```

## Testing Strategy

### Unit Tests

**1. VideoValidatorTests**
- `testValidateValidVideoFile()` - Confirm valid video passes validation
- `testValidateCorruptedFile()` - Confirm corrupted file error
- `testValidateUnsupportedFormat()` - Confirm unsupported format error
- `testExtractMetadata()` - Verify metadata extraction accuracy
- `testDurationFormatting()` - Check duration string formatting
- `testResolutionExtraction()` - Verify resolution extraction
- `testCodecDetection()` - Confirm codec identification
- `testFileSizeWarning()` - Test large file warning
- `testGetThumbnail()` - Verify thumbnail generation
- `testIsSupportedFormat()` - Check format detection

**2. VideoMetadataTests**
- `testResolutionString()` - Test resolution formatting
- `testFileSizeString()` - Test file size formatting
- `testHasWarnings()` - Test warnings detection
- `testIsLargeFile()` - Test large file detection

**3. VideoImportViewControllerTests**
- `testLoadRecentFiles()` - Verify recent files loading
- `testRecentFilesLimit()` - Confirm max 10 recent files
- `testBrowseButtonOpensPanel()` - Verify NSOpenPanel presentation
- `testShowImportConfirmation()` - Test confirmation dialog
- `testHandleValidationError()` - Test error display
- `testDisplayMetadata()` - Test metadata panel creation
- `testSelectVideoCallsCallback()` - Verify callback invocation

### Integration Tests

**4. VideoImportIntegrationTests**
- `testImportFlowToEditor()` - Full import flow validation
- `testRecentFilesPersistence()` - Verify recent files persist
- `testDragDropImport()` - Test drag-drop file import
- `testStateTransitionToEditing()` - Verify .sourceSelector → .editing
- `testEditorReceivesCorrectURL()` - Confirm EditorWindowController URL
- `testTimelinePopulatedWithVideo()` - Verify video loads into timeline
- `testNSDocumentControllerIntegration()` - Test system-level recent files
- `testFileOpenURL()` - Test app.openURL(_:) handling

### Manual Testing Checklist

**Basic Functionality:**
- [ ] Import tab shows recent files on launch
- [ ] Recent files list updates after importing
- [ ] Recent files persist across app restarts
- [ ] "Browse Files" button opens NSOpenPanel
- [ ] File type filter works (*.mp4, *.mov, *.mkv, etc.)
- [ ] Can select file from browser

**Validation & Metadata:**
- [ ] Selecting file shows metadata dialog
- [ ] Metadata displays correctly (duration, resolution, size)
- [ ] Import confirmation dialog works
- [ ] Cancel button returns to import selection
- [ ] Import button loads video into editor

**Editor Integration:**
- [ ] After import, editor window opens
- [ ] Video loads into timeline
- [ ] Can play imported video
- [ ] Timeline shows correct duration
- [ ] Video preview works

**Drag-Drop:**
- [ ] Drag file onto app window works
- [ ] Drag file onto app icon in Dock works
- [ ] Drag onto import tab works
- [ ] Invalid files rejected with error

**Recent Files (System-Level):**
- [ ] Recent files appear in File → Open Recent menu
- [ ] Can open recent files from menu
- [ ] Clear recent files works
- [ ] Recent files sync with import tab

**Error Handling:**
- [ ] Validation errors show appropriate messages
- [ ] Large file warning appears (>2GB)
- [ ] Corrupted file shows error message
- [ ] Unsupported format shows error message
- [ ] File not found handled gracefully

**Edge Cases:**
- [ ] Import same file twice (shows in recent files)
- [ ] Import very long video (>2 hours)
- [ ] Import 4K+ resolution video
- [ ] Import video with variable frame rate
- [ ] Import with no audio track
- [ ] Import non-video file (image, audio-only)

### Performance Considerations

- **Thumbnail Generation**: Async and cached to avoid blocking UI
- **Validation**: Should not block UI (use Task/await)
- **Large Videos**: Should not cause UI freeze during metadata extraction
- **Recent Files**: Load quickly from NSDocumentController
- **Memory**: Thumbnail cache limited to 50MB

## Implementation Notes

### File Structure

**Files to Create:**
```
Sources/native-macos/SourceSelector/
├── VideoImportViewController.swift (update from placeholder)
├── Models/
│   └── VideoMetadata.swift (new)
└── Utils/
    └── VideoValidator.swift (new)

Tests/OpenScreenTests/SourceSelectorTests/
├── VideoImportViewControllerTests.swift (new)
├── VideoValidatorTests.swift (new)
└── Models/
    └── VideoMetadataTests.swift (new)

Tests/OpenScreenTests/IntegrationTests/
└── VideoImportIntegrationTests.swift (new)
```

**Files to Modify:**
```
Sources/native-macos/SourceSelector/Models/SourceSelection.swift
    - Uncomment `case videoFile(url: URL)`

Sources/native-macos/App/AppDelegate.swift
    - Add NSDocumentController setup
    - Add application(_:openFile:) method
    - Register document types programmatically

Sources/native-macos/App/WindowManager.swift
    - Add importVideo(from:) method
    - Update showSourceSelector() to handle .videoFile case
```

### NSOpenPanel Configuration

```swift
let panel = NSOpenPanel()
panel.allowedContentTypes = [
    .movie,
    .mpeg4Movie,
    .quickTimeMovie,
    .audiovisualContent,
    UTType(filenameExtension: "mkv")
]
panel.allowsMultipleSelection = false
panel.canChooseFiles = true
panel.canChooseDirectories = false
panel.prompt = "Import"
panel.title = "Select Video to Import"
panel.message = "Choose a video file to import into the editor"

let response = await panel.beginSheetModal(for: view.window!)

if response == .OK, let url = panel.url {
    selectVideo(at: url)
}
```

### Recent Files Management

**Load Recent Files:**
```swift
private func loadRecentFiles() {
    let documentController = NSDocumentController.shared
    let recentURLs = documentController.recentDocumentURLs.prefix(10)

    recentFilesURLs = Array(recentURLs).filter { url in
        VideoValidator.isSupportedFormat(url: url)
    }

    refreshRecentFilesList()
}
```

**Add to Recent Files:**
```swift
private func addToRecentFiles(url: URL) {
    let documentController = NSDocumentController.shared
    documentController.noteNewRecentDocumentURL(url)
}
```

### Thumbnail Generation

**Async Thumbnail Generation:**
```swift
func generateThumbnails() async {
    await withTaskGroup(of: (URL, NSImage?).self) { group in
        for url in recentFilesURLs {
            group.addTask {
                do {
                    let thumbnail = try await VideoValidator.getThumbnail(
                        url: url,
                        maxDimension: 160
                    )
                    return (url, thumbnail)
                } catch {
                    return (url, nil)
                }
            }
        }

        for await (url, thumbnail) in group {
            if let thumbnail = thumbnail {
                thumbnailCache[url] = thumbnail
            }
        }
    }

    // Update UI on main actor
    refreshRecentFilesList()
}
```

**Thumbnail Cache Location:**
- `~/Library/Caches/com.openscreen.native/thumbnails/`
- Cache key: URL's lastPathComponent + file modification date hash
- Cache size limit: 50MB
- Cleanup: Remove oldest thumbnails when limit exceeded

**Thumbnail Cache Cleanup Implementation:**
```swift
private func cleanupThumbnailCache() {
    let cacheURL = getThumbnailCacheDirectory()
    var totalSize: Int64 = 0
    var fileDates: [(URL, Date)] = []

    guard let enumerator = FileManager.default.enumerator(
        at: cacheURL,
        includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]
    ) else {
        return
    }

    for case let fileURL as URL in enumerator {
        guard let resourceValues = try? fileURL.resourceValues(
            forKeys: [.fileSizeKey, .contentModificationDateKey]
        ),
        let fileSize = resourceValues.fileSize,
        let modificationDate = resourceValues.contentModificationDate else {
            continue
        }

        totalSize += Int64(fileSize)
        fileDates.append((fileURL, modificationDate))
    }

    // Remove oldest files if over limit
    if totalSize > 50_000_000 { // 50MB
        let sortedFiles = fileDates.sorted { $0.1 < $1.1 }
        var sizeToRemove = totalSize - 40_000_000 // Target 40MB

        for (fileURL, _) in sortedFiles {
            if sizeToRemove <= 0 { break }
            if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey])?.fileSize {
                try? FileManager.default.removeItem(at: fileURL)
                sizeToRemove -= Int64(fileSize)
            }
        }
    }
}
```

### App-Wide Drag-Drop

**Programmatic Document Type Registration:**

Since this is a Swift Package Manager project without Info.plist, document types are registered programmatically in AppDelegate:

```swift
// In AppDelegate.applicationDidFinishLaunching
func setupDocumentTypes() {
    // Register document type for video files
    NSApplication.shared.registerDocumentType(
        typeName: "Video File",
        extensions: ["mp4", "mov", "mkv", "avi", "m4v", "mpg", "mpeg"],
        mimeTypes: ["video/mp4", "video/quicktime", "video/x-matroska"],
        icon: nil
    )

    // Enable document controller
    let documentController = NSDocumentController.shared
    documentController.sharedDocumentController = true
}
```

**AppDelegate Methods:**
```swift
func application(_ sender: NSApplication, openFile filename: String) -> Bool {
    let url = URL(fileURLWithPath: filename)
    return handleVideoImport(url: url)
}

func application(_ application: NSApplication, openFiles filenames: [String]) {
    // Handle multiple files (import first one, show warning for others)
    if let firstFile = filenames.first {
        let url = URL(fileURLWithPath: firstFile)
        _ = handleVideoImport(url: url)
    }

    if filenames.count > 1 {
        showMultipleFilesWarning(count: filenames.count)
    }
}
```

### UserDefaults Keys

**Additional Settings (optional):**
```swift
// Remember last import directory
UserDefaults.standard.set(url.deletingLastPathComponent().path, forKey: "lastImportDirectory")

// Thumbnail cache enabled (default: true)
UserDefaults.standard.register(defaults: ["thumbnailCacheEnabled": true])

// Recent files limit (default: 10)
UserDefaults.standard.register(defaults: ["recentFilesLimit": 10])
```

## Dependencies

**Required Frameworks:**
- AVFoundation (already in project)
- AppKit (already in project)
- UniformTypeIdentifiers (for UTType.supportedContentTypes)

**Package Dependencies:**
- None (uses only system frameworks)

## Success Criteria

- [ ] User can import video files via browser
- [ ] User can import video files via drag-drop
- [ ] User can import video files via recent files list
- [ ] Video loads directly into editing timeline
- [ ] Recent files persist across app launches
- [ ] Recent files appear in File → Open Recent menu
- [ ] Video validation works with helpful error messages
- [ ] Metadata display shows correct information
- [ ] Thumbnail generation works for recent files
- [ ] All unit tests pass
- [ ] All integration tests pass
- [ ] Manual testing checklist complete

## Next Steps

After Phase 2 implementation:
- Phase 3: Webcam recording infrastructure
- Phase 4: Window recording feasibility research

## Related Documents

- Phase 1 Design: `/docs/superpowers/specs/2026-03-20-source-selector-design.md`
- Phase 1 Implementation Plan: `/docs/superpowers/plans/2026-03-20-source-selector-phase1.md`
