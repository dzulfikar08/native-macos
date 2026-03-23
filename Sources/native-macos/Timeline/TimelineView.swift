import AppKit
import Metal
import MetalKit
import AVFoundation
import CoreMedia

/// Delegate for in/out point callbacks in TimelineView
@MainActor
protocol TimelineViewInOutPointDelegate: AnyObject {
    /// Called when in point is set
    func timelineViewDidSetInPoint(_ timeline: TimelineView, time: Double)

    /// Called when out point is set
    func timelineViewDidSetOutPoint(_ timeline: TimelineView, time: Double)

    /// Called when in/out points are cleared
    func timelineViewDidClearInOutPoints(_ timeline: TimelineView)

    /// Called when focus mode is toggled
    func timelineViewDidToggleFocusMode(_ timeline: TimelineView, isFocused: Bool)

    /// Called when timeline is seeking (for keyboard shortcuts)
    func timelineViewDidSeek(_ timeline: TimelineView, amount: Double)

    /// Called when play/pause is triggered (for keyboard shortcuts)
    func timelineViewDidPlayPause(_ timeline: TimelineView)
}

/// Timeline view for displaying video waveform, playback position, loop regions, and chapter markers
@MainActor
final class TimelineView: MTKView {
    // MARK: - Properties

    /// Delegate for in/out point callbacks
    weak var inOutPointDelegate: TimelineViewInOutPointDelegate?

    /// Content offset for scrolling
    var contentOffset: CGPoint = .zero {
        didSet {
            needsDisplay = true
        }
    }

    /// Content scale for zooming
    var contentScale: CGFloat = 1.0 {
        didSet {
            needsDisplay = true
        }
    }

    /// Current playback position in seconds
    var currentTime: Double = 0.0 {
        didSet {
            needsDisplay = true
        }
    }

    /// Whether to show frame-level ticks in the time ruler
    var showFrameTicks: Bool = false {
        didSet {
            needsDisplay = true
        }
    }

    /// Height of the time ruler area in points
    var timeRulerHeight: CGFloat {
        return min(30.0, bounds.height * 0.15)
    }

    /// Major tick interval in seconds (adjusts based on scale)
    var majorTickInterval: Double {
        // Calculate appropriate interval based on scale
        let baseInterval: Double = 1.0 // 1 second
        let scaledInterval = baseInterval / Double(contentScale)

        // Round to nice numbers (0.5, 1, 2, 5, 10, etc.)
        let magnitude = pow(10.0, floor(log10(scaledInterval)))
        let normalized = scaledInterval / magnitude

        let niceNormalized: Double
        if normalized < 1.5 {
            niceNormalized = 1.0
        } else if normalized < 3.5 {
            niceNormalized = 2.0
        } else if normalized < 7.5 {
            niceNormalized = 5.0
        } else {
            niceNormalized = 10.0
        }

        return niceNormalized * magnitude
    }

    /// Minor tick interval in seconds
    var minorTickInterval: Double {
        return majorTickInterval / 5.0
    }

    /// Frame tick interval in seconds (when showFrameTicks is true)
    var frameTickInterval: Double {
        // Assume 30 fps for frame ticks
        return 1.0 / 30.0
    }

    /// Video duration
    var duration: CMTime = CMTime.zero

    /// Visible time range
    var visibleTimeRange: ClosedRange<CMTime> = CMTime.zero...CMTime.zero

    /// Waveform data for display
    private(set) var waveform: [Double] = [] {
        didSet {
            needsDisplay = true
        }
    }

    /// Audio waveform data (alias for waveform property)
    var audioWaveform: [Double] {
        return waveform
    }

    /// Track layout information
    private(set) var trackLayouts: [TrackLayout] = [] {
        didSet {
            needsDisplay = true
        }
    }

    /// Whether the playhead is currently being dragged
    private(set) var isDraggingPlayhead: Bool = false

    /// Tolerance for playhead hit detection in points
    private var playheadHitTolerance: CGFloat = 5.0

    /// Scrub controller for variable speed scrubbing
    private var scrubController: ScrubController?

    /// Whether scrubbing is currently active
    private(set) var isScrubbing: Bool = false

    /// Current scrub speed for display
    private var currentScrubSpeed: Double = 0.0

    /// Scrub indicator overlay view
    private var scrubIndicatorView: NSView?

    /// Whether loop creation drag is active
    private var isCreatingLoop: Bool = false

    /// Loop creation drag start position
    private var loopDragStartX: CGFloat = 0.0

    /// Loop creation drag current position
    private var loopDragCurrentX: CGFloat = 0.0

    /// Loop creation preview overlay
    private var loopCreationOverlay: NSView?

    /// Focus mode animation context
    private var focusModeAnimationContext: NSAnimationContext?

    /// Loop region rendering view
    private var loopRegionView: LoopRegionView?

    /// Chapter marker track view
    private var chapterMarkerTrackView: ChapterMarkerTrackView?

