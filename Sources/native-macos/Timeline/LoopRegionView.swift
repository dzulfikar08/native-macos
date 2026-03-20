import AppKit
import AVFoundation

/// NSView-based rendering layer for loop regions
@MainActor
final class LoopRegionView: NSView {

    // MARK: - Properties

    /// Loop regions to display
    private(set) var loopRegions: [LoopRegion] = []

    /// Video duration for time-to-position conversion
    var videoDuration: CMTime = CMTime(seconds: 60.0, preferredTimescale: 600)

    /// Time range currently visible in the timeline
    var visibleTimeRange: ClosedRange<CMTime> = CMTime.zero...CMTime(seconds: 60.0, preferredTimescale: 600)

    /// Content scale for zooming
    var contentScale: CGFloat = 1.0

    /// Content offset for scrolling
    var contentOffset: CGPoint = .zero

    /// Delegate for loop region interactions
    weak var delegate: LoopRegionDelegate?

    /// Currently selected loop region for dragging
    private var selectedLoopRegion: LoopRegion?
    private var selectedHandle: ResizeHandle?

    /// Drag state
    private var dragStartLocation: CGPoint = .zero
    private var dragStartTime: CMTime = .zero

    /// Loop icon rendering
    private let loopIcon: NSImage = createLoopIcon()

    // MARK: - Resize Handles

    private enum ResizeHandle {
        case start
        case end
    }

    // MARK: - Initialization

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Public Methods

    func addLoopRegion(_ loopRegion: LoopRegion) {
        loopRegions.append(loopRegion)
        needsDisplay = true
    }

    func removeLoopRegion(_ id: UUID) {
        if let index = loopRegions.firstIndex(where: { $0.id == id }) {
            loopRegions.remove(at: index)
            needsDisplay = true
        }
    }

    func updateLoopRegion(_ loopRegion: LoopRegion) {
        if let index = loopRegions.firstIndex(where: { $0.id == loopRegion.id }) {
            loopRegions[index] = loopRegion
            needsDisplay = true
        }
    }

    func clearLoopRegions() {
        loopRegions.removeAll()
        selectedLoopRegion = nil
        selectedHandle = nil
        needsDisplay = true
    }

    // MARK: - Computed Properties

    /// Loop regions visible in the current time range
    var visibleLoopRegions: [LoopRegion] {
        return loopRegions.filter { loop in
            loop.timeRange.lowerBound <= visibleTimeRange.upperBound &&
            loop.timeRange.upperBound >= visibleTimeRange.lowerBound
        }
    }

    // MARK: - Time Conversion

    func timeToXPosition(_ time: CMTime) -> CGFloat {
        let timeSeconds = CMTimeGetSeconds(time)
        let durationSeconds = CMTimeGetSeconds(videoDuration)

        guard durationSeconds > 0 else { return 0 }

        let relativeTime = timeSeconds / durationSeconds
        let contentWidth = bounds.width
        return CGFloat(relativeTime) * contentWidth + contentOffset.x
    }

    func xPositionToTime(_ x: CGFloat) -> CMTime {
        let contentWidth = bounds.width
        let relativePosition = (x - contentOffset.x) / contentWidth
        let timeSeconds = relativePosition * CMTimeGetSeconds(videoDuration)

        let clampedTime = max(0, min(timeSeconds, CMTimeGetSeconds(videoDuration)))
        return CMTime(seconds: clampedTime, preferredTimescale: 600)
    }

    // MARK: - Hit Detection

    private func isPointInResizeHandle(_ x: CGFloat, handleType: ResizeHandle) -> Bool {
        guard let selectedLoopRegion else { return false }

        let handleX: CGFloat
        if handleType == .start {
            handleX = timeToXPosition(selectedLoopRegion.timeRange.lowerBound)
        } else {
            handleX = timeToXPosition(selectedLoopRegion.timeRange.upperBound)
        }

        let tolerance: CGFloat = 8.0
        return abs(x - handleX) <= tolerance
    }

    func isPointInLoopRegion(_ x: CGFloat, _ y: CGFloat) -> Bool {
        for loopRegion in loopRegions {
            let startX = timeToXPosition(loopRegion.timeRange.lowerBound)
            let endX = timeToXPosition(loopRegion.timeRange.upperBound)

            if x >= startX && x <= endX {
                let loopHeight: CGFloat = 40.0
                let loopY = bounds.height - loopHeight - 10.0

                return y >= loopY && y <= loopY + loopHeight
            }
        }
        return false
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // Draw visible loop regions
        for loopRegion in visibleLoopRegions {
            drawLoopRegion(loopRegion, in: context)
        }

        // Draw selected region on top
        if let selectedRegion = selectedLoopRegion {
            drawLoopRegion(selectedRegion, in: context, isSelected: true)
        }
    }

