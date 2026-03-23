import AppKit
import AVFoundation
import CoreVideo
import CoreMedia
import Metal

/// Editor window controller with split view layout
@MainActor
final class EditorWindowController: NSWindowController, PlaybackControlsDelegate {
    let editorState: EditorState
    private var splitViewController: NSSplitViewController?
    private var videoPreview: VideoPreview?
    private var effectsPanel: EffectsPanel?
    var rightPanelView: NSView? // Exposed for testing
    var timelineView: TimelineView! // Exposed for testing
    var playbackControls: PlaybackControls! // Exposed for testing
    private nonisolated(unsafe) var videoProcessor: VideoProcessor?
    private var metalRenderer: MetalRenderer?
    private nonisolated(unsafe) var displayLink: CVDisplayLink?
    private var textureCache: CVMetalTextureCache?

    init(recordingURL: URL) {
        EditorState.initializeShared(with: recordingURL)
        self.editorState = EditorState.shared
        super.init(window: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        stopDisplayLink()
        videoProcessor?.cancelReading()
    }

    override func showWindow(_ sender: Any?) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "OpenScreen Editor"
        window.center()

        // Create split view
        let splitView = NSSplitViewController()
        splitView.splitView.isVertical = true
        splitView.splitView.dividerStyle = .thin

        // Left side: Video preview
        let videoPreview = VideoPreview()
        self.videoPreview = videoPreview
        let videoViewController = NSViewController()
        videoViewController.view = videoPreview
        let videoSplitItem = NSSplitViewItem(viewController: videoViewController)
        splitView.addSplitViewItem(videoSplitItem)

        // Middle: Timeline and playback controls
        let rightPanel = NSView()
        rightPanel.wantsLayer = true
        rightPanel.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        // Create timeline view
        let timelineView = TimelineView(frame: .zero)
        timelineView.translatesAutoresizingMaskIntoConstraints = false
        rightPanel.addSubview(timelineView)

        // Create playback controls
        let playbackControls = PlaybackControls(frame: .zero)
        playbackControls.delegate = self
        playbackControls.translatesAutoresizingMaskIntoConstraints = false
        rightPanel.addSubview(playbackControls)

        // Layout constraints for timeline and controls
        NSLayoutConstraint.activate([
            timelineView.topAnchor.constraint(equalTo: rightPanel.topAnchor, constant: 8),
            timelineView.leadingAnchor.constraint(equalTo: rightPanel.leadingAnchor, constant: 8),
            timelineView.trailingAnchor.constraint(equalTo: rightPanel.trailingAnchor, constant: -8),
            timelineView.heightAnchor.constraint(equalToConstant: 200),

            playbackControls.topAnchor.constraint(equalTo: timelineView.bottomAnchor, constant: 8),
            playbackControls.leadingAnchor.constraint(equalTo: rightPanel.leadingAnchor, constant: 8),
            playbackControls.trailingAnchor.constraint(equalTo: rightPanel.trailingAnchor, constant: -8),
            playbackControls.heightAnchor.constraint(equalToConstant: 44)
        ])

        let rightViewController = NSViewController()
        rightViewController.view = rightPanel
        let rightSplitItem = NSSplitViewItem(viewController: rightViewController)
        splitView.addSplitViewItem(rightSplitItem)

        // Right side: Effects panel
        let effectsPanel = EffectsPanel(editorState: editorState)
        self.effectsPanel = effectsPanel
        let effectsViewController = NSViewController()
        effectsViewController.view = effectsPanel
        let effectsSplitItem = NSSplitViewItem(viewController: effectsViewController)
        splitView.addSplitViewItem(effectsSplitItem)

        self.splitViewController = splitView
        self.videoPreview = videoPreview
        self.rightPanelView = rightPanel
        self.timelineView = timelineView
        self.playbackControls = playbackControls

        window.contentViewController = splitView
        self.window = window

        // Setup keyboard shortcuts
        setupKeyboardShortcuts()

        // Observe window close for cleanup
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillClose(_:)),
            name: NSWindow.willCloseNotification,
            object: window
        )

        // Observe transition selection changes to open inspector
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(transitionSelectionDidChange(_:)),
            name: .transitionSelectionChanged,
            object: nil
        )

        // Setup video processor and start rendering
        let videoProcessor = VideoProcessor(assetURL: editorState.assetURL)
        self.videoProcessor = videoProcessor

        Task {
            do {
                try await videoProcessor.loadAsset()
                try await videoProcessor.createAssetReader()
                try videoProcessor.startReading()

                // Update editor state with video duration
                if let assetDuration = videoProcessor.asset?.duration {
                    editorState.duration = assetDuration
                    let durationSeconds = CMTimeGetSeconds(assetDuration)
                    playbackControls.updateMaxPosition(durationSeconds)
                }

                // Get first frame and setup renderer
                if let firstFrame = videoProcessor.getNextFrame() {
                    self.setupMetalAndRender(firstFrame: firstFrame)
                }

                // Generate waveform and thumbnails
                self.generateTimelineData()
            } catch {
                print("❌ Failed to load video: \(error)")
            }
        }

        window.makeKeyAndOrderFront(sender)
    }

    // MARK: - Video Rendering

    private func setupMetalAndRender(firstFrame: CMSampleBuffer) {
        guard let videoPreview = videoPreview,
              let device = videoPreview.device else {
            return
        }

        // Create renderer
        let renderer = MetalRenderer(device: device)
        self.metalRenderer = renderer

        // Setup texture cache
        let result = CVMetalTextureCacheCreate(
            kCFAllocatorDefault,
            nil,
            device,
            nil,
            &textureCache
        )
        guard result == kCVReturnSuccess else {
            print("❌ Failed to create texture cache")
            return
        }

        do {
            try renderer.setupPipeline(view: videoPreview)

            // Create texture from first frame
            do {
                let texture = try createTexture(from: firstFrame)
                renderer.render(texture: texture, in: videoPreview)
            } catch {
                print("❌ Failed to create first texture: \(error)")
            }
        } catch {
            print("❌ Failed to setup renderer: \(error)")
        }

        // Start 60fps rendering loop
        setupDisplayLink()
    }

    private func createTexture(from sampleBuffer: CMSampleBuffer) throws -> MTLTexture {
        guard let cache = textureCache else {
            throw RenderingError.textureCacheNotAvailable
        }
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            throw RenderingError.invalidSampleBuffer
        }

        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)

        var textureRef: CVMetalTexture?
        let result = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            cache,
            imageBuffer,
            nil,
            .bgra8Unorm,
            width,
            height,
            0,
            &textureRef
        )

        guard result == kCVReturnSuccess,
              let metalTexture = textureRef else {
            throw RenderingError.textureCreationFailed
        }

        guard let texture = CVMetalTextureGetTexture(metalTexture) else {
            throw RenderingError.textureReferenceFailed
        }

        return texture
    }

    private func setupDisplayLink() {
        var displayLink: CVDisplayLink?
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)

        let userInfoPtr = Unmanaged.passUnretained(self).toOpaque()

        CVDisplayLinkSetOutputCallback(
            displayLink!,
            { (_, _, _, _, _, userInfo) -> CVReturn in
            let controller = Unmanaged<EditorWindowController>.fromOpaque(userInfo!).takeUnretainedValue()
            Task { @MainActor in
                await controller.renderNextFrame()
            }
            return kCVReturnSuccess
        },
            userInfoPtr
        )

        self.displayLink = displayLink
        CVDisplayLinkStart(displayLink!)
    }

    nonisolated private func stopDisplayLink() {
        if let link = displayLink {
            CVDisplayLinkStop(link)
        }
        displayLink = nil
    }

    func renderNextFrame() async {
        guard editorState.isPlaying,
              let processor = videoProcessor,
              let renderer = metalRenderer,
              let preview = videoPreview,
              let nextFrame = processor.getNextFrame() else {
            return
        }

        do {
            let texture = try createTexture(from: nextFrame)
            renderer.render(texture: texture, in: preview)

            // Update playback position
            let presentationTime = CMSampleBufferGetPresentationTimeStamp(nextFrame)
            editorState.currentTime = presentationTime
            let timeSeconds = CMTimeGetSeconds(presentationTime)
            timelineView.seek(to: timeSeconds)
            playbackControls.updatePosition(to: timeSeconds)
        } catch {
            print("⚠️ Failed to create texture: \(error)")
        }
    }

    // MARK: - Window Lifecycle

    @objc private func windowWillClose(_ notification: Notification) {
        stopDisplayLink()
        videoProcessor?.cancelReading()
    }

    // MARK: - Keyboard Shortcuts

    private func setupKeyboardShortcuts() {
        guard let window = self.window else { return }

        // Create key press handler
        let monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            return self?.handleKeyDown(event) ?? event
        }

        // Store monitor for cleanup (optional - window closure handles it)
    }

    private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
        guard let window = self.window,
              window.isKeyWindow else {
            return event
        }

        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // Space: Play/Pause
        if event.keyCode == 49 && modifiers.isEmpty { // Space key
            playbackControls.playPause(nil)
            return nil // Consume the event
        }

        // Escape: Stop
        if event.keyCode == 53 && modifiers.isEmpty { // Escape key
            playbackControls.stop(nil)
            return nil
        }

        // Left arrow: Seek backward
        if event.keyCode == 123 && modifiers.isEmpty {
            playbackControls.seekBackward(nil)
            return nil
        }

        // Right arrow: Seek forward
        if event.keyCode == 124 && modifiers.isEmpty {
            playbackControls.seekForward(nil)
            return nil
        }

        // Cmd+Left arrow: Seek to beginning
        if event.keyCode == 123 && modifiers.contains(.command) {
            playbackControls.updatePosition(to: 0.0)
            return nil
        }

        // Cmd+Right arrow: Seek to end
        if event.keyCode == 124 && modifiers.contains(.command) {
            let duration = CMTimeGetSeconds(editorState.duration)
            playbackControls.updatePosition(to: duration)
            return nil
        }

        // Cmd+Up arrow: Step forward one frame
        if event.keyCode == 126 && modifiers.contains(.command) {
            Task {
                await editorState.stepForward()
            }
            return nil
        }

        // Cmd+Down arrow: Step backward one frame
        if event.keyCode == 125 && modifiers.contains(.command) {
            Task {
                await editorState.stepBackward()
            }
            return nil
        }

        // Cmd+Opt+T: Show transition picker
        if event.charactersIgnoringModifiers == "t" &&
           modifiers.contains(.command) &&
           modifiers.contains(.option) {
            handleTransitionPickerShortcut()
            return nil
        }

        return event // Don't consume other key events
    }

    // MARK: - Transition Picker Shortcut

    /// Handles Cmd+Opt+T shortcut to show transition picker
    private func handleTransitionPickerShortcut() {
        // Get selected clip IDs from timeline view
        guard let selectedClipIDs = timelineView.viewModel?.selectedClipIDs,
              selectedClipIDs.count == 2 else {
            showTransitionShortcutError(message: "Please select exactly 2 clips to add a transition.")
            return
        }

        // Get the two selected clips
        let clipIDs = Array(selectedClipIDs)
        guard let clip1 = editorState.clipTracks.first(where: { $0.clips.contains(where: { $0.id == clipIDs[0] }) })?.clips.first(where: { $0.id == clipIDs[0] }),
              let clip2 = editorState.clipTracks.first(where: { $0.clips.contains(where: { $0.id == clipIDs[1] }) })?.clips.first(where: { $0.id == clipIDs[1] }) else {
            showTransitionShortcutError(message: "Could not find the selected clips.")
            return
        }

        // Check if clips overlap
        let detector = ClipOverlapDetector()
        guard let overlap = detector.findOverlap(between: clipIDs[0], and: clipIDs[1], in: editorState.clipTracks.flatMap { $0.clips }) else {
            showTransitionShortcutError(message: "Selected clips must overlap to create a transition.")
            return
        }

        // Check if transition already exists
        if let existingTransition = editorState.transitions.first(where: { transition in
            (transition.leadingClipID == clipIDs[0] && transition.trailingClipID == clipIDs[1]) ||
            (transition.leadingClipID == clipIDs[1] && transition.trailingClipID == clipIDs[0])
        }) {
            // Select existing transition instead of creating new one
            timelineView.viewModel?.selectTransition(existingTransition.id)
            print("ℹ️ Selected existing transition: \(existingTransition.id)")
            return
        }

        // Show transition picker at cursor location
        showTransitionPicker(at: NSEvent.mouseLocation, leadingClip: clip1, trailingClip: clip2, overlap: overlap.overlapDuration)
    }

    /// Shows error alert for transition shortcut
    private func showTransitionShortcutError(message: String) {
        let alert = NSAlert()
        alert.messageText = "Cannot Add Transition"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    /// Shows transition picker menu at cursor location
    private func showTransitionPicker(at point: CGPoint, leadingClip: VideoClip, trailingClip: VideoClip, overlap: CMTime) {
        let menu = NSMenu(title: "Add Transition")

        // Add transition type options
        for transitionType in TransitionType.allCases {
            let item = NSMenuItem(title: transitionType.displayName, action: #selector(createTransitionFromMenu(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = TransitionPickerInfo(
                leadingClipID: leadingClip.id,
                trailingClipID: trailingClip.id,
                type: transitionType,
                overlap: overlap
            )
            menu.addItem(item)
        }

        // Add separator
        menu.addItem(NSMenuItem.separator())

        // Add cancel option
        let cancelItem = NSMenuItem(title: "Cancel", action: nil, keyEquivalent: "")
        menu.addItem(cancelItem)

        // Show menu at cursor location
        let screenFrame = window?.screen?.frame ?? .zero
        let invertedY = screenFrame.height - point.y
        menu.popUp(positioning: nil, at: CGPoint(x: point.x, y: invertedY), in: nil)
    }

    /// Creates transition from menu selection
    @objc private func createTransitionFromMenu(_ sender: NSMenuItem) {
        guard let info = sender.representedObject as? TransitionPickerInfo else {
            return
        }

        // Create transition using factory
        guard let transition = TransitionFactory.createTransition(
            type: info.type,
            between: info.leadingClipID,
            and: info.trailingClipID,
            in: editorState
        ) else {
            print("❌ Failed to create transition: insufficient overlap or invalid clips")
            return
        }

        // Add transition to editor state
        editorState.addTransition(transition)

        // Select the newly created transition
        editorState.selectedTransitionID = transition.id

        print("✅ Created transition: \(info.type.displayName) between clips")
    }

    /// Information needed to create transition from picker menu
    private struct TransitionPickerInfo {
        let leadingClipID: UUID
        let trailingClipID: UUID
        let type: TransitionType
        let overlap: CMTime
    }

    // MARK: - Timeline Data Generation

    private func generateTimelineData() {
        Task {
            // Generate audio waveform (simplified - empty for now)
            await MainActor.run {
                timelineView.setWaveform([])
            }

            // Update timeline with track layouts
            let videoTrack = TimelineTrack(id: UUID(), type: .video, name: "Video", height: 120)
            let audioTrack = TimelineTrack(id: UUID(), type: .audio, name: "Audio", height: 60)
            let trackLayouts = [
                TrackLayout(track: videoTrack, frame: .zero, thumbnailPositions: [:]),
                TrackLayout(track: audioTrack, frame: .zero, thumbnailPositions: [:])
            ]
            await MainActor.run {
                timelineView.setTrackLayouts(trackLayouts)
            }
        }
    }

    // MARK: - Inspector

    /// Handles transition selection change notification
    @objc private func transitionSelectionDidChange(_ notification: Notification) {
        guard let transitionID = notification.userInfo?["transitionID"] as? UUID else {
            // Transition was deselected, do nothing
            return
        }

        // Open inspector for selected transition
        showTransitionInspector(for: transitionID)
    }

    /// Opens the transition inspector as a sheet
    /// - Parameter transitionID: ID of transition to inspect
    func showTransitionInspector(for transitionID: UUID) {
        guard let transition = editorState.transitions.first(where: { $0.id == transitionID }) else {
            print("⚠️ Transition not found: \(transitionID)")
            return
        }

        let inspector = TransitionInspectorViewController(
            transition: transition,
            onApply: { [weak self] updatedTransition in
                // Update the transition in editor state
                self?.editorState.updateTransition(updatedTransition)
            },
            onDelete: { [weak self] in
                // Delete the transition from editor state
                self?.editorState.removeTransition(id: transitionID)
            }
        )

        inspector.preferredContentSize = NSSize(width: 400, height: 500)

        // Present as sheet on the window
        guard let window = self.window else { return }

        // Create a sheet window for the view controller
        let sheetWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        sheetWindow.contentViewController = inspector

        window.beginSheet(sheetWindow) { [weak self] response in
            guard let self = self, response == .OK else {
                return
            }

            // Update editor state if changed
            self.editorState.objectWillChange.send()
        }
    }

    enum RenderingError: LocalizedError {
        case deviceNotAvailable
        case textureCacheNotAvailable
        case invalidSampleBuffer
        case textureCreationFailed
        case textureReferenceFailed

        var errorDescription: String? {
            switch self {
            case .deviceNotAvailable:
                return "Metal device not available"
            case .textureCacheNotAvailable:
                return "Texture cache not available"
            case .invalidSampleBuffer:
                return "Invalid sample buffer"
            case .textureCreationFailed:
                return "Failed to create Metal texture"
            case .textureReferenceFailed:
                return "Failed to get Metal texture reference"
            }
        }
    }
}