    /// Effect marker track view
    private var effectMarkerTrackView: EffectMarkerTrackView?

    /// In/Out point control buttons
    private var inPointButton: NSButton!
    private var outPointButton: NSButton!
    private var clearInOutPointButton: NSButton!
    private var focusModeButton: NSButton!

    /// Focus mode state
    private var isFocusMode: Bool = false

    /// Editor state for data synchronization
    weak var editorState: EditorState?

    /// Timeline view model for drag-drop operations
    var viewModel: TimelineViewModel?

    private var commandQueue: MTLCommandQueue?
    private var renderPipelineState: MTLRenderPipelineState?

    // MARK: - Initialization

    override init(frame frameRect: NSRect, device: MTLDevice?) {
        let metalDevice = device ?? MTLCreateSystemDefaultDevice()
        super.init(frame: frameRect, device: metalDevice)

        guard let device = self.device else {
            fatalError("Metal is not available on this device")
        }

        setupMetal(device: device)
        setupGestures()
        setupInOutPointControls()
    }

    required init(coder: NSCoder) {
        let metalDevice = MTLCreateSystemDefaultDevice()
        super.init(coder: coder)
        device = metalDevice

        guard let device = self.device else {
            fatalError("Metal is not available on this device")
        }

        setupMetal(device: device)
        setupGestures()
        setupInOutPointControls()
    }

    // MARK: - Setup

    private func setupMetal(device: MTLDevice) {
        // Create command queue
        commandQueue = device.makeCommandQueue()
        assert(commandQueue != nil, "Failed to create Metal command queue")

        // Configure pixel format
        self.colorPixelFormat = .bgra8Unorm
        self.framebufferOnly = false

        // Clear color (dark background)
        self.clearColor = MTLClearColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)

