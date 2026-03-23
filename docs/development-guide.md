# OpenScreen Development Guide

This guide provides comprehensive documentation for developers working on OpenScreen, covering the major features and their implementation.

## Table of Contents

- [Video Transitions](#video-transitions)
- [Timeline Operations](#timeline-operations)
- [Clip Management](#clip-management)
- [Effects System](#effects-system)

---

## Video Transitions

The Video Transitions feature provides professional-grade transition effects between video clips on the timeline.

### Built-in Transition Types

OpenScreen includes 5 built-in transition types:

1. **Crossfade (Dissolve)**
   - Fades from leading clip to trailing clip
   - Configurable curve (linear, ease-in, ease-out, ease-in-out)
   - Best for: Smooth, subtle transitions

2. **Wipe Left**
   - Reveals trailing clip from left to right
   - Configurable edge softness
   - Best for: Directional movement, time passage

3. **Wipe Right**
   - Reveals trailing clip from right to left
   - Configurable edge softness
   - Best for: Reverse direction, flashbacks

4. **Circle Reveal**
   - Expanding circular reveal from center
   - Configurable position and radius
   - Best for: Focusing attention, dramatic reveals

5. **Vertical Blinds**
   - Vertical blinds opening effect
   - Configurable blade count and spacing
   - Best for: Stylistic transitions, segmented content

### Built-in Presets

Quick-start presets for common use cases:

- **Quick Dissolve**: 0.5s crossfade with linear curve
- **Slow Fade**: 2.0s crossfade with ease-in-out curve
- **Wipe Left**: 1.0s left-to-right wipe
- **Circle Reveal**: 1.5s center reveal
- **Vertical Blinds**: 1.0s blinds with 8 blades

### Creation Methods

Transitions can be created using 4 different methods:

#### 1. Drag and Drop (from Palette)

**Workflow:**
1. Open Transitions palette (Window > Transitions)
2. Drag a transition type from the palette
3. Drop it on the overlap area between two clips
4. Transition is created with default parameters

**Code Example:**
```swift
let preset = BuiltInPresets.presets.first { $0.name == "Quick Dissolve" }
let transition = preset.makeTransition(
    leadingClipID: leadingClip.id,
    trailingClipID: trailingClip.id
)
editorState.addTransition(transition)
```

#### 2. Context Menu (Right-click)

**Workflow:**
1. Right-click on the overlap area between clips
2. Select "Add Transition" from context menu
3. Choose a preset from the submenu
4. Transition is created immediately

**UI Elements:**
- Context menu appears at cursor position
- Submenu shows all 5 built-in presets
- Each preset displays formatted duration

#### 3. Auto-prompt on Overlap

**Workflow:**
1. Drag a clip to create 0.5s+ overlap
2. Auto-prompt appears: "Add transition between clips?"
3. Click "Quick Dissolve" button (or dismiss)
4. Respects 5-minute cooldown after dismissal

**Trigger Conditions:**
- Overlap duration ≥ 0.5 seconds
- No existing transition between clips
- Not within cooldown period

#### 4. Keyboard Shortcut (Cmd+Opt+T)

**Workflow:**
1. Select two overlapping clips (or the overlap area)
2. Press Cmd+Opt+T
3. Quick Dissolve transition is created
4. Reuse shortcut to apply same preset elsewhere

**Behavior:**
- Defaults to Quick Dissolve preset
- Remembers last-used preset
- Provides visual feedback on creation

### Inspector Usage

When a transition is selected, the Inspector shows three tabs:

#### Properties Tab

Editable parameters for the current transition:

**Duration:**
- Slider: 0.1s to overlap duration
- Text input: Direct time entry (e.g., "1.5s")
- Validation: Cannot exceed overlap duration

**Type-specific Parameters:**
- **Crossfade**: Curve selector (linear, ease-in, ease-out, ease-in-out)
- **Wipe**: Edge softness slider (0-100%)
- **Circle Reveal**: Position X/Y sliders, radius slider
- **Blinds**: Blade count (2-16), spacing slider

**Enable/Disable:**
- Toggle checkbox to enable/disable transition
- Disabled transitions are skipped during export

#### Presets Tab

Apply built-in or custom presets:

**Built-in Presets:**
- Lists all 5 built-in presets
- Shows name and duration for each
- Click to apply all parameters at once

**Custom Presets:**
- Save current settings as custom preset
- Name and describe your preset
- Appears in preset list for future use

**Preset Management:**
- Delete custom presets
- Duplicate existing presets
- Reset to built-in defaults

#### Preview Tab

Real-time preview of transition animation:

**Preview Controls:**
- Play/Pause button
- Duration slider (updates preview in real-time)
- Parameter adjustments update preview immediately

**Preview Display:**
- Shows leading clip fading out
- Shows trailing clip fading in
- Renders at reduced resolution for performance
- Loops continuously while playing

### Validation Rules

Transitions must meet these validation criteria:

1. **Minimum Duration**: 0.05 seconds (50ms)
2. **Maximum Duration**: Cannot exceed overlap duration
3. **Clip References**: Must reference valid, existing clips
4. **Overlap Required**: Leading and trailing clips must overlap
5. **Track Same**: Both clips must be on the same track

**Example Validation:**
```swift
let validator = TransitionValidator()
let result = validator.validate(transition, in: editorState)

switch result {
case .valid:
    print("Transition is valid")
case .insufficientOverlap(let required):
    print("Need \(required)s overlap")
case .clipsNotFound:
    print("Referenced clips don't exist")
}
```

### Rendering Pipeline

Transitions are rendered during export using `TransitionExportPipeline`:

**Process:**
1. Detect transitions in timeline
2. For each transition:
   - Extract leading clip frames
   - Extract trailing clip frames
   - Apply transition effect per frame
   - Composite output frames
3. Merge with non-transition frames
4. Write final output file

**Metal Acceleration:**
- Crossfade: GPU-accelerated blending
- Wipe: Metal shader for edge rendering
- Circle: Metal shader for reveal
- Blinds: Metal shader for blade rendering

### Testing

Comprehensive test coverage includes:

**Unit Tests:**
- `TransitionTypeTests` - Type creation and validation
- `TransitionParametersTests` - Parameter encoding/decoding
- `TransitionFactoryTests` - Factory creation methods
- `TransitionValidatorTests` - Validation logic
- `TransitionPresetTests` - Preset application

**Integration Tests:**
- `TransitionClipTests` - Clip integration
- `EditorStateTransitionTests` - State management
- `ContextMenuCreationTests` - Context menu workflow
- `AutoTransitionPromptTests` - Auto-prompt workflow

**UI Tests:**
- `TransitionUITests` - Complete user workflows
  - Drag and drop workflow
  - Context menu workflow
  - Auto-prompt workflow
  - Keyboard shortcut workflow
  - Inspector preview loop
  - Preset application

**Rendering Tests:**
- `TransitionRenderingTests` - Export pipeline
- `TransitionPreviewViewTests` - Preview rendering

### Common Tasks

#### Create a Transition Programmatically

```swift
// Get overlapping clips
let clips = track.clips.sorted { $0.timeRangeInTimeline.start < $1.timeRangeInTimeline.start }
let leading = clips[0]
let trailing = clips[1]

// Create transition
let transition = TransitionClip(
    type: .crossfade,
    duration: CMTime(seconds: 1.0, preferredTimescale: 600),
    leadingClipID: leading.id,
    trailingClipID: trailing.id,
    parameters: .crossfade,
    isEnabled: true
)

// Add to editor state
editorState.addTransition(transition)
```

#### Update Transition Parameters

```swift
// Get existing transition
guard let transition = editorState.transitions.first else { return }

// Update duration
let updated = TransitionClip(
    id: transition.id,
    type: transition.type,
    duration: CMTime(seconds: 2.0, preferredTimescale: 600),
    leadingClipID: transition.leadingClipID,
    trailingClipID: transition.trailingClipID,
    parameters: transition.parameters,
    isEnabled: transition.isEnabled
)

editorState.updateTransition(updated)
```

#### Apply Preset to Transition

```swift
let preset = BuiltInPresets.presets.first { $0.name == "Slow Fade" }
guard let transition = editorState.transitions.first,
      let preset = preset else { return }

let updated = TransitionClip(
    id: transition.id,
    type: preset.transitionType,
    duration: preset.duration,
    leadingClipID: transition.leadingClipID,
    trailingClipID: transition.trailingClipID,
    parameters: preset.parameters,
    isEnabled: transition.isEnabled
)

editorState.updateTransition(updated)
```

#### Delete a Transition

```swift
if let transition = editorState.transitions.first {
    editorState.removeTransition(transition.id)
}
```

### Architecture

**Key Components:**

- **TransitionClip**: Model representing a transition between two clips
- **TransitionParameters**: Type-safe parameter storage for each transition type
- **TransitionValidator**: Validates transitions before creation/updates
- **TransitionFactory**: Creates transitions with sensible defaults
- **TransitionPreset**: Reusable preset configuration
- **BuiltInPresets**: Collection of 5 built-in presets
- **TransitionExportPipeline**: Renders transitions during export
- **TransitionPaletteItem**: Palette item for drag-and-drop
- **TransitionInspectorViewController**: Inspector UI controller

**Data Flow:**

```
User Action (drag/menu/shortcut)
    ↓
TimelineViewModel
    ↓
EditorState.addTransition()
    ↓
TransitionValidator.validate()
    ↓
TransitionClip created
    ↓
UI updates (timeline, inspector)
    ↓
Export pipeline (when exporting)
```

### Performance Considerations

**Timeline Rendering:**
- Transitions rendered as overlay on clip track
- Cached layout calculations for performance
- Only visible transitions rendered

**Preview Rendering:**
- Reduced resolution for real-time preview
- Metal acceleration for smooth playback
- Looping preview for continuous feedback

**Export Rendering:**
- Full-resolution rendering
- Frame-by-frame processing
- GPU acceleration where available
- Progress reporting during export

### Future Enhancements

Potential improvements for the transitions system:

- Custom transition shaders (user-defined Metal shaders)
- Transition templates with multiple effects
- Audio transitions (crossfade, ducking)
- 3D transitions (cube flip, page curl)
- Transition presets library (cloud sync)
- Transition timing curves (Bezier editor)
- Reverse transition direction option

---

## Timeline Operations

[Documentation for timeline operations to be added]

---

## Clip Management

[Documentation for clip management to be added]

---

## Effects System

[Documentation for effects system to be added]
