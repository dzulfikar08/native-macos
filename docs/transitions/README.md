# Video Transitions System

## Overview

The Video Transitions system provides seamless transitions between video clips with support for multiple transition types, custom parameters, and preset management.

## Architecture

### Core Components

- **TransitionClip**: Model representing a transition between two clips
- **TransitionValidator**: Validates transition parameters and constraints
- **TransitionRenderContext**: Manages transition rendering pipeline
- **TransitionPreset**: Reusable transition configurations
- **PresetLibrary**: Manages preset collection (built-in + custom)

### Rendering Pipeline

```
TransitionClip
    ↓
TransitionRenderContext.renderer(for:)
    ↓
Specific Renderer (CrossfadeRenderer, WipeRenderer, etc.)
    ↓
CVPixelBuffer output
```

## Supported Transitions

1. **Crossfade** - Smooth dissolve between clips
2. **Fade to Color** - Fade through a solid color
3. **Wipe** - Directional reveal (4 directions)
4. **Iris** - Shape-based reveal (circle/rectangle)
5. **Blinds** - Slat-based reveal (horizontal/vertical)

## Usage

### Basic Transition

```swift
let transition = TransitionClip(
    type: .crossfade,
    duration: CMTime(seconds: 1, preferredTimescale: 600),
    leadingClipID: leadingClip.id,
    trailingClipID: trailingClip.id,
    parameters: .crossfade,
    isEnabled: true
)

editorState.addTransition(transition)
```

### Custom Parameters

```swift
let transition = TransitionClip(
    type: .wipe,
    duration: CMTime(seconds: 1.5, preferredTimescale: 600),
    leadingClipID: leadingClip.id,
    trailingClipID: trailingClip.id,
    parameters: .wipe(direction: .left, softness: 0.5, border: 2.0),
    isEnabled: true
)
```

### Using Presets

```swift
let preset = BuiltInPresets.presets.first { $0.name == "Quick Dissolve" }
let transition = preset.makeTransition(
    leadingClipID: clip1.id,
    trailingClipID: clip2.id
)
```

## Performance

- Target: 60fps playback (16.67ms per frame)
- Memory: ~50KB per transition
- Thumbnail generation: ~100ms per preset

See `docs/performance/transitions-baseline.md` for detailed metrics.

## Known Limitations

- Transitions cannot overlap (Phase 3.2)
- Only video transitions (audio crossfade only) (Phase 3.4)
- No custom shader editor UI (Phase 3.2)
