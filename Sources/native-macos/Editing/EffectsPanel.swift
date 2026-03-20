import AppKit
import Foundation
import AVFoundation

/// Effects panel UI component for applying video and audio effects
@MainActor
final class EffectsPanel: NSView {
    // MARK: - Properties

    private var editorState: EditorState

    // UI Components
    private var presetLabel: NSTextField!
    private var presetPopupButton: NSPopUpButton!
    private var videoLabel: NSTextField!
    private var videoEffectsScrollView: NSScrollView!
    private var audioLabel: NSTextField!
    private var audioEffectsScrollView: NSScrollView!
    private var addVideoEffectButton: NSButton!
    private var addAudioEffectButton: NSButton!
    private var savePresetButton: NSButton!
    private var applyButton: NSButton!
    private var resetButton: NSButton!

    // Expose components for testing
    var presetPopupButtonForTesting: NSPopUpButton { presetPopupButton }
    var applyButtonForTesting: NSButton { applyButton }
    var resetButtonForTesting: NSButton { resetButton }

    private var visualEffectView: NSVisualEffectView!

    // Data
    private var currentPreset: EffectPreset?
    private var customPresets: [EffectPreset] = []

    // MARK: - Initialization

    init(editorState: EditorState) {
        self.editorState = editorState
        super.init(frame: .zero)
        setupUI()
        setupConstraints()
        setupObservations()
        loadCustomPresets()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - UI Setup

    private func setupUI() {
        // Create visual effect view for background
        visualEffectView = NSVisualEffectView()
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        visualEffectView.material = .popover
        visualEffectView.blendingMode = .behindWindow
        addSubview(visualEffectView)

        // Preset dropdown
        presetLabel = NSTextField(labelWithString: "Preset:")
        presetLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        presetLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(presetLabel)

        presetPopupButton = NSPopUpButton()
        presetPopupButton.target = self
        presetPopupButton.action = #selector(presetChanged)
        presetPopupButton.bezelStyle = .rounded
        presetPopupButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(presetPopupButton)
        populatePresetMenu()

        // Video Effects section
        videoLabel = NSTextField(labelWithString: "Video Effects:")
        videoLabel.font = NSFont.boldSystemFont(ofSize: 13)
        videoLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(videoLabel)

        videoEffectsScrollView = NSScrollView()
        videoEffectsScrollView.hasVerticalScroller = true
        videoEffectsScrollView.hasHorizontalScroller = false
        videoEffectsScrollView.autohidesScrollers = true
        videoEffectsScrollView.drawsBackground = false
        videoEffectsScrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(videoEffectsScrollView)

        addVideoEffectButton = NSButton()
        addVideoEffectButton.title = "+ Add Video Effect"
        addVideoEffectButton.bezelStyle = .rounded
        addVideoEffectButton.target = self
        addVideoEffectButton.action = #selector(showVideoEffectMenu)
        addVideoEffectButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(addVideoEffectButton)

        // Audio Effects section
        audioLabel = NSTextField(labelWithString: "Audio Effects:")
        audioLabel.font = NSFont.boldSystemFont(ofSize: 13)
        audioLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(audioLabel)

        audioEffectsScrollView = NSScrollView()
        audioEffectsScrollView.hasVerticalScroller = true
        audioEffectsScrollView.hasHorizontalScroller = false
        audioEffectsScrollView.autohidesScrollers = true
        audioEffectsScrollView.drawsBackground = false
        audioEffectsScrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(audioEffectsScrollView)

        addAudioEffectButton = NSButton()
        addAudioEffectButton.title = "+ Add Audio Effect"
        addAudioEffectButton.bezelStyle = .rounded
        addAudioEffectButton.target = self
        addAudioEffectButton.action = #selector(showAudioEffectMenu)
        addAudioEffectButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(addAudioEffectButton)

        // Preset management buttons
        savePresetButton = NSButton()
        savePresetButton.title = "Save as Preset..."
        savePresetButton.bezelStyle = .rounded
        savePresetButton.target = self
        savePresetButton.action = #selector(saveAsPreset)
        savePresetButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(savePresetButton)

        // Action buttons
        applyButton = NSButton()
        applyButton.title = "Apply"
        applyButton.bezelStyle = .rounded
        applyButton.target = self
        applyButton.action = #selector(applyEffects)
        applyButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(applyButton)

        resetButton = NSButton()
        resetButton.title = "Reset"
        resetButton.bezelStyle = .rounded
        resetButton.target = self
        resetButton.action = #selector(resetEffects)
        resetButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(resetButton)

        setupEffectLists()
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Visual effect view
            visualEffectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            visualEffectView.trailingAnchor.constraint(equalTo: trailingAnchor),
            visualEffectView.topAnchor.constraint(equalTo: topAnchor),
            visualEffectView.bottomAnchor.constraint(equalTo: bottomAnchor),

            // Preset label and dropdown
            presetLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            presetLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),

            presetPopupButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            presetPopupButton.topAnchor.constraint(equalTo: presetLabel.bottomAnchor, constant: 8),
            presetPopupButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            presetPopupButton.heightAnchor.constraint(equalToConstant: 30),

            // Video effects section
            videoLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            videoLabel.topAnchor.constraint(equalTo: presetPopupButton.bottomAnchor, constant: 20),

            videoEffectsScrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            videoEffectsScrollView.topAnchor.constraint(equalTo: videoLabel.bottomAnchor, constant: 8),
            videoEffectsScrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            videoEffectsScrollView.heightAnchor.constraint(equalToConstant: 150),

            addVideoEffectButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            addVideoEffectButton.topAnchor.constraint(equalTo: videoEffectsScrollView.bottomAnchor, constant: 8),

            // Audio effects section
            audioLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            audioLabel.topAnchor.constraint(equalTo: addVideoEffectButton.bottomAnchor, constant: 20),

            audioEffectsScrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            audioEffectsScrollView.topAnchor.constraint(equalTo: audioLabel.bottomAnchor, constant: 8),
            audioEffectsScrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            audioEffectsScrollView.heightAnchor.constraint(equalToConstant: 150),

            addAudioEffectButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            addAudioEffectButton.topAnchor.constraint(equalTo: audioEffectsScrollView.bottomAnchor, constant: 8),

            // Preset management buttons
            savePresetButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            savePresetButton.topAnchor.constraint(equalTo: addAudioEffectButton.bottomAnchor, constant: 20),

            // Action buttons
            applyButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            applyButton.topAnchor.constraint(equalTo: savePresetButton.bottomAnchor, constant: 16),
            applyButton.trailingAnchor.constraint(equalTo: centerXAnchor, constant: -8),
            applyButton.heightAnchor.constraint(equalToConstant: 32),

            resetButton.leadingAnchor.constraint(equalTo: centerXAnchor, constant: 8),
            resetButton.topAnchor.constraint(equalTo: applyButton.topAnchor),
            resetButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            resetButton.heightAnchor.constraint(equalToConstant: 32)
        ])
    }

    private func setupEffectLists() {
        reloadEffectsLists()
    }

    // MARK: - UI Population

    private func populatePresetMenu() {
        presetPopupButton.removeAllItems()

        // Add "None" option
        presetPopupButton.addItem(withTitle: "None")

        // Add built-in presets
        for preset in EffectStack.builtInPresets {
            presetPopupButton.addItem(withTitle: preset.name)
        }

        // Add custom presets
        for preset in customPresets {
            presetPopupButton.addItem(withTitle: preset.name)
        }

        // Select current preset if any
        if let selectedPreset = editorState.effectStack.selectedPreset {
            let index = presetPopupButton.indexOfItem(withTitle: selectedPreset.name)
            if index != -1 {
                presetPopupButton.selectItem(at: index)
            }
        } else {
            presetPopupButton.selectItem(withTitle: "None")
        }
    }

    private func reloadEffectsLists() {
        // Clear existing subviews
        videoEffectsScrollView.documentView?.removeFromSuperview()
        audioEffectsScrollView.documentView?.removeFromSuperview()

        // Create scroll views with proper clip views
        let videoContainer = NSView()
        videoEffectsScrollView.documentView = videoContainer

        let audioContainer = NSView()
        audioEffectsScrollView.documentView = audioContainer

        var yOffset: CGFloat = 0

        // Video effects
        for effect in editorState.effectStack.videoEffects {
            let effectView = createEffectView(effect: effect, isVideo: true)
            effectView.frame.origin = NSPoint(x: 0, y: yOffset)
            videoContainer.addSubview(effectView)
            yOffset += effectView.frame.height + 8
        }

        videoContainer.frame = NSRect(x: 0, y: 0, width: videoEffectsScrollView.bounds.width, height: yOffset)
        videoContainer.autoresizingMask = [.width]

        yOffset = 0

        // Audio effects
        for effect in editorState.effectStack.audioEffects {
            let effectView = createEffectView(effect: effect, isVideo: false)
            effectView.frame.origin = NSPoint(x: 0, y: yOffset)
            audioContainer.addSubview(effectView)
            yOffset += effectView.frame.height + 8
        }

        audioContainer.frame = NSRect(x: 0, y: 0, width: audioEffectsScrollView.bounds.width, height: yOffset)
        audioContainer.autoresizingMask = [.width]
    }

    private func createEffectView(effect: Any, isVideo: Bool) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        // Effect name label
        let nameLabel = NSTextField()
        nameLabel.isEditable = false
        nameLabel.isBordered = false
        nameLabel.backgroundColor = .clear
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        // Enable/disable checkbox
        let enableCheckbox = NSButton(checkboxWithTitle: "Enable", target: self, action: #selector(toggleEffectEnabled))
        enableCheckbox.identifier = NSUserInterfaceItemIdentifier("enableCheckbox")
        enableCheckbox.translatesAutoresizingMaskIntoConstraints = false

        // Value slider
        let valueSlider = NSSlider()
        valueSlider.target = self
        valueSlider.action = #selector(sliderValueChanged)
        valueSlider.identifier = NSUserInterfaceItemIdentifier("valueSlider")
        valueSlider.minValue = 0.0
        valueSlider.maxValue = 1.0
        valueSlider.doubleValue = 0.5
        valueSlider.translatesAutoresizingMaskIntoConstraints = false

        // Value label
        let valueLabel = NSTextField()
        valueLabel.isEditable = false
        valueLabel.isBordered = false
        valueLabel.backgroundColor = .clear
        valueLabel.translatesAutoresizingMaskIntoConstraints = false

        // Remove button
        let removeButton = NSButton()
        removeButton.title = "×"
        removeButton.bezelStyle = .circular
        removeButton.target = self
        removeButton.action = #selector(removeEffect)
        removeButton.translatesAutoresizingMaskIntoConstraints = false

        // Configure based on effect type
        if isVideo, let videoEffect = effect as? VideoEffect {
            nameLabel.stringValue = "\(videoEffect.type.rawValue.capitalized)"

            switch videoEffect.parameters {
            case .brightness(let value):
                valueSlider.minValue = -1.0
                valueSlider.maxValue = 1.0
                valueSlider.doubleValue = value
                valueLabel.stringValue = String(format: "%.2f", value)
            case .contrast(let value):
                valueSlider.minValue = 0.0
                valueSlider.maxValue = 4.0
                valueSlider.doubleValue = value
                valueLabel.stringValue = String(format: "%.2f", value)
            case .saturation(let value):
                valueSlider.minValue = 0.0
                valueSlider.maxValue = 2.0
                valueSlider.doubleValue = value
                valueLabel.stringValue = String(format: "%.2f", value)
            }

            enableCheckbox.state = videoEffect.isEnabled ? .on : .off

            // Store effect reference
            enableCheckbox.identifier = NSUserInterfaceItemIdentifier("enableVideo_\(videoEffect.id)")
            valueSlider.identifier = NSUserInterfaceItemIdentifier("valueVideo_\(videoEffect.id)")
            removeButton.identifier = NSUserInterfaceItemIdentifier("removeVideo_\(videoEffect.id)")
        } else if !isVideo, let audioEffect = effect as? AudioEffect {
            nameLabel.stringValue = "\(audioEffect.type.rawValue.capitalized)"

            switch audioEffect.parameters {
            case .volumeNormalization(let targetLUFS):
                valueSlider.minValue = -60.0
                valueSlider.maxValue = 0.0
                valueSlider.doubleValue = targetLUFS
                valueLabel.stringValue = String(format: "%.1f dB", targetLUFS)
            case .equalizer(let bass, let treble):
                valueSlider.minValue = -12.0
                valueSlider.maxValue = 12.0
                valueSlider.doubleValue = (bass + treble) / 2
                valueLabel.stringValue = String(format: "%.1f dB", valueSlider.doubleValue)
            }

            enableCheckbox.state = audioEffect.isEnabled ? .on : .off

            // Store effect reference
            enableCheckbox.identifier = NSUserInterfaceItemIdentifier("enableAudio_\(audioEffect.id)")
            valueSlider.identifier = NSUserInterfaceItemIdentifier("valueAudio_\(audioEffect.id)")
            removeButton.identifier = NSUserInterfaceItemIdentifier("removeAudio_\(audioEffect.id)")
        }

        // Add subviews
        container.addSubview(nameLabel)
        container.addSubview(enableCheckbox)
        container.addSubview(valueSlider)
        container.addSubview(valueLabel)
        container.addSubview(removeButton)

        // Layout constraints
        NSLayoutConstraint.activate([
            nameLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            nameLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            nameLabel.widthAnchor.constraint(equalToConstant: 120),

            enableCheckbox.leadingAnchor.constraint(equalTo: nameLabel.trailingAnchor, constant: 8),
            enableCheckbox.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            enableCheckbox.widthAnchor.constraint(equalToConstant: 50),

            valueSlider.leadingAnchor.constraint(equalTo: enableCheckbox.trailingAnchor, constant: 8),
            valueSlider.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            valueSlider.widthAnchor.constraint(equalToConstant: 120),

            valueLabel.leadingAnchor.constraint(equalTo: valueSlider.trailingAnchor, constant: 8),
            valueLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            valueLabel.widthAnchor.constraint(equalToConstant: 50),

            removeButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            removeButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            removeButton.widthAnchor.constraint(equalToConstant: 30),
            removeButton.heightAnchor.constraint(equalToConstant: 30),

            container.heightAnchor.constraint(equalToConstant: 40)
        ])

        return container
    }

    // MARK: - Actions

    @objc private func presetChanged(_ sender: NSPopUpButton) {
        guard let presetName = sender.selectedItem?.title,
              presetName != "None" else {
            editorState.effectStack.selectedPreset = nil
            return
        }

        // Find preset
        let preset = EffectStack.builtInPresets.first { $0.name == presetName }
            ?? customPresets.first { $0.name == presetName }

        if let preset = preset {
            editorState.effectStack.applyPreset(preset)
            reloadEffectsLists()
        }
    }

    @objc private func showVideoEffectMenu(_ sender: NSButton?) {
        let menu = NSMenu()

        menu.addItem(withTitle: "Brightness", action: #selector(addBrightnessEffect), keyEquivalent: "")
        menu.addItem(withTitle: "Contrast", action: #selector(addContrastEffect), keyEquivalent: "")
        menu.addItem(withTitle: "Saturation", action: #selector(addSaturationEffect), keyEquivalent: "")

        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender?.bounds.height ?? 0), in: sender)
    }

    @objc private func showAudioEffectMenu(_ sender: NSButton?) {
        let menu = NSMenu()

        menu.addItem(withTitle: "Volume Normalization", action: #selector(addVolumeNormalizationEffect), keyEquivalent: "")
        menu.addItem(withTitle: "EQ (Bass/Treble)", action: #selector(addEQEffect), keyEquivalent: "")

        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender?.bounds.height ?? 0), in: sender)
    }

    @objc private func addBrightnessEffect() {
        let effect = VideoEffect(type: .brightness, parameters: .brightness(0.0))
        editorState.effectStack.videoEffects.append(effect)
        reloadEffectsLists()
    }

    @objc private func addContrastEffect() {
        let effect = VideoEffect(type: .contrast, parameters: .contrast(1.0))
        editorState.effectStack.videoEffects.append(effect)
        reloadEffectsLists()
    }

    @objc private func addSaturationEffect() {
        let effect = VideoEffect(type: .saturation, parameters: .saturation(1.0))
        editorState.effectStack.videoEffects.append(effect)
        reloadEffectsLists()
    }

    @objc private func addVolumeNormalizationEffect() {
        let effect = AudioEffect(type: .volumeNormalization, parameters: .withVolumeNormalization(-16.0))
        editorState.effectStack.audioEffects.append(effect)
        reloadEffectsLists()
    }

    @objc private func addEQEffect() {
        let effect = AudioEffect(type: .equalizer, parameters: .withEqualizer(bass: 0.0, treble: 0.0))
        editorState.effectStack.audioEffects.append(effect)
        reloadEffectsLists()
    }

    @objc private func toggleEffectEnabled(_ sender: NSButton) {
        guard let identifier = sender.identifier else { return }
        let uuidString = identifier.rawValue.components(separatedBy: "_").last ?? ""

        guard let uuid = UUID(uuidString: uuidString) else { return }

        // Find and update effect
        for (index, effect) in editorState.effectStack.videoEffects.enumerated() {
            if effect.id == uuid {
                var updatedEffect = effect
                updatedEffect.isEnabled = sender.state == .on
                editorState.effectStack.videoEffects[index] = updatedEffect
                break
            }
        }

        for (index, effect) in editorState.effectStack.audioEffects.enumerated() {
            if effect.id == uuid {
                var updatedEffect = effect
                updatedEffect.isEnabled = sender.state == .on
                editorState.effectStack.audioEffects[index] = updatedEffect
                break
            }
        }
    }

    @objc private func sliderValueChanged(_ sender: NSSlider) {
        guard let identifier = sender.identifier else { return }
        let uuidString = identifier.rawValue.components(separatedBy: "_").last ?? ""

        guard let uuid = UUID(uuidString: uuidString) else { return }

        let value = sender.doubleValue

        // Update video effects
        for (index, effect) in editorState.effectStack.videoEffects.enumerated() {
            if effect.id == uuid {
                var updatedEffect = effect
                switch effect.parameters {
                case .brightness:
                    updatedEffect.parameters = .brightness(value)
                case .contrast:
                    updatedEffect.parameters = .contrast(value)
                case .saturation:
                    updatedEffect.parameters = .saturation(value)
                }
                editorState.effectStack.videoEffects[index] = updatedEffect
                break
            }
        }

        // Update audio effects
        for (index, effect) in editorState.effectStack.audioEffects.enumerated() {
            if effect.id == uuid {
                var updatedEffect = effect
                switch effect.parameters {
                case .volumeNormalization:
                    updatedEffect.parameters = .withVolumeNormalization(value)
                case .equalizer:
                    updatedEffect.parameters = .withEqualizer(bass: value, treble: value)
                }
                editorState.effectStack.audioEffects[index] = updatedEffect
                break
            }
        }
    }

    @objc private func removeEffect(_ sender: NSButton) {
        guard let identifier = sender.identifier else { return }
        let uuidString = identifier.rawValue.components(separatedBy: "_").last ?? ""

        guard let uuid = UUID(uuidString: uuidString) else { return }

        // Remove from video effects
        editorState.effectStack.videoEffects.removeAll { $0.id == uuid }

        // Remove from audio effects
        editorState.effectStack.audioEffects.removeAll { $0.id == uuid }

        reloadEffectsLists()
    }

    @objc private func saveAsPreset() {
        let alert = NSAlert()
        alert.messageText = "Save Preset"
        alert.informativeText = "Enter a name for this preset:"
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        textField.placeholderString = "My Preset"
        alert.accessoryView = textField

        let response = alert.runModal()

        if response == .alertFirstButtonReturn, !textField.stringValue.isEmpty {
            do {
                try editorState.effectStack.saveAsPreset(name: textField.stringValue)
                loadCustomPresets()
                populatePresetMenu()
            } catch {
                showErrorAlert(message: "Failed to save preset: \(error.localizedDescription)")
            }
        }
    }

    @objc private func applyEffects(_ sender: NSButton?) {
        // Trigger export with effects
        NotificationCenter.default.post(name: .applyEffects, object: nil)
    }

    @objc private func resetEffects(_ sender: NSButton?) {
        editorState.effectStack.videoEffects.removeAll()
        editorState.effectStack.audioEffects.removeAll()
        editorState.effectStack.selectedPreset = nil
        presetPopupButton.selectItem(withTitle: "None")
        reloadEffectsLists()
    }

    // MARK: - Helper Methods

    private func loadCustomPresets() {
        do {
            let storage = PresetStorage()
            customPresets = try storage.loadCustomPresets()
        } catch {
            print("Failed to load custom presets: \(error)")
        }
    }

    private func setupObservations() {
        // Observe effect stack changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(editorStateChanged),
            name: .effectStackDidChange,
            object: editorState
        )
    }

    @objc private func editorStateChanged() {
        reloadEffectsLists()
    }

    @objc private func effectStackChanged() {
        reloadEffectsLists()
    }

    private func showErrorAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let applyEffects = Notification.Name("applyEffects")
    static let effectStackChanged = Notification.Name("effectStackChanged")
}