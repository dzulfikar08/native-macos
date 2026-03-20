# Source Selector Phase 3: Webcam Recording Design

**Author:** Claude
**Date:** 2026-03-20
**Status:** Draft

## Overview

Implement webcam recording with multi-camera support, audio mixing, and picture-in-picture compositing. Users can select up to 4 cameras, configure quality settings independently, control audio mixing (system + microphone) with per-source volume/mute controls, and choose from multiple codec options.

**Key Features:**
- Multi-camera capture (1-4 cameras simultaneously)
- Picture-in-picture compositing layouts
- Dual audio capture (system audio + microphone) with mixing controls
- Manual quality controls (resolution, frame rate, bitrate)
- User-selectable codecs (H.264, HEVC, ProRes presets)
- Live camera previews during selection
- Mini-view overlay during recording

**Success Criteria:**
- User can select and record from 1-4 webcams
- Live preview shows all selected cameras in PIP layout
- Recording includes synchronized audio from both system and microphone
- User has full control over quality settings and codec selection
- Mini-view shows live feed during recording with stop controls

## Architecture

### Protocol-Based Pluggable System

```
RecordingController
    ↓ (uses)
Recorder Protocol
    ↑ (implemented by)
    ├── ScreenRecorder (existing)
    └── WebcamRecorder (new)
        ├── AVCaptureSession (multi-camera)
        ├── AudioMixer (system + mic)
        ├── PipCompositor (video layout)
        └── AVAssetWriter (output)
```

**Design Rationale:**
- Clean separation of concerns - RecordingController coordinates, recorders implement
- Each recorder uses optimal API (CGScreenCapture vs AVCaptureSession)
- Easy to extend for future recorder types (WindowRecorder, etc.)
- Testable - can inject mock recorders
- Multi-camera complexity isolated in WebcamRecorder

### Threading Model

- **UI Thread (@MainActor):** WebcamSourceViewController, all UI updates
- **Session Queue (serial):** AVCaptureSession operations (start/stop, add/remove inputs)
- **Video Queue (dispatch):** AVCaptureVideoDataOutput callbacks, frame processing
- **Audio Queue (dispatch):** Audio capture and mixing
- **Writer Queue (serial):** AVAssetWriter operations

**Callback Flow:**
AVCaptureSession queues → MainActor via @MainActor properties/callbacks

## Components

### 1. Recorder Protocol

**File:** `Sources/native-macos/Recording/Recorder.swift`

```swift
/// Protocol for recording implementations
protocol Recorder: Sendable {
    /// Configuration type for this recorder
    associatedtype Config: Sendable

    /// Start recording to specified URL with given configuration
    func startRecording(to url: URL, config: Config) async throws

    /// Stop current recording and return output URL
    func stopRecording() async throws -> URL

    /// Whether currently recording
    var isRecording: Bool { get }
}
```

**Purpose:** Abstraction layer allowing RecordingController to work with any recorder type

**Type Safety:** Uses associated types instead of `Any?` for configuration - compiler ensures correct config type for each recorder

**Existing Implementation:**
- ScreenRecorder will be updated to conform to this protocol with a `Config` struct containing `displayID: CGDirectDisplayID?`
- Current API is compatible, just needs refactoring to accept config struct

### 2. WebcamRecorder

**File:** `Sources/native-macos/Recording/WebcamRecorder.swift`

**Responsibilities:**
- Manage AVCaptureSession lifecycle
- Configure multiple camera inputs (up to 4)
- Set up audio capture (system + microphone)
- Coordinate PipCompositor for video layout
- Coordinate AudioMixer for audio mixing
- Write output via AVAssetWriter
- Handle codec selection

**Key Properties:**
```swift
@MainActor
final class WebcamRecorder: Recorder {
    private let session: AVCaptureSession
    private let sessionQueue = DispatchQueue(label: "com.openscreen.webcam.session")
    private var videoOutputs: [AVCaptureVideoDataOutput] = []
    private var audioOutput: AVCaptureAudioDataOutput?
    private var writer: AVAssetWriter?
    private var writerInput: AVAssetWriterInput?
    private var audioMixer: AudioMixer
    private var pipCompositor: PipCompositor

    var isRecording: Bool { writer?.status == .writing }
}
```