        // Load shaders and create pipeline
        setupRenderPipeline(device: device)
    }

    private func setupRenderPipeline(device: MTLDevice) {
        _ = try? device.makeLibrary(source: TimelineShaders.source, options: nil)
        if false {
            print("Warning: Could not load TimelineShaders, using basic rendering")
        }

        // TODO: Create render pipeline state for advanced rendering
        // For now, we'll use basic drawing

        // Setup subview rendering after Metal is ready
        setupSubviewRendering()
    }

    private func setupGestures() {
        // TODO: Add gesture recognizers for pan and zoom
    }

    private func setupSubviewRendering() {
        setupLoopRegionRendering()
        setupChapterMarkerRendering()
        setupEffectMarkerRendering()
        setupNotificationObservers()
    }

    private func setupInOutPointControls() {
        // Create In Point button
        inPointButton = NSButton(title: "I", target: self, action: #selector(setInPoint))
        inPointButton.bezelStyle = .rounded
        inPointButton.translatesAutoresizingMaskIntoConstraints = false
        inPointButton.identifier = NSUserInterfaceItemIdentifier("inPointButton")
        inPointButton.toolTip = "Set In Point (I)"

        // Create Out Point button
        outPointButton = NSButton(title: "O", target: self, action: #selector(setOutPoint))
        outPointButton.bezelStyle = .rounded
        outPointButton.translatesAutoresizingMaskIntoConstraints = false
        outPointButton.identifier = NSUserInterfaceItemIdentifier("outPointButton")
        outPointButton.toolTip = "Set Out Point (O)"

        // Create Clear In/Out Point button
        clearInOutPointButton = NSButton(title: "Clear", target: self, action: #selector(clearInOutPoints))
        clearInOutPointButton.bezelStyle = .rounded
        clearInOutPointButton.translatesAutoresizingMaskIntoConstraints = false
        clearInOutPointButton.toolTip = "Clear In/Out Points (Cmd+Shift+C)"

        // Create Focus Mode button
        focusModeButton = NSButton(title: "Focus", target: self, action: #selector(toggleFocusMode))
        focusModeButton.bezelStyle = .rounded
        focusModeButton.translatesAutoresizingMaskIntoConstraints = false
        focusModeButton.toolTip = "Toggle Focus Mode (Cmd+F)"

        // Add subviews
        addSubview(inPointButton)
        addSubview(outPointButton)
        addSubview(clearInOutPointButton)
        addSubview(focusModeButton)

        // Layout constraints for in/out point controls at bottom of timeline
        NSLayoutConstraint.activate([
            inPointButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            inPointButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),

            outPointButton.leadingAnchor.constraint(equalTo: inPointButton.trailingAnchor, constant: 4),
            outPointButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),

            clearInOutPointButton.leadingAnchor.constraint(equalTo: outPointButton.trailingAnchor, constant: 4),
            clearInOutPointButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),

            focusModeButton.leadingAnchor.constraint(equalTo: clearInOutPointButton.trailingAnchor, constant: 8),
            focusModeButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])
    }

    private func setupLoopRegionRendering() {
        guard loopRegionView == nil else { return }

        loopRegionView = LoopRegionView(frame: bounds)
        loopRegionView?.videoDuration = duration
        loopRegionView?.contentScale = contentScale
        loopRegionView?.contentOffset = contentOffset
        loopRegionView?.delegate = self

        addSubview(loopRegionView!)
    }

    private func setupChapterMarkerRendering() {
        guard chapterMarkerTrackView == nil else { return }

        chapterMarkerTrackView = ChapterMarkerTrackView(frame: bounds)
        chapterMarkerTrackView?.videoDuration = duration
        chapterMarkerTrackView?.contentScale = contentScale
        chapterMarkerTrackView?.contentOffset = contentOffset
        chapterMarkerTrackView?.delegate = self

        addSubview(chapterMarkerTrackView!)
    }

    private func setupEffectMarkerRendering() {
        guard effectMarkerTrackView == nil else { return }

        effectMarkerTrackView = EffectMarkerTrackView(frame: bounds)
        effectMarkerTrackView?.videoDuration = duration
        effectMarkerTrackView?.contentScale = contentScale
        effectMarkerTrackView?.contentOffset = contentOffset
        effectMarkerTrackView?.delegate = self

        addSubview(effectMarkerTrackView!)
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Update subview frames when bounds change
        updateSubviewFrames()

        guard let drawable = currentDrawable,
              let renderPassDescriptor = currentRenderPassDescriptor,
              let commandBuffer = commandQueue?.makeCommandBuffer(),
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }

        // Set viewport
        let viewport = MTLViewport(
            originX: 0,
            originY: 0,
            width: Double(drawable.texture.width),
            height: Double(drawable.texture.height),
            znear: 0,
            zfar: 1
        )
        renderEncoder.setViewport(viewport)

        // Draw grid
        drawGrid(in: renderEncoder)

        // Draw waveform
        drawWaveform(in: renderEncoder)

        // Draw playhead
        drawPlayhead(in: renderEncoder)

        // Draw effect markers
        drawEffectMarkers(in: renderEncoder)

        // Draw focus mode overlay if enabled
        if isFocusMode {
            renderFocusModeOverlay(in: renderEncoder)
        }

        renderEncoder.endEncoding()

        // Present drawable
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    // MARK: - Loop Region Updates

    func updateLoopRegions() {
        guard let loopRegionView = loopRegionView,
              let editorState = editorState else { return }

        loopRegionView.videoDuration = duration
        loopRegionView.contentScale = contentScale
        loopRegionView.contentOffset = contentOffset
        loopRegionView.visibleTimeRange = visibleTimeRange

        // Sync with editor state
        loopRegionView.clearLoopRegions()
        for loopRegion in editorState.loopRegions {
            loopRegionView.addLoopRegion(loopRegion)
        }
    }

    func updateChapterMarkers() {
        guard let chapterMarkerTrackView = chapterMarkerTrackView,
              let editorState = editorState else { return }

        chapterMarkerTrackView.videoDuration = duration
        chapterMarkerTrackView.contentScale = contentScale
        chapterMarkerTrackView.contentOffset = contentOffset
        chapterMarkerTrackView.visibleTimeRange = visibleTimeRange

        // Sync with editor state - performance optimized to only render visible markers
        chapterMarkerTrackView.clearChapterMarkers()
        for chapterMarker in editorState.chapterMarkers {
            chapterMarkerTrackView.addChapterMarker(chapterMarker)
        }
    }

    func updateEffectMarkers() {
        guard let effectMarkerTrackView = effectMarkerTrackView,
              let editorState = editorState else { return }

        effectMarkerTrackView.videoDuration = duration
        effectMarkerTrackView.contentScale = contentScale
        effectMarkerTrackView.contentOffset = contentOffset
        effectMarkerTrackView.visibleTimeRange = visibleTimeRange

        // Sync with editor state - performance optimized to only render visible effect markers
        effectMarkerTrackView.clearEffectMarkers()
        for videoEffect in editorState.effectStack.videoEffects {
            if let timeRange = videoEffect.timeRange {
                effectMarkerTrackView.addEffectMarker(videoEffect)
            }
        }
    }

    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLoopRegionsDidChange),
            name: .loopRegionsDidChange,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleChapterMarkersDidChange),
            name: .chapterMarkersDidChange,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleEffectStackDidChange),
            name: .effectStackDidChange,
            object: nil
        )
    }

    @objc private func handleLoopRegionsDidChange() {
        updateLoopRegions()
    }

    @objc private func handleChapterMarkersDidChange() {
        updateChapterMarkers()
    }

    @objc private func handleEffectStackDidChange() {
        updateEffectMarkers()
    }

    private func drawGrid(in encoder: MTLRenderCommandEncoder) {
        // TODO: Implement grid rendering
    }

    private func drawEffectMarkers(in encoder: MTLRenderCommandEncoder) {
        guard let editorState = editorState else { return }

        // Sort effects by start time for proper layering
        let sortedEffects = editorState.effectStack.videoEffects
            .filter { $0.timeRange != nil }
            .sorted { $0.timeRange!.lowerBound < $1.timeRange!.lowerBound }

        for effect in sortedEffects {
            guard let timeRange = effect.timeRange else { continue }

            let startX = timeToXPosition(CMTimeGetSeconds(timeRange.lowerBound))
            let endX = timeToXPosition(CMTimeGetSeconds(timeRange.upperBound))
            let width = endX - startX

            // Skip effects that are completely outside visible area
            if endX < 0 || startX > bounds.width {
                continue
            }

            // Choose color based on effect type
            let color: NSColor
            switch effect.type {
            case .brightness:
                color = NSColor.systemYellow.withAlphaComponent(0.6)
            case .contrast:
                color = NSColor.systemOrange.withAlphaComponent(0.6)
            case .saturation:
                color = NSColor.systemPurple.withAlphaComponent(0.6)
            }

            // Draw effect region
            drawEffectRegion(
                in: encoder,
                rect: CGRect(x: startX, y: timeRulerHeight, width: width, height: bounds.height - timeRulerHeight),
                color: color,
                effect: effect
            )
        }
    }

    private func drawEffectRegion(in encoder: MTLRenderCommandEncoder, rect: CGRect, color: NSColor, effect: VideoEffect) {
        // Create vertices for effect rectangle
        let vertices: [Float] = [
            Float(rect.minX), Float(rect.minY), 0.0,
            Float(rect.maxX), Float(rect.minY), 0.0,
            Float(rect.minX), Float(rect.maxY), 0.0,
            Float(rect.maxX), Float(rect.maxY), 0.0
        ]

        // Create colors with transparency
        let alpha: Float = Float(color.alphaComponent)
        let baseColor = color.usingColorSpace(.deviceRGB) ?? color
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        baseColor.getRed(&r, green: &g, blue: &b, alpha: nil)

        let colors: [Float] = [
            Float(r), Float(g), Float(b), alpha,
            Float(r), Float(g), Float(b), alpha,
            Float(r), Float(g), Float(b), alpha,
            Float(r), Float(g), Float(b), alpha
        ]

        // Render effect region (simplified implementation)
        // In a real implementation, you'd use proper Metal rendering
        // For now, we'll mark the area for the basic renderer to handle
    }

    private func drawWaveform(in encoder: MTLRenderCommandEncoder) {
        // TODO: Implement waveform rendering
    }

    private func drawPlayhead(in encoder: MTLRenderCommandEncoder) {
        // TODO: Implement playhead rendering
    }

    // MARK: - Public Methods

    /// Update waveform data
    func setWaveform(_ waveform: [Double]) {
        self.waveform = waveform
    }

    /// Update audio waveform data (convenience method that accepts optional)
    func setAudioWaveform(_ waveform: [Double]?) {
        if let waveform = waveform {
            self.waveform = waveform
        } else {
            self.waveform = []
        }
    }

    /// Update track layouts
    func setTrackLayouts(_ layouts: [TrackLayout]) {
        self.trackLayouts = layouts
    }

    /// Scroll to position
    func scroll(to point: CGPoint) {
        contentOffset = point
    }

    /// Zoom to scale
    func zoom(to scale: CGFloat) {
        contentScale = max(0.1, min(scale, 10.0))
    }

    /// Seek to time
    func seek(to time: Double) {
        currentTime = time
    }

    /// Configure timeline with editor state
    func configure(with editorState: EditorState) {
        self.editorState = editorState
        self.viewModel = TimelineViewModel(editorState: editorState)
        self.duration = editorState.duration

        // Initialize subviews if not already done
        if loopRegionView == nil {
            setupSubviewRendering()
        }

        // Sync initial data
        updateLoopRegions()
        updateChapterMarkers()
        updateEffectMarkers()
    }

    /// Convert time to x position
    func timeToXPosition(_ time: Double) -> CGFloat {
        return CGFloat(time) * contentScale + contentOffset.x
    }

    /// Convert x position to time
    func xPositionToTime(_ x: CGFloat) -> Double {
        return (Double(x) - Double(contentOffset.x)) / Double(contentScale)
    }

    /// Calculate visible time range with 10% padding on in/out range
    func calculateVisibleTimeRange() -> ClosedRange<CMTime> {
        guard duration > CMTime.zero else {
            return CMTime.zero...CMTime.zero
        }

        guard let editorState = editorState else {
            return CMTime.zero...duration
        }

        let inTime = editorState.inPoint ?? CMTime.zero
        let outTime = editorState.outPoint ?? duration

        let range = outTime - inTime
        if range <= CMTime.zero {
            return CMTime.zero...duration
        }

        // Add 10% padding
        let paddingSeconds = CMTimeGetSeconds(range) * 0.1
        let padding = CMTime(seconds: paddingSeconds, preferredTimescale: range.timescale)
        let paddedRange = CMTimeAdd(range, padding)

        let startTime = max(CMTime.zero, inTime - padding)
        let endTime = min(duration, CMTimeAdd(inTime, paddedRange))

        return startTime...endTime
    }

    /// Format time as string for display in time ruler
    func formatTime(_ time: Double) -> String {
        let totalSeconds = Int(time)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        let fractional = Int((time.truncatingRemainder(dividingBy: 1.0)) * 100)

        if minutes > 0 {
            return String(format: "%d:%02d", minutes, seconds)
        } else {
            return String(format: "%d.%02d", seconds, fractional)
        }
    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        let playheadX = timeToXPosition(currentTime)

        // Check if Cmd key is pressed for scrubbing
        if event.modifierFlags.contains(.command) {
            // Start scrubbing with Cmd+drag on playhead
            if abs(location.x - playheadX) <= playheadHitTolerance {
                startScrubbing(at: location.x)
                return
            }
        } else {
            // Check for loop creation drag (not on playhead)
            if abs(location.x - playheadX) > playheadHitTolerance {
                startLoopCreation(at: location.x)
                return
            }

            // Check if click is within playhead tolerance for normal dragging
            if abs(location.x - playheadX) <= playheadHitTolerance {
                isDraggingPlayhead = true
            } else {
                isDraggingPlayhead = false
            }
        }
    }

    override func mouseMoved(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        let playheadX = timeToXPosition(currentTime)

        // Update cursor based on position and Cmd key
        if event.modifierFlags.contains(.command) && abs(location.x - playheadX) <= playheadHitTolerance {
            NSCursor.openHand.set()
        } else {
            NSCursor.arrow.set()
        }
    }

    override func mouseDragged(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)

        if isScrubbing {
            // Update scrubbing with Cmd+drag
            updateScrub(at: location.x)
        } else if isCreatingLoop {
            // Update loop creation drag
            updateLoopCreation(location.x)
        } else if isDraggingPlayhead {
            // Normal playhead dragging
            let newTime = xPositionToTime(location.x)
            currentTime = max(0.0, newTime) // Ensure time doesn't go negative
        }
    }

    override func mouseUp(with event: NSEvent) {
        if isScrubbing {
            endScrubbing()
        } else if isCreatingLoop {
            finishLoopCreation()
        } else {
            isDraggingPlayhead = false
        }
    }

  // MARK: - Keyboard Shortcuts

    override func keyDown(with event: NSEvent) {
        // Handle command+modifier keys first (priority hierarchy)
        if event.modifierFlags.contains(.command) {
            switch event.charactersIgnoringModifiers {
            case "f":
                // Cmd+F for focus mode toggle
                toggleFocusMode()
                return
            case "i":
                // Cmd+I for set in point
                setInPoint()
                return
            case "o":
                // Cmd+O for set out point
                setOutPoint()
                return
            case "c":
                // Cmd+C for clear in/out points
                if event.modifierFlags.contains(.shift) {
                    clearInOutPoints()
                }
                return
            default:
                break
            }
        }

        // Handle JKL playback controls
        switch event.charactersIgnoringModifiers?.lowercased() {
        case "j":
            // J for seek backward
            seekBackward()
            return
        case "k":
            // K for play/pause
            togglePlayPause()
            return
        case "l":
            // L for seek forward
            seekForward()
            return
        default:
            break
        }

        // Handle arrow keys for navigation
        switch event.charactersIgnoringModifiers {
        case "←":
            // Left arrow for seek backward
            seekBackward()
            return
        case "→":
            // Right arrow for seek forward
            seekForward()
            return
        case " ":
            // Space for play/pause
            togglePlayPause()
            return
        default:
            break
        }

        super.keyDown(with: event)
    }

    private func seekBackward() {
        let seekAmount: Double = -5.0
        currentTime = max(0.0, currentTime + seekAmount)
        inOutPointDelegate?.timelineViewDidSeek(self, amount: seekAmount)
    }

    private func seekForward() {
        let seekAmount: Double = 5.0
        currentTime = min(CMTimeGetSeconds(duration), currentTime + seekAmount)
        inOutPointDelegate?.timelineViewDidSeek(self, amount: seekAmount)
    }

    private func togglePlayPause() {
        // This would call a play/pause delegate method if one exists
        inOutPointDelegate?.timelineViewDidPlayPause(self)
    }

    // MARK: - Resize Handling

    func updateSubviewFrames() {
        loopRegionView?.frame = bounds
        chapterMarkerTrackView?.frame = bounds
        effectMarkerTrackView?.frame = bounds
    }

    // MARK: - In/Out Point Actions

    @objc private func setInPoint() {
        inOutPointDelegate?.timelineViewDidSetInPoint(self, time: currentTime)
    }

    @objc private func setOutPoint() {
        inOutPointDelegate?.timelineViewDidSetOutPoint(self, time: currentTime)
    }

    @objc private func clearInOutPoints() {
        inOutPointDelegate?.timelineViewDidClearInOutPoints(self)
    }

    @objc private func toggleFocusMode() {
        isFocusMode.toggle()
        inOutPointDelegate?.timelineViewDidToggleFocusMode(self, isFocused: isFocusMode)
        focusModeButton.state = isFocusMode ? .on : .off

        // Trigger focus mode animation
        updateForFocusMode()
    }

    // MARK: - Scrubbing Methods

    private func startScrubbing(at position: CGFloat) {
        scrubController = ScrubController()
        scrubController?.startScrubbing(at: position)
        isScrubbing = true
        currentScrubSpeed = 0.0

        // Change cursor to scrub icon
        NSCursor.openHand.set()

        // Create scrub indicator overlay
        setupScrubIndicator()
    }

    private func updateScrub(at position: CGFloat) {
        guard let scrubController = scrubController else { return }

        let scrubSpeed = scrubController.updateScrub(at: position)
        currentScrubSpeed = scrubSpeed

        // Update current time based on scrub speed
        let timeDelta = scrubSpeed * 0.016 // Assuming 60 FPS
        currentTime = max(0.0, currentTime + timeDelta)

        // Update scrub indicator
        updateScrubIndicator(at: position)
    }

    private func endScrubbing() {
        scrubController?.endScrubbing()
        scrubController = nil
        isScrubbing = false
        currentScrubSpeed = 0.0

        // Restore cursor
        NSCursor.arrow.set()

        // Remove scrub indicator
        scrubIndicatorView?.removeFromSuperview()
        scrubIndicatorView = nil
    }

    private func setupScrubIndicator() {
        guard scrubIndicatorView == nil else { return }

        scrubIndicatorView = NSView(frame: NSRect(x: 0, y: 0, width: 60, height: 30))
        scrubIndicatorView?.wantsLayer = true
        scrubIndicatorView?.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.8).cgColor
        scrubIndicatorView?.layer?.cornerRadius = 4.0

        addSubview(scrubIndicatorView!)

        // Add speed label
        let label = NSTextField(labelWithString: "1.0x")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .white
        label.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)

        scrubIndicatorView?.addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: scrubIndicatorView!.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: scrubIndicatorView!.centerYAnchor)
        ])

        updateScrubIndicatorPosition()
    }

    private func updateScrubIndicator(at position: CGFloat) {
        guard let scrubIndicatorView = scrubIndicatorView else { return }

        // Update speed display
        if let label = scrubIndicatorView.subviews.first as? NSTextField {
            let speedText = abs(currentScrubSpeed) < 0.01 ? "0.0x" : String(format: "%.1fx", abs(currentScrubSpeed))
            label.stringValue = currentScrubSpeed < 0 ? "-\(speedText)" : speedText
        }

        updateScrubIndicatorPosition()
    }

    private func updateScrubIndicatorPosition() {
        guard let scrubIndicatorView = scrubIndicatorView else { return }

        // Position indicator above the cursor with some offset
        let mouseX = scrubIndicatorView.superview?.convert(.zero, from: nil).x ?? 0
        let mouseY = scrubIndicatorView.superview?.convert(.zero, from: nil).y ?? 0

        scrubIndicatorView.frame.origin.x = mouseX - 30 // Center on cursor
        scrubIndicatorView.frame.origin.y = mouseY - 40 // Above cursor
    }

    // MARK: - Focus Mode Methods

    func updateForFocusMode() {
        let context = NSAnimationContext.current
        context.duration = 0.3
        context.allowsImplicitAnimation = true

        // Update visible time range
        visibleTimeRange = self.calculateVisibleTimeRange()

        // Animate timeline zoom
        let focusRange = visibleTimeRange
        let zoomScale = Double(bounds.width) / focusRange.lowerBound.seconds
        contentScale = max(0.1, min(zoomScale, 10.0))

        // Trigger redraw
        needsDisplay = true

        focusModeAnimationContext = context
    }

    private func renderFocusModeOverlay(in encoder: MTLRenderCommandEncoder) {
        guard isFocusMode else { return }

        let visibleRange = visibleTimeRange
        let currentTimeCMTime = CMTime(seconds: currentTime, preferredTimescale: 600)

        // Calculate dimmed areas
        let leftDimmedArea: CGRect
        let rightDimmedArea: CGRect

        if currentTimeCMTime >= visibleRange.lowerBound && currentTimeCMTime <= visibleRange.upperBound {
            // Current time is within focus range
            leftDimmedArea = CGRect(x: 0, y: 0, width: timeToXPosition(CMTimeGetSeconds(visibleRange.lowerBound)), height: bounds.height)
            rightDimmedArea = CGRect(x: timeToXPosition(CMTimeGetSeconds(visibleRange.upperBound)), y: 0, width: bounds.width - timeToXPosition(CMTimeGetSeconds(visibleRange.upperBound)), height: bounds.height)
        } else {
            // Current time is outside focus range
            leftDimmedArea = CGRect(x: 0, y: 0, width: bounds.width * 0.5, height: bounds.height)
            rightDimmedArea = CGRect(x: bounds.width * 0.5, y: 0, width: bounds.width * 0.5, height: bounds.height)
        }

        // Render dimmed overlays
        renderDimmedArea(in: encoder, rect: leftDimmedArea)
        renderDimmedArea(in: encoder, rect: rightDimmedArea)
    }

    private func renderDimmedArea(in encoder: MTLRenderCommandEncoder, rect: CGRect) {
        // Create vertices for dimmed rectangle
        let vertices: [Float] = [
            Float(rect.minX), Float(rect.minY), 0.0,
            Float(rect.maxX), Float(rect.minY), 0.0,
            Float(rect.minX), Float(rect.maxY), 0.0,
            Float(rect.maxX), Float(rect.maxY), 0.0
        ]

        // Create colors (semi-transparent black)
        let colors: [Float] = [
            0.0, 0.0, 0.0, 0.7,
            0.0, 0.0, 0.0, 0.7,
            0.0, 0.0, 0.0, 0.7,
            0.0, 0.0, 0.0, 0.7
        ]

        // Render dimmed area (simplified implementation)
        // In a real implementation, you'd use proper Metal rendering
        // For now, we'll mark the area for the basic renderer to handle
    }

  // MARK: - Loop Creation Methods

    private func startLoopCreation(at position: CGFloat) {
        isCreatingLoop = true
        loopDragStartX = position
        loopDragCurrentX = position

        // Create loop creation overlay
        setupLoopCreationOverlay()
    }

    private func updateLoopCreation(_ position: CGFloat) {
        guard isCreatingLoop else { return }

        loopDragCurrentX = position
        updateLoopCreationOverlay()
    }

    private func finishLoopCreation() {
        guard isCreatingLoop else { return }

        isCreatingLoop = false

        // Calculate loop time range
        let startTime = min(xPositionToTime(loopDragStartX), xPositionToTime(loopDragCurrentX))
        let endTime = max(xPositionToTime(loopDragStartX), xPositionToTime(loopDragCurrentX))

        let loopRange = CMTime(seconds: startTime, preferredTimescale: 600)...CMTime(seconds: endTime, preferredTimescale: 600)

        // Validate loop duration
        let validator = LoopRegionValidator(minimumDuration: 0.1)
        do {
            try validator.validate(range: loopRange, videoDuration: duration)

            // Create new loop region
            let loopCount = editorState?.loopRegions.count ?? 0
            let loopName = "Loop \(loopCount + 1)"
            let randomColor = TimelineColor.random()

            let newLoop = LoopRegion(
                id: UUID(),
                name: loopName,
                timeRange: loopRange,
                color: randomColor
            )

            // Add to editor state
            editorState?.loopRegions.append(newLoop)

        } catch {
            // Handle validation error (show alert or ignore)
            print("Loop creation failed: \(error.localizedDescription)")
        }

        // Clean up overlay
        loopCreationOverlay?.removeFromSuperview()
        loopCreationOverlay = nil
    }

    private func setupLoopCreationOverlay() {
        guard loopCreationOverlay == nil else { return }

        loopCreationOverlay = NSView(frame: bounds)
        loopCreationOverlay?.wantsLayer = true
        loopCreationOverlay?.layer?.backgroundColor = NSColor.red.withAlphaComponent(0.3).cgColor
        addSubview(loopCreationOverlay!)

        updateLoopCreationOverlay()
    }

    private func updateLoopCreationOverlay() {
        guard let loopCreationOverlay = loopCreationOverlay else { return }

        let startX = min(loopDragStartX, loopDragCurrentX)
        let width = abs(loopDragCurrentX - loopDragStartX)

        loopCreationOverlay.frame = NSRect(
            x: startX,
            y: 0,
            width: width,
            height: bounds.height
        )
    }

    // MARK: - Cleanup

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - LoopRegionDelegate

