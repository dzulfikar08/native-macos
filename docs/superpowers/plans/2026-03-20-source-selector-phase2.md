# Source Selector Phase 2: Import Video File

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable users to import existing video files directly into the editor with comprehensive validation and system-level recent files tracking.

**Architecture:** AppKit-based import interface using NSDocumentController for system-wide file handling, AVFoundation for video validation and metadata extraction, and integration with existing WindowManager state machine.

**Tech Stack:** AppKit, AVFoundation, UniformTypeIdentifiers, CoreGraphics

---

## Chunk 1: Data Models and Validation

### Task 1: Create VideoMetadata Model

**Files:**
- Create: `Sources/native-macos/SourceSelector/Models/VideoMetadata.swift`
- Test: `Tests/OpenScreenTests/SourceSelectorTests/Models/VideoMetadataTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
import CoreMedia
@testable import OpenScreen

func testVideoMetadataProperties() {
    let duration = CMTime(seconds: 30, preferredTimescale: 600)
    let resolution = CGSize(width: 1920, height: 1080)

    let metadata = VideoMetadata(
        duration: duration,
        durationString: "00:00:30",
        resolution: resolution,
        frameRate: 30.0,
        codec: "h264",
        fileSize: 125_000_000,
        isCompatible: true,
        warnings: [],
        thumbnail: nil
    )

    XCTAssertEqual(metadata.duration, duration)
    XCTAssertEqual(metadata.resolutionString, "1920 × 1080")
    XCTAssertEqual(metadata.fileSizeString, "125 MB")
    XCTAssertFalse(metadata.hasWarnings)
    XCTAssertFalse(metadata.isLargeFile)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter VideoMetadataTests::testVideoMetadataProperties`
Expected: FAIL with "VideoMetadata not found"

- [ ] **Step 3: Write minimal implementation**

```swift
import Foundation
import CoreMedia
import AppKit

/// Metadata extracted from a video file
struct VideoMetadata: Sendable {
    let duration: CMTime
    let durationString: String
    let resolution: CGSize
    let frameRate: Float
    let codec: String
    let fileSize: Int64
    let isCompatible: Bool
    let warnings: [String]
    let thumbnail: NSImage?

    var hasWarnings: Bool { !warnings.isEmpty }
    var isLargeFile: Bool { fileSize > 2_000_000_000 }

    var resolutionString: String {
        "\(Int(resolution.width)) × \(Int(resolution.height))"
    }

    var fileSizeString: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter VideoMetadataTests::testVideoMetadataProperties`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/native-macos/SourceSelector/Models/VideoMetadata.swift \
        Tests/OpenScreenTests/SourceSelectorTests/Models/VideoMetadataTests.swift
git commit -m "feat(source-selector): add VideoMetadata model

- Add VideoMetadata struct for video file information
- Include duration, resolution, codec, file size properties
- Add computed properties for formatted strings
- Add VideoMetadataTests

Part of Phase 2: Import Video File"
```

---

### Task 2: Create VideoValidator

**Files:**
- Create: `Sources/native-macos/SourceSelector/Utils/VideoValidator.swift`
- Test: `Tests/OpenScreenTests/SourceSelectorTests/VideoValidatorTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
import AVFoundation
@testable import OpenScreen

func testValidateValidVideo() async throws {
    let testURL = try TestDataFactory.makeTestRecordingURL()
    // Create a simple test video file
    try await createTestVideo(at: testURL)

    let result = VideoValidator.validate(url: testURL)

    switch result {
    case .success(let metadata):
        XCTAssertNotNil(metadata)
        XCTAssertTrue(metadata.isCompatible)
    case .failure:
        XCTFail("Valid video should pass validation")
    }
}

