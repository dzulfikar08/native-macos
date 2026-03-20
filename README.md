# OpenScreen Native (Swift, macOS)

This is a minimal native macOS Swift version of OpenScreen focused on a simple HUD-style screen recorder, created alongside the existing Electron app.

## Features

### Screen Recording
- Floating HUD window at the bottom of the main screen
- Single button to start/stop recording
- Records the main display to `.mov` files
- Saves recordings under `~/Movies/OpenScreenNative` and reveals the file in Finder when done

### Webcam Recording (NEW!)
- **Multi-Camera Support**: Select 1-4 cameras for recording
- **PIP Compositing**: Single, dual, triple, or quad camera layouts
- **Quality Controls**: Presets from Low (480p) to Ultra (4K) + custom settings
- **Codec Selection**: H.264, HEVC, ProRes 422, ProRes 4444
- **Audio Mixing**: System audio + microphone with independent volume/mute controls
- **Live Preview**: Mini-view overlay during recording

> Note: This is **not** yet a full feature-complete port of the Electron/React editor (no timeline/zoom/annotations/export UI yet). It is a foundation you can extend.

## Requirements

- macOS 13+ (for HEVC and modern AVFoundation features)
- Xcode command line tools installed (`xcode-select --install` if needed)
- Built-in or connected webcam (for webcam recording)
- Microphone (for audio recording)

## Build & Run

From the project root (`/Users/macbookpro/Documents/Personal/openscreen`):

```bash
cd native-macos
swift build
swift run
```

## Permissions

On first run, macOS will ask for the following permissions:

1. **Screen Recording**: For screen capture. Grant it in **System Settings → Privacy & Security → Screen Recording**
2. **Camera**: For webcam recording. Grant it in **System Settings → Privacy & Security → Camera**
3. **Microphone**: For audio recording. Grant it in **System Settings → Privacy & Security → Microphone**

These permissions can be managed at any time in System Settings.

## Usage

### Screen Recording
- Choose "Screen" from the source selector
- A translucent HUD window appears centered near the bottom of the main display
- Click **Start Recording** to begin capturing the entire main screen
- Click **Stop Recording** to finish; the movie file is saved to `~/Movies/OpenScreenNative` and that folder is opened in Finder

### Webcam Recording
- Choose "Webcam" from the source selector
- Select 1-4 cameras from the list (each has a live preview)
- Adjust quality preset and codec as needed
- Click **Start Recording** to begin
- A mini-view window shows the live composited feed
- Click **Stop Recording** in the mini-view to finish

## Roadmap / Gaps vs Electron Version

- Source selector window is partially implemented (screen and webcam available)
- No video editor UI (timeline, zooms, annotations, export options, etc.)
- No tray icon / menu bar integration

These can be implemented incrementally by building additional windows and controllers in the `Sources/native-macos` target.
