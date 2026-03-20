import AppKit
import AVFoundation
import CoreMedia

/// Delegate for effect marker callbacks
protocol EffectMarkerTrackViewDelegate: AnyObject {
    /// Called when an effect marker is selected
    func effectMarkerTrackViewDidSelectEffect(_ effect: VideoEffect)

    /// Called when an effect marker is moved
    func effectMarkerTrackViewDidMoveEffect(_ effect: VideoEffect, from oldTimeRange: ClosedRange<CMTime>)
}

/// View for rendering effect markers on the timeline
@MainActor
final class EffectMarkerTrackView: NSView {

    // MARK: - Properties

    /// Delegate for effect marker callbacks
    weak var delegate: EffectMarkerTrackViewDelegate?

    /// Video duration
    var videoDuration: CMTime = CMTime.zero

    /// Content scale for zooming
    var contentScale: CGFloat = 1.0

    /// Content offset for scrolling
    var contentOffset: CGPoint = .zero

    /// Visible time range
    var visibleTimeRange: ClosedRange<CMTime> = CMTime.zero...CMTime.zero

    /// Effect markers to display
    private var effectMarkers: [VideoEffect] = []

    /// Hit detection tolerance for effect markers
    private let hitTolerance: CGFloat = 5.0

    /// Currently selected effect marker
    private var selectedEffect: VideoEffect?