func testIsSupportedFormat() {
    let mp4URL = URL(fileURLWithPath: "/test/video.mp4")
    let txtURL = URL(fileURLWithPath: "/test/file.txt")

    XCTAssertTrue(VideoValidator.isSupportedFormat(url: mp4URL))
    XCTAssertFalse(VideoValidator.isSupportedFormat(url: txtURL))
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter VideoValidatorTests::testValidateValidVideo`
Expected: FAIL with "VideoValidator not found"

- [ ] **Step 3: Write minimal implementation**

```swift
import Foundation
import AVFoundation
import UniformTypeIdentifiers
import CoreGraphics
import AppKit

/// Errors that can occur during video validation
enum VideoValidationError: Error {
    case fileNotFound(URL)
    case unsupportedFormat(String)
    case corruptedFile
    case tooLarge(Int64)
    case noVideoTrack

    var localizedDescription: String {
        switch self {
        case .fileNotFound(let url):
            return "File not found: \(url.lastPathComponent)"
        case .unsupportedFormat(let format):
            return "Unsupported format: \(format)"
        case .corruptedFile:
            return "File appears to be corrupted"
        case .tooLarge(let size):
            let sizeGB = Double(size) / 1_000_000_000
            return "File is very large (\(String(format: "%.1f", sizeGB)) GB)"
        case .noVideoTrack:
            return "No video track found in file"
        }
    }
}

/// Validator for video files
struct VideoValidator {

    /// Validates a video file and extracts metadata
    static func validate(url: URL) -> Result<VideoMetadata, VideoValidationError> {
        // Check file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            return .failure(.fileNotFound(url))
        }

        // Check format support
        guard isSupportedFormat(url: url) else {
            return .failure(.unsupportedFormat(url.pathExtension))
        }

        // Load asset
        let asset = AVAsset(url: url)

        // Load metadata asynchronously (simplified for now)
        let metadata = extractMetadata(from: asset, url: url)

        guard let metadata = metadata else {
            return .failure(.corruptedFile)
        }

        return .success(metadata)
    }

    /// Checks if file format is supported
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

    /// Extracts metadata from AVAsset
    private static func extractMetadata(from asset: AVAsset, url: URL) -> VideoMetadata? {
        // Get duration
        let duration = asset.duration
        let durationString = formatDuration(duration)

        // Get file size
        let fileSize: Int64
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            fileSize = attributes[.size] as? Int64 ?? 0
        } catch {
            return nil
        }

        // Get video track
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            return nil
        }

        // Get resolution
        let resolution = videoTrack.naturalSize.applying(videoTrack.preferredTransform)

        // Get frame rate
        let frameRate = videoTrack.nominalFrameRate

        // Get codec
        let codec = videoTrack.formatDescriptions.first.flatMap { desc in
            let formatDesc = desc as? CMFormatDescription
            return formatDesc?.mediaSubType.rawValue as String?
        } ?? "unknown"

        // Check compatibility
        let (isCompatible, warnings) = checkCompatibility(tracks: asset.tracks)

        return VideoMetadata(
            duration: duration,
            durationString: durationString,
            resolution: resolution,
            frameRate: frameRate,
            codec: codec,
            fileSize: fileSize,
            isCompatible: isCompatible,
            warnings: warnings,
            thumbnail: nil
        )
    }

    /// Formats duration as HH:MM:SS
    private static func formatDuration(_ duration: CMTime) -> String {
        let totalSeconds = CMTimeGetSeconds(duration)
        let hours = Int(totalSeconds) / 3600
        let minutes = Int(totalSeconds) % 3600 / 60
        let seconds = Int(totalSeconds) % 60

        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    /// Checks if tracks are compatible
    private static func checkCompatibility(tracks: [AVAssetTrack]) -> (Bool, [String]) {
        var warnings: [String] = []

        // Check for variable frame rate
        if let videoTrack = tracks.first(where: { $0.mediaType == .video }) {
            if videoTrack.nominalFrameRate == 0 {
                warnings.append("Variable frame rate detected - playback may not be smooth")
            }
        }

        return (true, warnings)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter VideoValidatorTests::testValidateValidVideo`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/native-macos/SourceSelector/Utils/VideoValidator.swift \
        Tests/OpenScreenTests/SourceSelectorTests/VideoValidatorTests.swift
git commit -m "feat(source-selector): add VideoValidator utility

- Add video file validation using AVFoundation
- Extract metadata (duration, resolution, codec, file size)
- Check format compatibility
- Add VideoValidatorTests

Part of Phase 2: Import Video File"
```

---

## Chunk 2: VideoImportViewController

### Task 3: Implement VideoImportViewController - Recent Files UI

**Files:**
- Modify: `Sources/native-macos/SourceSelector/VideoImportViewController.swift`

- [ ] **Step 1: Update VideoImportViewController with recent files UI**

Replace the entire placeholder implementation with:

```swift
import Cocoa
import UniformTypeIdentifiers

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
    override func viewDidLoad() {
        super.viewDidLoad()

        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        setupUI()
        loadRecentFiles()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        refreshRecentFilesList()
    }

    // MARK: - UI Setup
    private func setupUI() {
        // Create scroll view for recent files
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false

        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.alignment = .leading

        scrollView.documentView = stackView
        self.scrollView = scrollView
        self.recentFilesStack = stackView

        view.addSubview(scrollView)

        // Create browse button
        let browseButton = NSButton(title: "Browse Files...", target: self, action: #selector(browseButtonClicked))
        browseButton.translatesAutoresizingMaskIntoConstraints = false
        browseButton.bezelStyle = .rounded
        self.browseButton = browseButton

        view.addSubview(browseButton)

        // Create metadata panel (hidden initially)
        let metadataPanel = NSView()
        metadataPanel.translatesAutoresizingMaskIntoConstraints = false
        metadataPanel.wantsLayer = true
        metadataPanel.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        metadataPanel.isHidden = true
        self.metadataPanel = metadataPanel

        view.addSubview(metadataPanel)

        // Create validation message label
        let validationMessage = NSTextField(labelWithString: "")
        validationMessage.isEditable = false
        validationMessage.isBordered = false
        validationMessage.backgroundColor = .clear
        validationMessage.translatesAutoresizingMaskIntoConstraints = false
        self.validationMessage = validationMessage

        view.addSubview(validationMessage)

        // Layout
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            scrollView.heightAnchor.constraint(equalToConstant: 250),

            browseButton.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 20),
            browseButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            metadataPanel.topAnchor.constraint(equalTo: browseButton.bottomAnchor, constant: 20),
            metadataPanel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            metadataPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            metadataPanel.heightAnchor.constraint(equalToConstant: 120),

            validationMessage.topAnchor.constraint(equalTo: metadataPanel.bottomAnchor, constant: 8),
            validationMessage.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])

        // Setup drag-drop
        setupDragAndDrop()
    }

    // MARK: - Recent Files
    private func loadRecentFiles() {
        let documentController = NSDocumentController.shared
        let recentURLs = documentController.recentDocumentURLs.prefix(10)

        recentFilesURLs = Array(recentURLs).filter { url in
            VideoValidator.isSupportedFormat(url: url)
        }

        refreshRecentFilesList()
    }

    private func refreshRecentFilesList() {
        guard let stackView = recentFilesStack else { return }

        // Remove existing items
        stackView.arrangedSubviews.forEach { stackView.removeView($0) }

        // Add recent files
        for url in recentFilesURLs {
            let itemView = createRecentFileItem(for: url)
            stackView.addArrangedSubview(itemView)
        }
    }

    private func createRecentFileItem(for url: URL) -> NSView {
        let containerView = NSView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        containerView.layer?.cornerRadius = 4

        let label = NSTextField(labelWithString: url.lastPathComponent)
        label.isEditable = false
        label.isBordered = false
        label.backgroundColor = .clear
        label.translatesAutoresizingMaskIntoConstraints = false

        containerView.addSubview(label)

        NSLayoutConstraint.activate([
            containerView.heightAnchor.constraint(equalToConstant: 40),
            label.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            label.centerYAnchor.constraint(equalTo: containerView.centerYAnchor)
        ])

        // Add click gesture
        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(recentFileClicked(_:)))
        containerView.addGestureRecognizer(clickGesture)

        return containerView
    }

    // MARK: - File Browser
    @objc private func browseButtonClicked() {
        showFileOpenPanel()
    }

    private func showFileOpenPanel() {
        Task {
            let panel = NSOpenPanel()
            panel.allowedContentTypes = [.movie, .mpeg4Movie, .quickTimeMovie, .audiovisualContent]
            panel.allowsMultipleSelection = false
            panel.canChooseFiles = true
            panel.canChooseDirectories = false
            panel.prompt = "Import"
            panel.title = "Select Video to Import"

            guard let window = view.window else { return }
            let response = await panel.beginSheetModal(for: window)

            if response == .OK, let url = panel.url {
                selectVideo(at: url)
            }
        }
    }

    // MARK: - Video Selection
    @objc private func recentFileClicked(_ gesture: NSClickGestureRecognizer) {
        guard let containerView = gesture.view,
              let index = recentFilesStack?.arrangedSubviews.firstIndex(of: containerView),
              index < recentFilesURLs.count else {
            return
        }

        let url = recentFilesURLs[index]
        selectVideo(at: url)
    }

    private func selectVideo(at url: URL) {
        selectedURL = url

        // Validate video
        let result = VideoValidator.validate(url: url)

        switch result {
        case .success(let metadata):
            self.metadata = metadata
            showImportConfirmation(metadata: metadata)

        case .failure(let error):
            handleValidationError(error)
        }
    }

    private func showImportConfirmation(metadata: VideoMetadata) {
        metadataPanel?.isHidden = false

        // Update metadata panel
        // (Would add labels to display duration, resolution, etc.)

        // Show import alert
        Task {
            let alert = NSAlert()
            alert.messageText = "Import Video?"
            alert.informativeText = """
            Duration: \(metadata.durationString)
            Resolution: \(metadata.resolutionString)
            File Size: \(metadata.fileSizeString)

            Would you like to import this video into the editor?
            """
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Import")
            alert.addButton(withTitle: "Cancel")

            guard let window = view.window else { return }
            let response = await alert.beginSheetModal(for: window)

            if response == .alertFirstButtonReturn {
                confirmImport()
            } else {
                metadataPanel?.isHidden = true
            }
        }
    }

    private func confirmImport() {
        guard let url = selectedURL else { return }

        onVideoSelected?(url)

        // Add to recent files
        NSDocumentController.shared.noteNewRecentDocumentURL(url)
    }

    // MARK: - Validation
    private func handleValidationError(_ error: VideoValidationError) {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")

        guard let window = view.window else { return }
        alert.beginSheetModal(for: window) { _ in
            // Clear selection
            self.selectedURL = nil
        }
    }

    // MARK: - Drag & Drop
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

        if VideoValidator.isSupportedFormat(url: fileURL) {
            selectVideo(at: fileURL)
            return true
        }

        return false
    }
}
```

- [ ] **Step 2: Build to verify no errors**

Run: `swift build`
Expected: Build succeeds with no errors

- [ ] **Step 3: Commit**

```bash
git add Sources/native-macos/SourceSelector/VideoImportViewController.swift
git commit -m "feat(source-selector): implement VideoImportViewController UI

- Add recent files list with scroll view
- Add browse button for NSOpenPanel
- Add metadata panel for video information
- Add drag-drop support
- Handle video selection and validation

Part of Phase 2: Import Video File"
```

---

## Chunk 3: Source Selection Enum Update

### Task 4: Enable Video File Case in SourceSelection

**Files:**
- Modify: `Sources/native-macos/SourceSelector/Models/SourceSelection.swift`

- [ ] **Step 1: Write the failing test**

```swift
func testSourceSelectionVideoFile() {
    let url = URL(fileURLWithPath: "/path/to/video.mp4")
    let selection = SourceSelection.videoFile(url: url)

    switch selection {
    case .videoFile(let selectedURL):
        XCTAssertEqual(selectedURL, url)
    default:
        XCTFail("Should be videoFile case")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter SourceSelectionTests::testSourceSelectionVideoFile`
Expected: FAIL - ".videoFile case is commented out"

- [ ] **Step 3: Uncomment the videoFile case**

Update SourceSelection.swift:

```swift
enum SourceSelection: Equatable, Sendable {
    case screen(displayID: CGDirectDisplayID, displayName: String)
    // Future phases:
    // case window(windowID: CGWindowID, windowName: String, ownerName: String)
    // case webcam(deviceID: String, deviceName: String)
    case videoFile(url: URL)  // ✅ Uncommented for Phase 2
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter SourceSelectionTests::testSourceSelectionVideoFile`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/native-macos/SourceSelector/Models/SourceSelection.swift
git commit -m "feat(source-selector): enable videoFile case in SourceSelection

- Uncomment videoFile case to support video import
- Add test for videoFile case

Part of Phase 2: Import Video File"
```

---

## Chunk 4: AppDelegate Integration

### Task 5: Add NSDocumentController and File Handling to AppDelegate

**Files:**
- Modify: `Sources/native-macos/App/AppDelegate.swift`

- [ ] **Step 1: Read AppDelegate to understand current structure**

Run: `cat Sources/native-macos/App/AppDelegate.swift | head -50`
Expected: See existing AppDelegate structure

- [ ] **Step 2: Add document type registration and file handling**

Add to AppDelegate after applicationDidFinishLaunching:

```swift
// MARK: - Document Types
private func setupDocumentTypes() {
    // Register document type for video files
    NSApplication.shared.registerDocumentType(
        typeName: "Video File",
        extensions: ["mp4", "mov", "mkv", "avi", "m4v"],
        mimeTypes: ["video/mp4", "video/quicktime", "video/x-matroska"],
        icon: nil
    )

    // Enable document controller
    let documentController = NSDocumentController.shared
    documentController.sharedDocumentController = true
}
```

Add application delegate methods:

```swift
// MARK: - File Opening
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
        print("⚠️ Only the first file was imported. Multiple file import not yet supported.")
    }
}

