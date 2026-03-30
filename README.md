# OpenScreen Native (Swift, macOS)

A native macOS screen and webcam recording application built with Swift, featuring a comprehensive video editor with timeline, effects, transitions, and multi-clip editing capabilities.

## Features

### Recording
- **Screen Recording**: Capture any display or window
- **Webcam Recording**: Multi-camera support (1-4 cameras) with PiP compositing
- **Audio Mixing**: System audio + microphone with independent volume/mute controls
- **Quality & Codec Options**: H.264, HEVC, ProRes 422/4444
- **Live Preview**: Real-time preview during recording

### Video Editor
- **Timeline**: Multi-track timeline with video, audio, and effect tracks
- **Playback Controls**: Play, pause, JKL shuttle, and frame-by-frame navigation
- **Clips**: Split, trim, move, duplicate, and delete clips
- **In/Out Points**: Set and clear in/out points for precise editing
- **Loop Regions**: Create and manage loop regions for focused editing
- **Chapter Markers**: Add and manage chapter markers

### Effects & Transitions
- **Video Effects**: Apply real-time video effects with presets
- **Audio Effects**: Process audio with built-in effects
- **Transitions**: Create smooth transitions between clips with auto-transition prompts
- **Effect Presets**: Save and manage custom effect presets

### Editing Tools
- **Metal Rendering**: Hardware-accelerated video rendering using Metal
- **Waveform Display**: Audio waveform visualization on timeline
- **Thumbnail Cache**: Efficient thumbnail generation for timeline clips
- **Keyboard Shortcuts**: Comprehensive keyboard shortcut support

### Export
- **Export Settings**: Configurable quality settings and codecs
- **Composition Builder**: Build export compositions with transitions

## Project Structure

```
Sources/native-macos/
├── App/                    # Application lifecycle and window management
│   ├── AppDelegate.swift
│   ├── WindowManager.swift
│   └── ResourceCoordinator.swift
├── Recording/              # Recording functionality
│   ├── ScreenRecorder.swift
│   ├── WebcamRecorder.swift
│   ├── PipCompositor.swift
│   ├── AudioMixer.swift
│   └── HUDWindowController.swift
├── Editing/                # Video editing core
│   ├── EditorWindowController.swift
│   ├── VideoProcessor.swift
│   ├── MetalRenderer.swift
│   ├── VideoPreview.swift
│   └── MarkersPanel.swift
├── Timeline/               # Timeline components
│   ├── TimelineView.swift
│   ├── ClipTrack.swift
│   ├── PlaybackControls.swift
│   ├── ScrubController.swift
│   ├── JKLController.swift
│   ├── AudioWaveformGenerator.swift
│   └── ThumbnailCache.swift
├── Effects/                # Effects system
│   ├── VideoEffect.swift
│   ├── AudioEffect.swift
│   ├── VideoEffectProcessor.swift
│   ├── AudioEffectProcessor.swift
│   └── PresetStorage.swift
├── Operations/             # Edit operations (undo/redo)
│   ├── SplitClipOperation.swift
│   ├── TrimClipOperation.swift
│   ├── MoveClipOperation.swift
│   └── TransitionOperations/
├── UndoRedo/               # Undo/redo system
│   ├── ClipUndoManager.swift
│   ├── CoalescingStrategy.swift
│   └── HistoryLimit.swift
└── Shared/                 # Shared models and utilities
    ├── Models/             # EditorState, Recording, TimelineModels
    └── Utilities/          # FileUtils, TimeUtils
```

## Requirements

- **macOS 13.0+** (for HEVC and modern AVFoundation features)
- **Xcode** or **Swift 6.0+** command line tools
- **Metal-compatible GPU** for video rendering

## Build & Run

### Quick Start

```bash
# From the project root
cd native-macos

# Build the project
swift build

# Run the application
swift run

# Or build and create a distributable DMG
./build-dmg.sh

# Test launch with debug logging
./test-launch.sh
```

### Building Metal Shaders

The project includes Metal shaders for video rendering. Build them with:

```bash
./build-metal-shaders.sh
```

## Testing

The project includes comprehensive unit tests:

```bash
# Run all tests
swift test

# Run specific test module
swift test --filter TimelineTests
```

## Permissions

On first run, macOS will request the following permissions:

1. **Screen Recording** - Required for screen capture
   - System Settings → Privacy & Security → Screen Recording
2. **Camera** - Required for webcam recording
   - System Settings → Privacy & Security → Camera
3. **Microphone** - Required for audio recording
   - System Settings → Privacy & Security → Microphone

## Development

### Architecture

- **MVVM Pattern**: Clear separation between views, view models, and models
- **Metal Rendering**: GPU-accelerated video processing using Metal shaders
- **Undo/Redo System**: Comprehensive undo/redo with coalescing support
- **Command Pattern**: Edit operations implement undoable commands
- **NotificationCenter**: Decoupled communication between components

### Key Design Patterns

- **Coordinator Pattern**: `ResourceCoordinator` manages shared resources
- **Window Manager**: Centralized window lifecycle management
- **Operation Queue**: Edit operations are queued for undo/redo
- **Effect Processors**: Modular effect processing pipeline

## Distribution

### Building a DMG

```bash
./build-dmg.sh
```

This creates:
- `OpenScreen.app` - The application bundle
- `OpenScreen-1.0.0.dmg` - Distributable disk image

The DMG includes:
- Code signing entitlements (in `OpenScreen.entitlements`)
- Proper Info.plist with permission descriptions
- Metal shader resources bundled

## Debug Logging

View debug logs while the app is running:

```bash
log stream --predicate 'process == "OpenScreen"' --level debug
```

## Contributing

This is an active development project. Key areas for contribution:
- Additional video effects and transitions
- Export format options
- Performance optimizations
- UI/UX improvements

## License

Part of the OpenScreen project - see parent project LICENSE file.