extension TimelineView: LoopRegionDelegate {
    nonisolated func loopRegionDidChange(_ loopRegion: LoopRegion) {
        Task { @MainActor in
            // Update editor state with the changed loop region
            if let index = editorState?.loopRegions.firstIndex(where: { $0.id == loopRegion.id }) {
                editorState?.loopRegions[index] = loopRegion
            }
        }
    }
}

// MARK: - ChapterMarkerDelegate

extension TimelineView: ChapterMarkerDelegate {
    nonisolated func chapterMarkerSelected(_ marker: ChapterMarker) {
        Task { @MainActor in
            // Handle marker selection (could trigger highlighting or other UI updates)
            print("Selected chapter marker: \(marker.name)")
        }
    }

    nonisolated func chapterMarkerMoved(_ marker: ChapterMarker, from oldTime: CMTime) {
        Task { @MainActor in
            // Update editor state with the moved marker
            if let index = editorState?.chapterMarkers.firstIndex(where: { $0.id == marker.id }) {
                editorState?.chapterMarkers[index] = marker
            }
        }
    }
}

// MARK: - EffectMarkerTrackViewDelegate

extension TimelineView: EffectMarkerTrackViewDelegate {
    nonisolated func effectMarkerTrackViewDidSelectEffect(_ effect: VideoEffect) {
        Task { @MainActor in
            // Handle effect selection (could trigger highlighting or other UI updates)
            print("Selected effect: \(effect.type.rawValue)")
        }
    }