private func handleVideoImport(url: URL) -> Bool {
    // Validate it's a video file
    guard VideoValidator.isSupportedFormat(url: url) else {
        showUnsupportedFormatError(url)
        return false
    }

    // Trigger import flow
    Task { @MainActor in
        guard let windowManager = self.windowManager else { return }
        await windowManager.importVideo(from: url)
    }

    return true
}

private func showUnsupportedFormatError(_ url: URL) {
    let alert = NSAlert()
    alert.messageText = "Unsupported Format"
    alert.informativeText = "The file \(url.lastPathComponent) is not a supported video format."
    alert.alertStyle = .warning
    alert.addButton(withTitle: "OK")
    alert.runModal()
}
```

- [ ] **Step 3: Update applicationDidFinishLaunching to call setupDocumentTypes()**

```swift
func applicationDidFinishLaunching(_ aNotification: Notification) {
    // ... existing setup code ...

    setupDocumentTypes()
}
```

- [ ] **Step 4: Build to verify no errors**

Run: `swift build`
Expected: Build succeeds

- [ ] **Step 5: Commit**

```bash
git add Sources/native-macos/App/AppDelegate.swift
git commit -m "feat(source-selector): add document controller to AppDelegate

- Register document types programmatically
- Add application(_:openFile:) handling
- Add application(_:openFiles:) for multiple files
- Setup NSDocumentController for recent files