**Note on @MainActor and Sendable:** The `@MainActor` annotation ensures all properties and methods are accessed from the main thread. This provides thread-safe access to mutable state, making the class conform to `Sendable` without requiring additional synchronization. When a value is passed between concurrency contexts, Swift ensures the @MainActor isolation is preserved.

**Configuration:**
```swift
struct WebcamRecordingConfig: Sendable {
    let cameras: [CameraDevice]
    let compositingMode: PipMode
    let videoSettings: VideoSettings
    let audioSettings: AudioSettings
    let codec: VideoCodec
}
```

**Methods:**
```swift
func startRecording(to url: URL, config: WebcamRecordingConfig) async throws
func stopRecording() async throws -> URL
func updateCompositingMode(_ mode: PipMode)  // During recording
func updateAudioMix(_ mix: AudioMix)         // During recording
```

### 3. CameraDevice Model

**File:** `Sources/native-macos/SourceSelector/Models/CameraDevice.swift`

**Properties:**
```swift
struct CameraDevice: Identifiable, Sendable {
    let id: String  // deviceID
    let name: String
    let position: AVCaptureDevice.Position?
    let supportedFormats: [VideoFormat]
    var thumbnail: NSImage?

    struct VideoFormat: Sendable {
        let resolution: CGSize
        let frameRates: [Float]
        let codec: FourCharCode
    }
}
```

**Methods:**
- `static func enumerateCameras() -> [CameraDevice]` - Uses AVCaptureDevice.DiscoverySession
- `func createCaptureInput() -> AVCaptureDeviceInput?` - Creates AVCaptureDeviceInput

### 4. PipCompositor

**File:** `Sources/native-macos/Recording/PipCompositor.swift`

**Responsibilities:**
- Generate layout for 1-4 cameras
- Compose frames into single CVPixelBuffer
- Handle different PIP modes (single, dual, triple, quad)

**Modes:**
```swift
enum PipMode: Sendable {
    case single                        // Full screen
    case dual(main: Int, overlay: Int)  // Main full, overlay corner
    case triple(main: Int, p2: Int, p3: Int)  // 1 large, 2 small
    case quad                           // 2x2 grid
}
```

**Methods:**
```swift
func composeFrame(
    buffers: [Int: CVPixelBuffer],  // cameraIndex -> buffer
    into outputBuffer: CVPixelBuffer,
    mode: PipMode
) throws
```

**Implementation:**
- Use Core Image (CIContext) for compositing
- Pre-calculate layout rectangles per mode
- Handle aspect ratio scaling
- Apply to output buffer via CIContext.render

### 5. AudioMixer

**File:** `Sources/native-macos/Recording/AudioMixer.swift`

**Responsibilities:**
- Capture system audio (via existing ScreenRecorder mechanisms)
- Capture microphone audio (via AVCaptureAudioDataOutput)
- Mix audio streams with per-source volume control
- Mute/unmute individual sources
- Output mixed audio buffers

**Configuration:**
```swift
struct AudioSettings: Sendable {
    var systemAudioEnabled: Bool = true
    var microphoneEnabled: Bool = true
    var systemVolume: Float = 1.0      // 0.0 - 1.0
    var microphoneVolume: Float = 1.0  // 0.0 - 1.0
}
```

**Methods:**
```swift
func processSystemAudio(_ buffer: AVAudioBuffer)
func processMicrophoneAudio(_ buffer: AVAudioBuffer)
func getMixedBuffer() -> AVAudioBuffer?
func updateSettings(_ settings: AudioSettings)
```

**Implementation:**
- Use AVAudioMixerNode for mixing
- Separate AVAudioEngine nodes for each source
- Volume controls via node.volume
- Mute via node.isMuted

### 6. WebcamRecordingSettings

**File:** `Sources/native-macos/SourceSelector/Models/WebcamRecordingSettings.swift`

**Properties:**
```swift
struct WebcamRecordingSettings: Sendable {
    var selectedCameras: [CameraDevice]
    var compositingMode: PipMode
    var qualityPreset: QualityPreset
    var audioSettings: AudioSettings
    var codec: VideoCodec
}

enum QualityPreset: String, CaseIterable {
    case low      // 480p, 24fps, 2 Mbps
    case medium   // 720p, 30fps, 5 Mbps
    case high     // 1080p, 30fps, 10 Mbps
    case ultra    // 4K, 60fps, 50 Mbps (if camera supports)
    case custom   // Manual controls
}

struct VideoSettings: Sendable {
    var resolution: CGSize?
    var frameRate: Float?
    var bitrate: Int?
}
```