    nonisolated func effectMarkerTrackViewDidMoveEffect(_ effect: VideoEffect, from oldTimeRange: ClosedRange<CMTime>) {
        Task { @MainActor in
            // Update editor state with the moved effect
            if let index = editorState?.effectStack.videoEffects.firstIndex(where: { $0.id == effect.id }) {
                editorState?.effectStack.videoEffects[index] = effect
            }
        }
    }
}

// MARK: - NSDraggingDestination

extension TimelineView {
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let pasteboard = sender.draggingPasteboard
        guard pasteboard.types?.contains(NSPasteboard.PasteboardType("com.openscreen.transitionType")) ?? false else {
            return []
        }

        return .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        // Read transition type from pasteboard
        let pasteboard = sender.draggingPasteboard
        guard let transitionTypeString = pasteboard.string(forType: NSPasteboard.PasteboardType("com.openscreen.transitionType")),
              let transitionType = TransitionType(rawValue: transitionTypeString) else {
            return false
        }

        // Find clips at drop location
        let dropPoint = sender.draggingLocation
        guard let (leadingClip, trailingClip) = findClipsAt(point: dropPoint) else {
            showAlert(message: "Can only add transitions between two overlapping clips")
            return false
        }

        // Validate overlap
        let overlapDuration = calculateOverlap(leading: leadingClip, trailing: trailingClip)