// MARK: - PlaybackControlsDelegate

extension EditorWindowController {
    func playbackControlsDidPlay(_ controls: PlaybackControls) {
        editorState.isPlaying = true
        print("▶️ Playback started")
    }

    func playbackControlsDidPause(_ controls: PlaybackControls) {
        editorState.isPlaying = false
        print("⏸️ Playback paused")
    }

    func playbackControlsDidStop(_ controls: PlaybackControls) {
        editorState.isPlaying = false
        editorState.currentTime = .zero
        timelineView.seek(to: 0.0)
        print("⏹️ Playback stopped")
    }

    func playbackControls(_ controls: PlaybackControls, didSeekBy amount: Double) {
        let currentTime = CMTimeGetSeconds(editorState.currentTime)
        let newPosition = currentTime + amount
        updatePlaybackPosition(to: newPosition)
        print("⏩ Seeked by \(amount)s")
    }

    func playbackControls(_ controls: PlaybackControls, didUpdatePosition position: Double) {
        updatePlaybackPosition(to: position)
    }

    private func updatePlaybackPosition(to position: Double) {
        let durationSeconds = CMTimeGetSeconds(editorState.duration)
        let clampedPosition = max(0.0, min(position, durationSeconds))
        let cmTime = CMTime(seconds: clampedPosition, preferredTimescale: 600)
        editorState.currentTime = cmTime
        timelineView.seek(to: clampedPosition)

        // Seek video processor
        Task {
            let seekTime = CMTime(seconds: clampedPosition, preferredTimescale: 600)
            try? await videoProcessor?.seek(to: seekTime)
        }
    }

    // MARK: - Extended PlaybackControlsDelegate Methods

    func playbackControlsDidStepForward(_ controls: PlaybackControls) {
        print("⏭️ Step forward")
        Task {
            await editorState.stepForward()
        }
    }

    func playbackControlsDidStepBackward(_ controls: PlaybackControls) {
        print("⏮️ Step backward")
        Task {
            await editorState.stepBackward()
        }
    }

    func playbackControlsSetLoopStart(_ controls: PlaybackControls) {
        print("🔁 Set loop start")
        let currentTime = CMTimeGetSeconds(editorState.currentTime)
        editorState.loopStart = CMTime(seconds: currentTime, preferredTimescale: 600)
    }

    func playbackControlsSetLoopEnd(_ controls: PlaybackControls) {
        print("🔁 Set loop end")
        let currentTime = CMTimeGetSeconds(editorState.currentTime)
        editorState.loopEnd = CMTime(seconds: currentTime, preferredTimescale: 600)
    }

    func playbackControlsClearLoop(_ controls: PlaybackControls) {
        print("🔁 Clear loop")
        editorState.loopStart = nil
        editorState.loopEnd = nil
    }
}