### 7. WebcamSourceViewController

**File:** `Sources/native-macos/SourceSelector/WebcamSourceViewController.swift`

**UI Components:**
- Camera list with thumbnails (240x180) - NSCollectionView
- Favorites dropdown (remembers last used)
- Quality controls - NSPopUpButton for preset, custom controls for manual
- Audio controls - 2x mute buttons + NSSlider for each
- Codec selector - NSPopUpButton (H.264 / HEVC / ProRes 422 / ProRes 4444)
- Start Recording button (enabled when 1+ cameras selected)

**State:**
```swift
@MainActor
private var availableCameras: [CameraDevice] = []
private var selectedCameras: Set<CameraDevice.ID> = []
private var lastUsedCamera: CameraDevice.ID?
private var settings: WebcamRecordingSettings
```

**Actions:**
- Camera selection/deselection toggles
- Quality preset changes
- Audio slider updates
- Codec selection
- Start/Stop recording

**Preview:**
- NSCollectionView items show live camera thumbnails
- Uses AVCaptureVideoPreviewLayer for each selected camera
- Updates at ~15 FPS (sufficient for selection, not full quality)

### 8. Mini-View Overlay

**File:** `Sources/native-macos/Recording/MiniRecordingView.swift`

**Window:** NSPanel (non-activating, floating)

**UI Components:**
- Live camera feed (PipCompositor output)
- Stop Recording button
- Recording time indicator
- Close button (confirms stop first)

**Behavior:**
- Appears when recording starts
- Shows live composited output
- User can drag to reposition
- Remembers position between recordings
- Closes when recording stops

## Data Flow

### Selection Flow

```
User opens Webcam tab
    ↓
WebcamSourceViewController.viewDidLoad()
    ↓
CameraDevice.enumerateCameras()
    ↓
Show camera list with thumbnails
    ↓
User selects 1-4 cameras
    ↓
User configures quality, audio, codec
    ↓
User clicks "Start Recording"
    ↓
SourceSelectorWindowController receives callback
    ↓
SourceSelection.webcam(cameras, settings) created
    ↓
WindowManager receives selection
    ↓
WindowManager.transition(to: .recording)
    ↓
Create WebcamRecorder with config
    ↓
RecordingController.startRecording(with: webcamRecorder)
    ↓
Show mini-view overlay
    ↓
Recording in progress
```

### Recording Flow

```
RecordingController.startRecording()
    ↓
WebcamRecorder.startRecording(to: url, config: config)
    ↓
Create AVCaptureSession
    ↓
Add camera inputs (1-4)
    ↓
Add audio inputs (system + mic)
    ↓
Start session running
    ↓
Create AVAssetWriter with codec settings
    ↓
Setup PipCompositor with mode
    ↓
Setup AudioMixer with settings
    ↓
For each video frame:
    AVCaptureVideoDataOutput callback
    ↓
    Collect buffers from all cameras
    ↓
    PipCompositor.composeFrame()
    ↓
    AVAssetWriterInput.append(buffer)
For each audio buffer:
    AVCaptureAudioDataOutput callback
    ↓
    AudioMixer.process[mic]Audio()
    ↓
    AudioMixer.getMixedBuffer()
    ↓
    AVAssetWriterInput.append(buffer)
    ↓
User clicks Stop
    ↓
WebcamRecorder.stopRecording()
    ↓
Stop AVCaptureSession
    ↓
Finalize AVAssetWriter
    ↓
Return URL to RecordingController
    ↓
WindowManager receives URL
    ↓
WindowManager.transition(to: .editing)
    ↓
Create EditorWindowController with video URL
    ↓
Close mini-view
```

## Error Handling

### Permission Errors

**Detection:**
- Check `AVCaptureDevice.authorizationStatus(for: .video)`
- Check `AVCaptureDevice.authorizationStatus(for: .audio)`
- Proactive check on view load, not on start