    private func drawLoopRegion(_ loopRegion: LoopRegion, in context: CGContext, isSelected: Bool = false) {
        let startX = timeToXPosition(loopRegion.timeRange.lowerBound)
        let endX = timeToXPosition(loopRegion.timeRange.upperBound)
        let width = endX - startX

        guard width > 0 else { return }

        let loopHeight: CGFloat = 40.0
        let loopY = bounds.height - loopHeight - 10.0

        // Set colors based on active state
        let fillColor: NSColor
        if loopRegion.isActive {
            fillColor = NSColor(red: 0.0, green: 0.478, blue: 1.0, alpha: 0.6) // 60% active
        } else {
            fillColor = NSColor(red: 0.0, green: 0.478, blue: 1.0, alpha: 0.3) // 30% inactive
        }

        let strokeColor: NSColor
        if isSelected {
            strokeColor = NSColor.white
        } else {
            strokeColor = loopRegion.color.nsColor
        }

        // Draw fill
        let fillRect = CGRect(x: startX, y: loopY, width: width, height: loopHeight)
        context.setFillColor(fillColor.cgColor)
        context.fill(fillRect)

        // Draw border
        context.setStrokeColor(strokeColor.cgColor)
        context.setLineWidth(2.0)
        context.stroke(fillRect)

        // Draw resize handles
        if isSelected {
            drawResizeHandle(at: startX, in: context)
            drawResizeHandle(at: endX, in: context)
        }

        // Draw loop icon in center
        let iconSize: CGFloat = 16.0
        let iconX = startX + width / 2 - iconSize / 2
        let iconY = loopY + loopHeight / 2 - iconSize / 2

        context.setFillColor(NSColor.white.cgColor)
        loopIcon.draw(in: CGRect(x: iconX, y: iconY, width: iconSize, height: iconSize))

        // Draw label if space allows
        if width > 60 {
            drawLabel(loopRegion.name, in: CGRect(x: startX + 5, y: loopY + 2, width: width - 10, height: 16))
        }
    }

    private func drawResizeHandle(at x: CGFloat, in context: CGContext) {
        let handleSize: CGFloat = 8.0
        let handleY = bounds.height - 50.0 // Above the loop region

        let handleRect = CGRect(x: x - handleSize / 2, y: handleY, width: handleSize, height: handleSize)

        context.setFillColor(NSColor.white.cgColor)
        context.fill(handleRect)

        context.setStrokeColor(NSColor.black.cgColor)
        context.setLineWidth(1.0)
        context.stroke(handleRect)
    }