    // MARK: - Initialization

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupAppearance()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupAppearance()
    }

    // MARK: - Setup

    private func setupAppearance() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    // MARK: - Public Methods

    /// Add an effect marker
    func addEffectMarker(_ effect: VideoEffect) {
        guard effect.timeRange != nil else { return }
        effectMarkers.append(effect)
        needsDisplay = true
    }

    /// Clear all effect markers
    func clearEffectMarkers() {
        effectMarkers.removeAll()
        selectedEffect = nil
        needsDisplay = true
    }

    /// Convert time to x position
    func timeToXPosition(_ time: Double) -> CGFloat {
        return CGFloat(time) * contentScale + contentOffset.x
    }

    /// Convert x position to time
    func xPositionToTime(_ x: CGFloat) -> Double {
        return (Double(x) - Double(contentOffset.x)) / Double(contentScale)
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // Draw effect markers
        for effect in effectMarkers {
            drawEffectMarker(effect, in: context)
        }

        // Draw selection highlight if needed
        if let selectedEffect = selectedEffect {
            drawEffectMarkerSelection(selectedEffect, in: context)
        }
    }

    private func drawEffectMarker(_ effect: VideoEffect, in context: CGContext) {
        guard let timeRange = effect.timeRange else { return }

        let startX = timeToXPosition(CMTimeGetSeconds(timeRange.lowerBound))
        let endX = timeToXPosition(CMTimeGetSeconds(timeRange.upperBound))
        let width = endX - startX

        // Skip effects that are completely outside visible area
        if endX < 0 || startX > bounds.width {
            return
        }

        // Choose color based on effect type
        let fillColor: NSColor
        let strokeColor: NSColor
        switch effect.type {
        case .brightness:
            fillColor = NSColor.systemYellow.withAlphaComponent(0.3)
            strokeColor = NSColor.systemYellow
        case .contrast:
            fillColor = NSColor.systemOrange.withAlphaComponent(0.3)
            strokeColor = NSColor.systemOrange
        case .saturation:
            fillColor = NSColor.systemPurple.withAlphaComponent(0.3)
            strokeColor = NSColor.systemPurple
        }

        // Draw effect region
        let rect = CGRect(x: startX, y: 30, width: max(2, width), height: bounds.height - 60)

        context.setFillColor(fillColor.cgColor)
        context.setStrokeColor(strokeColor.cgColor)
        context.setLineWidth(1.0)

        // Draw rounded rectangle
        let cornerRadius: CGFloat = 3.0
        let path = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        context.addPath(path)
        context.fillPath()
        context.strokePath()

        // Draw effect label if there's enough space
        if width > 40 {
            drawEffectLabel(effect, in: rect, with: strokeColor, context: context)
        }

        // Draw start and end markers
        drawTimeMarker(startX, color: strokeColor, context: context, isStart: true)
        drawTimeMarker(endX, color: strokeColor, context: context, isStart: false)
    }

    private func drawEffectLabel(_ effect: VideoEffect, in rect: CGRect, with color: NSColor, context: CGContext) {
        let labelText: String
        switch effect.type {
        case .brightness:
            labelText = "Brightness"
        case .contrast:
            labelText = "Contrast"
        case .saturation:
            labelText = "Saturation"
        }

        let font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .medium)
        let textColor = NSColor.black
        let textStyle = NSAttributedString(
            string: labelText,
            attributes: [
                .font: font,
                .foregroundColor: textColor,
                .backgroundColor: NSColor.white.withAlphaComponent(0.8)
            ]
        )

        let textRect = CGRect(
            x: rect.minX + 5,
            y: rect.minY + 5,
            width: rect.width - 10,
            height: 16
        )

        textStyle.draw(with: textRect, options: .usesLineFragmentOrigin, context: nil)
    }

    private func drawTimeMarker(_ x: CGFloat, color: NSColor, context: CGContext, isStart: Bool) {
        let markerY: CGFloat = isStart ? bounds.height - 20 : bounds.height - 35
        let markerHeight: CGFloat = 10

        context.setFillColor(color.cgColor)

        if isStart {
            // Triangle pointing down
            let points = [
                CGPoint(x: x - 3, y: markerY),
                CGPoint(x: x + 3, y: markerY),
                CGPoint(x: x, y: markerY + markerHeight)
            ]
            let path = CGMutablePath()
        path.addLines(between: points)
        context.addPath(path)
        } else {
            // Triangle pointing up
            let points = [
                CGPoint(x: x - 3, y: markerY + markerHeight),
                CGPoint(x: x + 3, y: markerY + markerHeight),
                CGPoint(x: x, y: markerY)
            ]
            let path = CGMutablePath()
        path.addLines(between: points)
        context.addPath(path)
        }

        context.fillPath()

        // Draw time label
        let time = xPositionToTime(x)
        let timeString = String(format: "%.2f", time)
        let font = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .regular)
        let textStyle = NSAttributedString(
            string: timeString,
            attributes: [
                .font: font,
                .foregroundColor: color,
                .backgroundColor: NSColor.clear
            ]
        )

        let textRect = CGRect(
            x: x - 15,
            y: markerY + (isStart ? markerHeight + 2 : -15),
            width: 30,
            height: 12
        )

        textStyle.draw(with: textRect, options: .usesLineFragmentOrigin, context: nil)
    }

    private func drawEffectMarkerSelection(_ effect: VideoEffect, in context: CGContext) {
        guard let timeRange = effect.timeRange else { return }

        let startX = timeToXPosition(CMTimeGetSeconds(timeRange.lowerBound))
        let endX = timeToXPosition(CMTimeGetSeconds(timeRange.upperBound))
        let width = endX - startX

        let rect = CGRect(x: startX, y: 28, width: max(2, width), height: bounds.height - 56)

        context.setStrokeColor(NSColor.systemBlue.cgColor)
        context.setLineWidth(2.0)
        context.setLineDash(phase: 0, lengths: [5, 5])

        let cornerRadius: CGFloat = 3.0
        let path = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        context.addPath(path)
        context.strokePath()

        context.setLineDash(phase: 0, lengths: [])
    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)

        // Check if clicking on an effect marker
        for effect in effectMarkers {
            guard let timeRange = effect.timeRange else { continue }

            let startX = timeToXPosition(CMTimeGetSeconds(timeRange.lowerBound))
            let endX = timeToXPosition(CMTimeGetSeconds(timeRange.upperBound))
            let width = endX - startX
            let rect = CGRect(x: startX, y: 30, width: max(2, width), height: bounds.height - 60)

            if rect.contains(location) {
                selectedEffect = effect
                delegate?.effectMarkerTrackViewDidSelectEffect(effect)
                needsDisplay = true
                return
            }
        }

        // If no effect was clicked, deselect
        selectedEffect = nil
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        // Handle effect dragging if selected
        if let selectedEffect = selectedEffect {
            let location = convert(event.locationInWindow, from: nil)

            // Calculate new time range based on drag
            let dragDelta = location.x - bounds.midX

            if let oldTimeRange = selectedEffect.timeRange {
                let oldStartSeconds = CMTimeGetSeconds(oldTimeRange.lowerBound)
                let oldDuration = CMTimeGetSeconds(oldTimeRange.upperBound) - oldStartSeconds

                let newStartSeconds = max(0, oldStartSeconds + (xPositionToTime(dragDelta) - oldStartSeconds))
                let newEndSeconds = min(CMTimeGetSeconds(videoDuration), newStartSeconds + oldDuration)

                let newTimeStart = CMTime(seconds: newStartSeconds, preferredTimescale: 600)
                let newTimeEnd = CMTime(seconds: newEndSeconds, preferredTimescale: 600)
                let newTimeRange = newTimeStart...newTimeEnd

                // Create updated effect with new time range
                let updatedEffect = VideoEffect(
                    id: selectedEffect.id,
                    type: selectedEffect.type,
                    parameters: selectedEffect.parameters,
                    isEnabled: selectedEffect.isEnabled,
                    timeRange: newTimeRange
                )

                delegate?.effectMarkerTrackViewDidMoveEffect(updatedEffect, from: oldTimeRange)
            }
        }
    }

    override func mouseUp(with event: NSEvent) {
        // End dragging
    }

    // MARK: - Resize Handling

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        needsDisplay = true
    }
}