**States:**
1. **Not Determined:** Request permission immediately
2. **Denied:** Show "Camera/Microphone Access Required"
   - Message: "OpenScreen needs camera access to record webcam video. Open System Settings to grant permission."
   - Button: "Open System Settings" → Deep link to `x-apple.systempreferences:com.apple.preference.security?Privacy_Camera`
   - Button: "Retry" → Re-check authorization status
3. **Restricted:** Show error, no action possible

**UI:**
- WebcamSourceViewController shows error state overlay
- Camera list hidden when permissions denied
- Helpful message with clear action

### Camera Errors

**Camera Disconnected During Recording:**
- Stop recording immediately
- Save partial recording if > 5 seconds
- Show alert: "Camera was disconnected. Recording saved. Check camera connection and try again."

**No Cameras Found:**
- Show empty state: "No cameras found. Connect a camera and click Refresh."
- Refresh button to re-enumerate

**Camera In Use by Another App:**
- Show error: "Camera is unavailable (in use by another application). Close other apps using the camera and try again."
- Disable that camera in selection list

### Recording Errors

**Disk Full:**
- Stop recording
- Show alert: "Disk full. Cannot save recording. Free up space and try again."
- Offer to open Finder to Downloads folder

**Session Configuration Failed:**
- Fall back to safe defaults (H.264, 720p)
- If still fails, show error: "Cannot configure camera. Try disconnecting and reconnecting the camera."

**AVAssetWriter Failed:**
- Stop session
- Show error: "Recording failed. The file may be corrupted."
- Check disk space, permissions

### Audio Errors

**Microphone Not Available:**
- Disable microphone controls
- Show warning: "Microphone not available. Recording with system audio only."
- Continue recording

**System Audio Capture Failed:**
- Show warning: "Cannot capture system audio. Recording with microphone only."
- Continue recording

### User Actions

**Cancel:**
- ESC key or Cancel button → Returns to .idle state
- Sheet closes, no recording created

**No Selection:**
- Start Recording button disabled until 1+ cameras selected

**Retry:**
- "Refresh" button re-enumerates cameras
- Useful after connecting new camera

**Reset to Defaults:**
- "Reset" button restores default quality/audio settings

## Testing Strategy

### Unit Tests

**CameraDevice Tests:**
- Camera enumeration returns correct devices
- Filter to video-capable devices only
- Exclude built-in FaceTime HD if desired (or keep as option)
- Thumbnail generation from AVCaptureDevice

**WebcamRecordingSettings Tests:**
- Default settings are valid
- Custom settings validate correctly (resolution, fps, bitrate ranges)
- Codec presets match capabilities