    private func drawLabel(_ text: String, in rect: CGRect) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraphStyle
        ]

        let attributedString = NSAttributedString(string: text, attributes: attributes)
        attributedString.draw(with: rect, options: .usesLineFragmentOrigin, context: nil)
    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        let time = xPositionToTime(location.x)

        // Check if clicking on a resize handle
        if let selectedRegion = selectedLoopRegion {
            if isPointInResizeHandle(location.x, handleType: .start) {
                selectedHandle = .start
                dragStartLocation = location
                dragStartTime = time
                return
            } else if isPointInResizeHandle(location.x, handleType: .end) {
                selectedHandle = .end
                dragStartLocation = location
                dragStartTime = time
                return
            }
        }

        // Check if clicking on a loop region
        if let loopRegion = loopRegions.first(where: {
            let startX = timeToXPosition($0.timeRange.lowerBound)
            let endX = timeToXPosition($0.timeRange.upperBound)
            return location.x >= startX && location.x <= endX
        }) {
            selectedLoopRegion = loopRegion

            // Toggle active state if clicking on the region itself
            if !isPointInResizeHandle(location.x, handleType: .start) &&
               !isPointInResizeHandle(location.x, handleType: .end) {
                let newLoopRegion = LoopRegion(
                    id: loopRegion.id,
                    name: loopRegion.name,
                    timeRange: loopRegion.timeRange,
                    color: loopRegion.color,
                    isActive: !loopRegion.isActive,
                    useInOutPoints: loopRegion.useInOutPoints
                )
                updateLoopRegion(newLoopRegion)
                delegate?.loopRegionDidChange(newLoopRegion)
            }

            needsDisplay = true
        } else {
            selectedLoopRegion = nil
            selectedHandle = nil
            needsDisplay = true
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let selectedLoopRegion = selectedLoopRegion else { return }

        let location = convert(event.locationInWindow, from: nil)
        _ = xPositionToTime(location.x)

        if let handle = selectedHandle {
            let startTime = CMTimeGetSeconds(selectedLoopRegion.timeRange.lowerBound)
            let endTime = CMTimeGetSeconds(selectedLoopRegion.timeRange.upperBound)

            switch handle {
            case .start:
                let newStartTime = min(max(CMTimeGetSeconds(dragStartTime), 0), endTime - 0.1)
                let newTimeRange = CMTime(seconds: newStartTime, preferredTimescale: 600)...selectedLoopRegion.timeRange.upperBound

                let updatedRegion = LoopRegion(
                    id: selectedLoopRegion.id,
                    name: selectedLoopRegion.name,
                    timeRange: newTimeRange,
                    color: selectedLoopRegion.color,
                    isActive: selectedLoopRegion.isActive,
                    useInOutPoints: selectedLoopRegion.useInOutPoints
                )
                updateLoopRegion(updatedRegion)

            case .end:
                let newEndTime = max(min(CMTimeGetSeconds(dragStartTime), CMTimeGetSeconds(videoDuration)), startTime + 0.1)
                let newTimeRange = selectedLoopRegion.timeRange.lowerBound...CMTime(seconds: newEndTime, preferredTimescale: 600)

                let updatedRegion = LoopRegion(
                    id: selectedLoopRegion.id,
                    name: selectedLoopRegion.name,
                    timeRange: newTimeRange,
                    color: selectedLoopRegion.color,
                    isActive: selectedLoopRegion.isActive,
                    useInOutPoints: selectedLoopRegion.useInOutPoints
                )
                updateLoopRegion(updatedRegion)
            }

            needsDisplay = true
        }
    }

    override func mouseUp(with event: NSEvent) {
        if selectedLoopRegion != nil {
            delegate?.loopRegionDidChange(selectedLoopRegion!)
        }

        selectedHandle = nil
        dragStartLocation = .zero
        dragStartTime = .zero
    }

    override func cursorUpdate(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)

        if selectedLoopRegion != nil {
            if isPointInResizeHandle(location.x, handleType: .start) ||
               isPointInResizeHandle(location.x, handleType: .end) {
                self.addCursor(.resizeLeftRight)
            } else if isPointInLoopRegion(location.x, location.y) {
                self.addCursor(.pointingHand)
            } else {
                self.addCursor(.arrow)
            }
        } else {
            self.addCursor(.arrow)
        }
    }

    private func addCursor(_ cursor: NSCursor) {
        cursor.push()
        NSCursor.pop()
    }
}

// MARK: - LoopRegionDelegate

protocol LoopRegionDelegate: AnyObject {
    func loopRegionDidChange(_ loopRegion: LoopRegion)
}

// MARK: - Helper Functions

private func createLoopIcon() -> NSImage {
    let size = NSSize(width: 16, height: 16)
    let image = NSImage(size: size)
    image.lockFocus()

    // Draw loop symbol ⟳
    NSColor.white.setStroke()
    NSColor.white.setFill()

    let center = NSPoint(x: 8, y: 8)
    let radius: CGFloat = 6.0

    // Draw circular arrow
    let path = NSBezierPath()
    path.move(to: NSPoint(x: center.x + radius, y: center.y))
    path.curve(to: NSPoint(x: center.x, y: center.y - radius),
               controlPoint1: NSPoint(x: center.x + radius, y: center.y - radius/3),
               controlPoint2: NSPoint(x: center.x + radius/3, y: center.y - radius))
    path.curve(to: NSPoint(x: center.x - radius, y: center.y),
               controlPoint1: NSPoint(x: center.x - radius/3, y: center.y - radius),
               controlPoint2: NSPoint(x: center.x - radius, y: center.y - radius/3))
    path.curve(to: NSPoint(x: center.x, y: center.y + radius),
               controlPoint1: NSPoint(x: center.x - radius, y: center.y + radius/3),
               controlPoint2: NSPoint(x: center.x - radius/3, y: center.y + radius))
    path.curve(to: NSPoint(x: center.x + radius, y: center.y),
               controlPoint1: NSPoint(x: center.x + radius/3, y: center.y + radius),
               controlPoint2: NSPoint(x: center.x + radius, y: center.y + radius/3))

    path.lineWidth = 1.5
    path.stroke()

    // Draw arrowhead
    let arrowPath = NSBezierPath()
    arrowPath.move(to: NSPoint(x: center.x + radius, y: center.y))
    arrowPath.line(to: NSPoint(x: center.x + radius - 2, y: center.y - 1.5))
    arrowPath.line(to: NSPoint(x: center.x + radius - 2, y: center.y + 1.5))
    arrowPath.close()
    arrowPath.fill()

    image.unlockFocus()
    return image
}