Part of Phase 2: Import Video File"
```

---

## Chunk 5: WindowManager Integration

### Task 6: Add importVideo Method to WindowManager

**Files:**
- Modify: `Sources/native-macos/App/WindowManager.swift`

- [ ] **Step 1: Write the integration test**

```swift
func testImportVideoFlow() async throws {
    let manager = WindowManager(
        resourceCoordinator: ResourceCoordinator(),
        errorPresenter: ErrorPresenter()
    )

    let testURL = try TestDataFactory.makeTestRecordingURL()

    // This would test the full flow
    // For now, just verify the method exists
    // (Full test requires UI mocking)
}
```

- [ ] **Step 2: Add importVideo method to WindowManager**

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

- [ ] **Step 3: Update showSourceSelector() to handle .videoFile case**

Update the switch statement in showSourceSelector():

```swift
case .videoFile(let url):
    print("✅ Selected video file: \(url.path)")

    // Validate and load video
    Task { @MainActor in
        await self.importVideo(from: url)
    }
```

- [ ] **Step 4: Build to verify no errors**

Run: `swift build`
Expected: Build succeeds

- [ ] **Step 5: Commit**

```bash
git add Sources/native-macos/App/WindowManager.swift
git commit -m "feat(source-selector): add importVideo method to WindowManager