**PipCompositor Tests:**
- Layout calculation for each mode (single, dual, triple, quad)
- Aspect ratio handling (doesn't stretch)
- Buffer composition output size matches expected
- Performance: composition completes within frame time (33ms for 30fps)

**AudioMixer Tests:**
- Volume control affects output levels
- Mute silences respective source
- Mixing preserves synchronization
- Output buffer format matches AVAssetWriter expectations

### Integration Tests

**WebcamRecorder Lifecycle:**
- Start recording → session running, writer ready
- Stop recording → session stopped, file finalized
- Concurrent start/stop throws error (cannot start when already recording)

**Multi-Camera Setup:**
- Add 1-4 camera inputs to session
- Video outputs receive frames from all cameras
- Frame timestamps are synchronized

**Audio Pipeline:**
- System audio capture works
- Microphone capture works
- Mixed output contains both sources
- Volume controls affect mix ratio

**RecordingController Integration:**
- RecordingController accepts WebcamRecorder
- Callbacks propagate correctly
- State transitions work (sourceSelector → recording → editing)

**WindowManager Integration:**
- SourceSelection.webcam case handled
- WebcamRecorder configured with settings
- Mini-view shown during recording
- Transition to .editing after stop

### UI Tests (Manual)

**Camera Enumeration:**
- All connected cameras appear in list
- Camera names are readable
- Thumbnails show live feed
- Last-used camera highlighted

**Multi-Camera Selection:**
- Can select 1-4 cameras
- Selection state visible
- Cannot select more than 4

**Quality Controls:**
- Presets select appropriate values
- Custom controls enable when "custom" selected
- Sliders show current values
- Invalid values rejected (negative fps, 0 resolution)

**Audio Controls:**
- Mute buttons toggle state
- Volume sliders move smoothly
- Values display next to sliders
- Both system and mic independent

**Codec Selection:**
- All 4 codecs available
- Selection persists

**Mini-View:**
- Shows composited output during recording
- Stop button works
- Window is draggable
- Position remembered

**Permission Denied State:**
- Shows appropriate error message
- "Open System Settings" button works
- "Retry" button re-checks after granting

### Edge Cases

- All cameras disconnected mid-recording → Save partial, show error
- Permission revoked mid-recording → Stop, save partial, show error
- Disk space runs out → Stop, show disk full error
- User tries to switch cameras while recording → Controls disabled during recording
- Camera supports only some formats → Show only supported formats
- Multi-codec compatibility → Test H.264, HEVC, ProRes on different macOS versions
- 4K recording → Verify performance, disk usage
- Recording exceeds 2 hours → Verify file size, no crashes

### Performance Considerations

- Thumbnail previews at ~15 FPS (not full frame rate)
- PIP compositing should complete in < 10ms per frame
- Audio mixing adds minimal latency (< 50ms)
- AVAssetWriter writes efficiently (uses hardware encoding when available)
- Memory usage bounded (circular buffer for frames)

## Implementation Notes

### AVCaptureSession Configuration

**Session Setup:**
```swift
let session = AVCaptureSession()
session.sessionPreset = .inputPriority  // Manual control over format
session.automaticallyConfiguresApplicationAudioSession = false

let queue = DispatchQueue(label: "com.openscreen.webcam.session")
sessionQueue = queue
```

**Adding Camera Inputs:**
```swift
for camera in selectedCameras {
    let input = try camera.createCaptureInput()
    if session.canAddInput(input) {
        session.addInput(input)
    }
}
```

**Video Output:**
```swift
let output = AVCaptureVideoDataOutput()
output.setSampleBufferDelegate(self, queue: videoQueue)
output.videoSettings = [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
]
if session.canAddOutput(output) {
    session.addOutput(output)
}
```

**Starting Session:**
```swift
sessionQueue.async {
    session.startRunning()
}
```

### AVAssetWriter Setup

**Initialization:**
```swift
let writer = try AVAssetWriter(outputURL: url, fileType: .mov)

// Video input
let videoSettings: [String: Any] = [
    AVVideoCodecKey: codec.avCodecKey,
    AVVideoWidthKey: settings.resolution.width,
    AVVideoHeightKey: settings.resolution.height,
    AVVideoCompressionPropertiesKey: [
        AVVideoAverageBitRateKey: settings.bitrate,
        AVVideoProfileLevelKey: codec.profileLevel
    ]
]
let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
videoInput.expectsMediaDataInRealTime = true

// Audio input
let audioSettings: [String: Any] = [
    AVFormatIDKey: kAudioFormatMPEG4AAC,
    AVNumberOfChannelsKey: 2,
    AVSampleRateKey: 48000,
    AVEncoderBitRateKey: 128000
]
let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
audioInput.expectsMediaDataInRealTime = true

writer.add(videoInput)
writer.add(audioInput)
writer.startWriting()
writer.startSession(atSourceTime: kCMTimeZero)
```

**Pixel Buffer Adaptor:**
```swift
let adaptor = AVAssetWriterInputPixelBufferAdaptor(
    assetWriterInput: videoInput,
    sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
        kCVPixelBufferWidthKey as String: settings.resolution.width,
        kCVPixelBufferHeightKey as String: settings.resolution.height
    ]
)
```

### PIP Compositing Implementation

**Layout Calculations:**

For **Single** mode:
- Main camera fills entire output

For **Dual** mode:
- Main camera: 75% width, 100% height
- Overlay camera: 25% width, 25% height, top-right corner

For **Triple** mode:
- Main camera: 70% width, 100% height
- Camera 2: 30% width, 50% height, top-left
- Camera 3: 30% width, 50% height, top-right

For **Quad** mode:
- 2x2 grid, each 50% width, 50% height

**Composition:**
```swift
func composeFrame(buffers: [Int: CVPixelBuffer], into output: CVPixelBuffer, mode: PipMode) throws {
    let context = CIContext(options: [.useSoftwareRenderer: false])
    var currentImage = CIImage()

    for (index, buffer) in buffers.sorted(by: { $0.key < $1.key }) {
        let rect = calculateRect(for: index, mode: mode)
        let image = CIImage(cvPixelBuffer: buffer)

        // Calculate scale to fit rect
        let scaleX = rect.width / CGFloat(CVPixelBufferGetWidth(buffer))
        let scaleY = rect.height / CGFloat(CVPixelBufferGetHeight(buffer))
        let scaled = image.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
            .cropped(to: CGRect(x: 0, y: 0, width: rect.width, height: rect.height))
            .transformed(by: CGAffineTransform(translationX: rect.origin.x, y: rect.origin.y))

        if index == buffers.keys.first {
            currentImage = scaled
        } else {
            currentImage = scaled.composited(over: currentImage)
        }
    }

    try context.render(currentImage, to: output)
}
```

**Frame Synchronization:**
- Use `AVCaptureVideoDataOutput` timestamps for each camera
- Buffer frames to match slowest camera's frame rate
- Use camera with lowest frame rate as master clock
- For 30fps recording, buffer up to 3 frames (100ms) to allow sync
- Drop oldest frames if buffer overflows

### Audio Pipeline

**System Audio Capture:**

For system audio capture, we need a different approach than screen recording since AVCaptureSession doesn't provide system audio directly. Options:

**Option A: AVAudioEngine with Output Tap**
```swift
let engine = AVAudioEngine()
let outputNode = engine.outputNode
let format = outputNode.outputFormat(forBus: 0)

// Install tap to capture system audio
outputNode.installTap(onBus: 0, bufferSize: 8192, format: format) { [weak self] buffer, time in
    self?.audioMixer.processSystemAudio(buffer)
}
```

**Option B: Use BlackHole (Virtual Audio Device)**
- Install BlackHole audio driver (user action required)
- User sets BlackHole as output in System Settings
- Capture from BlackHole input device
- More reliable but requires third-party driver

**Recommendation:** Use Option A for simplicity, fall back to no system audio if capture fails. Add note in UI about optional BlackHole for better system audio capture.

**AudioMixer Output Format:**
- Normalize all inputs to 48kHz stereo before mixing
- Output consistent format for AVAssetWriter:
  ```swift
  let mixedFormat = AVAudioFormat(
      commonFormat: .pcmFormatFloat32,
      sampleRate: 48000,
      channels: 2,
      interleaved: true
  )
  ```

**Microphone Capture:**
```swift
let micInput = try AVCaptureDeviceInput(device: microphoneDevice)
session.addInput(micInput)

let audioOutput = AVCaptureAudioDataOutput()
audioOutput.setSampleBufferDelegate(self, queue: audioQueue)
session.addOutput(audioOutput)
```

**Mixing with AVAudioEngine:**
```swift
let engine = AVAudioEngine()

// System audio node
let systemNode = AVAudioPlayerNode()
engine.attach(systemNode)

// Mic node
let micNode = AVAudioPlayerNode()
engine.attach(micNode)

// Mixer
let mixer = AVAudioMixerNode()
engine.attach(mixer)

engine.connect(systemNode, to: mixer, format: systemFormat)
engine.connect(micNode, to: mixer, format: micFormat)

// Volume control
mixer.inputVolume = settings.systemVolume
micNode.volume = settings.microphoneVolume
```

### WindowManager Updates

**Handle Webcam Selection:**
```swift
case .webcam(let cameras, let settings):
    print("✅ Selected \(cameras.count) camera(s)")

    Task { @MainActor in
        let config = WebcamRecordingConfig(
            cameras: cameras,
            compositingMode: settings.compositingMode,
            videoSettings: settings.videoSettings,
            audioSettings: settings.audioSettings,
            codec: settings.codec
        )

        let recorder = WebcamRecorder()
        do {
            let url = try await recordingController.startRecording(with: recorder, config: config)
            await handleRecordingStarted(url)
        } catch {
            await handleRecordingError(error)
        }
    }
```

**RecordingController API Update:**
```swift
func startRecording(with recorder: Recorder, config: Any) async throws -> URL {
    currentRecorder = recorder
    let url = try FileUtils.uniqueRecordingURL()
    try await recorder.startRecording(to: url, config: config)
    return url
}
```

### Mini-View Implementation

**Window Setup:**
```swift
class MiniRecordingView: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 240),
            styleMask: [.resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.isFloatingPanel = true
        self.level = .floating
        self.title = "Recording"
    }
}
```

**Position Persistence:**
```swift
private static let positionKey = "miniRecordingViewPosition"

func savePosition() {
    let origin = self.frame.origin
    UserDefaults.standard.set([origin.x, origin.y], forKey: Self.positionKey)
}

func restorePosition() {
    guard let saved = UserDefaults.standard.array(forKey: Self.positionKey) as? [CGFloat],
          let x = saved.first, let y = saved.last else { return }
    self.setFrameOrigin(NSPoint(x: x, y: y))
}
```

### Codec Support

**Supported Codecs:**
```swift
enum VideoCodec: String, CaseIterable {
    case h264 = "H.264"
    case hevc = "HEVC"
    case prores422 = "ProRes 422"
    case prores4444 = "ProRes 4444"

    var avCodecKey: AVVideoCodecType {
        switch self {
        case .h264: return .h264
        case .hevc: return .hevc
        case .prores422: return .proRes422
        case .prores4444: return .proRes4444
        }
    }

    var profileLevel: String? {
        switch self {
        case .h264: return AVVideoProfileLevelH264HighAutoLevel
        case .hevc: return AVVideoProfileLevelHEVCMainAutoLevel
        default: return nil
        }
    }
}
```

**Compatibility:**
- H.264: All macOS versions, most compatible
- HEVC: macOS 10.13+, smaller files, slower encoding
- ProRes 422: macOS 10.7+, professional quality, large files
- ProRes 4444: macOS 10.7+, with alpha channel, largest files

**Runtime Availability Check:**
```swift
extension VideoCodec {
    static func availableCodecs() -> [VideoCodec] {
        var codecs: [VideoCodec] = [.h264]

        if #available(macOS 10.13, *) {
            codecs.append(.hevc)
        }

        // ProRes codecs are available on macOS 10.7+
        codecs.append(.prores422)
        codecs.append(.prores4444)

        return codecs
    }

    func isAvailable() -> Bool {
        switch self {
        case .h264:
            return true
        case .hevc:
            if #available(macOS 10.13, *) {
                return true
            }
            return false
        case .prores422, .prores4444:
            if #available(macOS 10.7, *) {
                return true
            }
            return false
        }
    }

    func validate() throws {
        guard isAvailable() else {
            return VideoError.codecNotSupported(self)
        }
    }
}
```

**UI Integration:**
- WebcamSourceViewController should call `VideoCodec.availableCodecs()` on load
- Only show available codecs in dropdown
- If user selected codec becomes unavailable (e.g., moved to older Mac), fall back to H.264

## Files to Create

1. `Sources/native-macos/Recording/Recorder.swift` - Protocol definition
2. `Sources/native-macos/Recording/WebcamRecorder.swift` - Main recorder implementation
3. `Sources/native-macos/Recording/PipCompositor.swift` - PIP layout composition
4. `Sources/native-macos/Recording/AudioMixer.swift` - Audio mixing logic
5. `Sources/native-macos/SourceSelector/Models/CameraDevice.swift` - Camera model
6. `Sources/native-macos/SourceSelector/Models/WebcamRecordingSettings.swift` - Settings model
7. `Sources/native-macos/Recording/MiniRecordingView.swift` - Mini-view overlay
8. `Tests/OpenScreenTests/RecordingTests/CameraDeviceTests.swift` - Unit tests
9. `Tests/OpenScreenTests/RecordingTests/PipCompositorTests.swift` - Unit tests
10. `Tests/OpenScreenTests/RecordingTests/AudioMixerTests.swift` - Unit tests
11. `Tests/OpenScreenTests/IntegrationTests/WebcamRecordingIntegrationTests.swift` - Integration tests

## Files to Modify

1. `Sources/native-macos/Recording/ScreenRecorder.swift` - Conform to Recorder protocol
2. `Sources/native-macos/Recording/RecordingController.swift` - Accept Recorder protocol
3. `Sources/native-macos/SourceSelector/WebcamSourceViewController.swift` - Replace placeholder
4. `Sources/native-macos/SourceSelector/Models/SourceSelection.swift` - Enable webcam case
5. `Sources/native-macos/App/WindowManager.swift` - Handle webcam selection flow
6. `Sources/native-macos/App/AppDelegate.swift` - Add camera/mic permissions info.plist keys

## API Changes Required

### RecordingController Update

**Current:**
```swift
func startRecording(displayID: CGDirectDisplayID? = nil) async throws -> URL
```

**New (Type-Safe Approach):**
```swift
func startRecording(displayID: CGDirectDisplayID? = nil) async throws -> URL {
    // Use default screen recorder
    let url = try FileUtils.uniqueRecordingURL()
    currentRecordingURL = url
    try await screenRecorder.startRecording(to: url, displayID: displayID)
    return url
}

func startRecording<T: Recorder>(
    with recorder: T,
    config: T.Config
) async throws -> URL where T.Config: Sendable {
    let url = try FileUtils.uniqueRecordingURL()
    currentRecordingURL = url
    try await recorder.startRecording(to: url, config: config)
    currentRecorder = recorder
    return url
}
```

**Recorder Protocol with Associated Type:**
```swift
protocol Recorder: Sendable {
    associatedtype Config: Sendable

    func startRecording(to url: URL, config: Config) async throws
    func stopRecording() async throws -> URL
    var isRecording: Bool { get }
}
```

**ScreenRecorder Conformance:**
```swift
extension ScreenRecorder: Recorder {
    struct Config: Sendable {
        let displayID: CGDirectDisplayID?
    }

    func startRecording(to url: URL, config: Config) async throws {
        try await startRecording(to: url, displayID: config.displayID)
    }

    var isRecording: Bool { isRecording }
}
```

**WebcamRecorder Conformance:**
```swift
struct WebcamRecordingConfig: Sendable {
    let cameras: [CameraDevice]
    let compositingMode: PipMode
    let videoSettings: VideoSettings
    let audioSettings: AudioSettings
    let codec: VideoCodec
}

extension WebcamRecorder: Recorder {
    typealias Config = WebcamRecordingConfig

    func startRecording(to url: URL, config: Config) async throws {
        // Webcam-specific implementation
    }
}
```

### SourceSelection Update

**Current:**
```swift
enum SourceSelection: Equatable, Sendable {
    case screen(displayID: CGDirectDisplayID, displayName: String)
    case videoFile(url: URL)
    // case webcam(deviceID: String, deviceName: String)  // Commented out
}
```

**New:**
```swift
enum SourceSelection: Equatable, Sendable {
    case screen(displayID: CGDirectDisplayID, displayName: String)
    case videoFile(url: URL)
    case webcam(cameras: [CameraDevice], settings: WebcamRecordingSettings)
}
```

### WindowState Transition Update

**Current:**
```swift
case .sourceSelector:
    return [.idle, .recording, .editing]
```

**No change needed** - webcam recording transitions to `.recording`, then to `.editing` (already supported).

## Info.plist Keys Required

Add the following keys to `Info.plist` or in the project's target settings:

```xml
<key>NSCameraUsageDescription</key>
<string>OpenScreen needs camera access to record webcam video.</string>
<key>NSMicrophoneUsageDescription</key>
<string>OpenScreen needs microphone access to record audio with your video.</string>
```

**Note:** For SPM projects without Info.plist, these can be added programmatically or via the macOS target settings in Xcode.

## Success Criteria

✅ User can select from multiple webcams (1-4)
✅ Live preview shows camera feed
✅ Recording includes audio and video
✅ Audio mixing controls work (mute + volume for system + mic)
✅ Quality controls work (resolution, fps, bitrate)
✅ Codec selection works (H.264, HEVC, ProRes)
✅ PIP compositing works (single, dual, triple, quad layouts)
✅ Mini-view shows during recording
✅ Recording stops correctly and file is playable
✅ WindowManager transitions work correctly
✅ Permissions handled gracefully

## Success Metrics

- Multi-camera recording works at 30fps minimum
- Audio/video synchronization is accurate (< 50ms drift)
- PIP compositing completes in < 10ms per frame
- File output is playable in QuickTime Player
- All 4 codecs produce valid, playable files
- Permission errors show helpful UI
- Mini-view is responsive and drag-able