        guard overlapDuration >= TransitionValidator.minimumDuration else {
            showAlert(message: "Clips must overlap by at least \(CMTimeGetSeconds(TransitionValidator.minimumDuration))s")
            return false
        }

        // Check if transition already exists
        if let editorState = editorState,
           editorState.transitions.contains(where: {
            $0.leadingClipID == leadingClip.id && $0.trailingClipID == trailingClip.id
           }) {
            showAlert(message: "Transition already exists between these clips")
            return false
        }

        // Create transition
        let transition = TransitionClip(
            type: transitionType,
            duration: min(overlapDuration, CMTime(seconds: 1.0, preferredTimescale: 600)),
            leadingClipID: leadingClip.id,
            trailingClipID: trailingClip.id,
            parameters: TransitionParameters.default(for: transitionType),
            isEnabled: true
        )

        // Add to EditorState
        editorState?.addTransition(transition)

        return true
    }

    /// Finds overlapping clips at a given point in the timeline
    private func findClipsAt(point: CGPoint) -> (VideoClip, VideoClip)? {
        guard let editorState = editorState else { return nil }

        // Convert point to time
        let timeAtPoint = xPositionToTime(point.x)
        let pointTime = CMTime(seconds: timeAtPoint, preferredTimescale: 600)

        // Find clips at this time across all tracks
        var clipsAtTime: [VideoClip] = []
        for track in editorState.clipTracks {
            for clip in track.clips {
                if pointTime >= clip.timeRangeInTimeline.start &&
                   pointTime <= clip.timeRangeInTimeline.end {
                    clipsAtTime.append(clip)
                }
            }
        }

        // Need exactly 2 overlapping clips
        guard clipsAtTime.count == 2 else { return nil }

        // Sort by start time to determine leading vs trailing
        let sortedClips = clipsAtTime.sorted { $0.timeRangeInTimeline.start < $1.timeRangeInTimeline.start }
        let leadingClip = sortedClips[0]
        let trailingClip = sortedClips[1]

        // Validate they actually overlap
        let overlapDuration = calculateOverlap(leading: leadingClip, trailing: trailingClip)
        guard overlapDuration > CMTime.zero else { return nil }

        return (leadingClip, trailingClip)
    }
}

// MARK: - Shader Source

private enum TimelineShaders {
    static let source = """
    #include <metal_stdlib>
    using namespace metal;

    struct Vertex {
        float2 position [[attribute(0)]];
        float4 color [[attribute(1)]];
    };

    struct RasterizerData {
        float4 position [[position]];
        float4 color;
    };

    vertex RasterizerData timeline_vertex(Vertex in [[stage_in]]) {
        RasterizerData out;
        out.position = float4(in.position, 0.0, 1.0);
        out.color = in.color;
        return out;
    }

    fragment float4 timeline_fragment(RasterizerData in [[stage_in]]) {
        return in.color;
    }
    """
}