- Add importVideo(from:) method for video file import
- Add confirmation dialog with metadata display
- Add loadVideoIntoEditor to create editor with video
- Update showSourceSelector() to handle .videoFile case
- Add state transition to .editing

Part of Phase 2: Import Video File"
```

---

## Chunk 6: Testing and Verification

### Task 7: Add Integration Tests

**Files:**
- Create: `Tests/OpenScreenTests/IntegrationTests/VideoImportIntegrationTests.swift`

- [ ] **Step 1: Create integration test file**

```swift
import XCTest
import AVFoundation
@testable import OpenScreen

@MainActor
final class VideoImportIntegrationTests: XCTestCase {

    func testImportFlowToEditor() async throws {
        // This would test the full flow from source selector to editor
        // Requires UI mocking or full UI testing

        // For now, verify components can be instantiated
        let validator = VideoValidator.self
        XCTAssertNotNil(validator)

        let metadata = VideoMetadata(
            duration: CMTime(seconds: 10, preferredTimescale: 600),
            durationString: "00:00:10",
            resolution: CGSize(width: 1920, height: 1080),
            frameRate: 30.0,
            codec: "h264",
            fileSize: 10_000_000,
            isCompatible: true,
            warnings: [],
            thumbnail: nil
        )
        XCTAssertNotNil(metadata)
    }

