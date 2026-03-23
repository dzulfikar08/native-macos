# Transitions API Reference

## TransitionClip

```swift
struct TransitionClip {
    let type: TransitionType
    let duration: CMTime
    let leadingClipID: UUID
    let trailingClipID: UUID
    let parameters: TransitionParameters
    let isEnabled: Bool
}
```

### Creating Transitions

```swift
let transition = TransitionClip(
    type: .crossfade,
    duration: CMTime(seconds: 1.0, preferredTimescale: 600),
    leadingClipID: clip1.id,
    trailingClipID: clip2.id,
    parameters: .crossfade,
    isEnabled: true
)
```

## TransitionValidator

```swift
struct TransitionValidator {
    static let minimumDuration: CMTime

    func validate(_ transition: TransitionClip, availableOverlap: CMTime) throws
    func validate(clip: TransitionClip) -> ValidationResult
    func validate(type: TransitionType, duration: CMTime, overlap: CMTime) -> ValidationResult
    func clampParameters(_ parameters: TransitionParameters) -> TransitionParameters
}
```

### ValidationResult

```swift
struct ValidationResult {
    let isValid: Bool
    let errors: [TransitionError]
    let warnings: [TransitionWarning]
}
```

## TransitionPreset

```swift
struct TransitionPreset {
    let id: UUID
    let name: String
    let isBuiltIn: Bool
    let folder: String
    let isFavorite: Bool
    let transitionType: TransitionType
    let parameters: TransitionParameters
    let duration: CMTime

    func makeTransition(
        leadingClipID: UUID,
        trailingClipID: UUID
    ) -> TransitionClip
}
```

## PresetLibrary

```swift
@MainActor
class PresetLibrary: ObservableObject {
    var allPresets: [TransitionPreset]
    var folders: Set<String>

    func loadCustomPresets() throws
    func savePreset(name: String, folder: String, transition: TransitionClip, isFavorite: Bool) throws
    func deletePreset(_ preset: TransitionPreset) throws
    func updatePreset(_ preset: TransitionPreset, name: String?, folder: String?)
    func toggleFavorite(_ preset: TransitionPreset)
    func presetsInFolder(_ folder: String) -> [TransitionPreset]
    func favoritePresets() -> [TransitionPreset]
    func importPreset(from url: URL) throws
    func exportPreset(_ preset: TransitionPreset, to url: URL) throws
}
```

## BuiltInPresets

```swift
enum BuiltInPresets {
    static let presets: [TransitionPreset]
}
```

Available presets:
- Quick Dissolve (crossfade, 0.5s)
- Slow Fade (fade to black, 2.0s)
- Wipe Left (left wipe, 1.0s)
- Circle Reveal (iris, 1.5s)
- Vertical Blinds (blinds, 1.0s)