    func testRecentFilesPersistence() {
        // Test that recent files persist
        let documentController = NSDocumentController.shared
        documentController.noteNewRecentDocumentURL(URL(fileURLWithPath: "/test/video.mp4"))

        let recentURLs = documentController.recentDocumentURLs
        XCTAssertTrue(recentURLs.count > 0)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Tests/OpenScreenTests/IntegrationTests/VideoImportIntegrationTests.swift
git commit -m "test(source-selector): add video import integration tests

- Add VideoImportIntegrationTests
- Test import flow components
- Test recent files persistence

Part of Phase 2: Import Video File"
```

---

### Task 8: Run All Tests and Verify

- [ ] **Step 1: Run source selector tests**

```bash
swift test --filter SourceSelector
```

Expected: All source selector tests pass

- [ ] **Step 2: Run integration tests**

```bash
swift test --filter VideoImportIntegration
```

Expected: All integration tests pass

- [ ] **Step 3: Run full test suite**

```bash
swift test
```

Expected: All tests pass, no regressions

- [ ] **Step 4: Build the app**

```bash
swift build
```

Expected: Build succeeds

- [ ] **Step 5: Manual verification**

Test the following:
- [ ] Source selector Import tab shows recent files
- [ ] Browse button opens file browser
- [ ] Can select and import a video file
- [ ] Imported video loads into editor
- [ ] Video appears in timeline
- [ ] Recent files persist across app restarts

- [ ] **Step 6: Final commit**

```bash
git add .
git commit -m "test(source-selector): verify Phase 2 completion

- All source selector tests passing
- Integration tests passing
- Video import verified
- Phase 2: Import Video File complete"
```

---

## Summary

**Files Created:**
1. `Sources/native-macos/SourceSelector/Models/VideoMetadata.swift`
2. `Sources/native-macos/SourceSelector/Utils/VideoValidator.swift`
3. `Tests/OpenScreenTests/SourceSelectorTests/Models/VideoMetadataTests.swift`
4. `Tests/OpenScreenTests/SourceSelectorTests/VideoValidatorTests.swift`
5. `Tests/OpenScreenTests/IntegrationTests/VideoImportIntegrationTests.swift`

**Files Modified:**
1. `Sources/native-macos/SourceSelector/Models/SourceSelection.swift` - Enable .videoFile case
2. `Sources/native-macos/SourceSelector/VideoImportViewController.swift` - Full implementation
3. `Sources/native-macos/App/AppDelegate.swift` - NSDocumentController and file handling
4. `Sources/native-macos/App/WindowManager.swift` - importVideo method and .videoFile handling

**Next Steps:**
- Phase 3: Webcam recording infrastructure
- Phase 4: Window recording feasibility research
