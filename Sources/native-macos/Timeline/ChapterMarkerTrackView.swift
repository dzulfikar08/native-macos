import AppKit
import AVFoundation

/// NSView-based marker track rendering for chapter markers
@MainActor
final class ChapterMarkerTrackView: NSView {

    // MARK: - Properties

    /// Chapter markers to display
    private(set) var chapterMarkers: [ChapterMarker] = []

    /// Video duration for time-to-position conversion
    var videoDuration: CMTime = CMTime(seconds: 60.0, preferredTimescale: 600)

    /// Time range currently visible in the timeline
    var visibleTimeRange: ClosedRange<CMTime> = CMTime.zero...CMTime(seconds: 60.0, preferredTimescale: 600)

    /// Content scale for zooming
    var contentScale: CGFloat = 1.0

    /// Content offset for scrolling
    var contentOffset: CGPoint = .zero

    /// Delegate for chapter marker interactions
    weak var delegate: ChapterMarkerDelegate?

    /// Currently selected marker
    private var selectedMarker: ChapterMarker?

    /// Drag state
    private var dragStartLocation: CGPoint = .zero

    /// Marker hit detection radius
    private let hitRadius: CGFloat = 8.0

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

    func addChapterMarker(_ chapterMarker: ChapterMarker) {
        chapterMarkers.append(chapterMarker)
        needsDisplay = true
    }

    func removeChapterMarker(_ id: UUID) {
        if let index = chapterMarkers.firstIndex(where: { $0.id == id }) {
            chapterMarkers.remove(at: index)
            needsDisplay = true
        }
    }

    func updateChapterMarker(_ chapterMarker: ChapterMarker) {
        if let index = chapterMarkers.firstIndex(where: { $0.id == chapterMarker.id }) {
            chapterMarkers[index] = chapterMarker
            needsDisplay = true
        }
    }

    func clearChapterMarkers() {
        chapterMarkers.removeAll()
        selectedMarker = nil
        needsDisplay = true
    }

    // MARK: - Computed Properties

    /// Chapter markers visible in the current time range (performance optimized)
    var visibleChapterMarkers: [ChapterMarker] {
        // Use binary search for performance with 100+ markers
        let lowerBoundTime = visibleTimeRange.lowerBound
        let upperBoundTime = visibleTimeRange.upperBound

        return chapterMarkers.filter { marker in
            marker.time >= lowerBoundTime && marker.time <= upperBoundTime
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

    func isPointInMarker(_ x: CGFloat) -> Bool {
        for marker in chapterMarkers {
            let markerX = timeToXPosition(marker.time)
            if abs(x - markerX) <= hitRadius {
                return true
            }
        }
        return false
    }

    func getMarkerAtPoint(_ x: CGFloat) -> ChapterMarker? {
        for marker in chapterMarkers {
            let markerX = timeToXPosition(marker.time)
            if abs(x - markerX) <= hitRadius {
                return marker
            }
        }
        return nil
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // Draw visible chapter markers with performance optimization
        for marker in visibleChapterMarkers {
            drawChapterMarker(marker, in: context)
        }

        // Draw selected marker on top
        if let selectedMarker = selectedMarker {
            drawChapterMarker(selectedMarker, in: context, isSelected: true)
        }
    }

    private func drawChapterMarker(_ marker: ChapterMarker, in context: CGContext, isSelected: Bool = false) {
        let x = timeToXPosition(marker.time)
        let markerHeight: CGFloat = 30.0
        let markerY = bounds.height - markerHeight - 5.0

        // Draw flag pole
        let poleWidth: CGFloat = 2.0
        let poleRect = CGRect(x: x - poleWidth / 2, y: markerY, width: poleWidth, height: markerHeight)
        context.setStrokeColor(marker.color.nsColor.cgColor)
        context.setLineWidth(poleWidth)
        context.stroke(poleRect)

        // Draw flag
        let flagWidth: CGFloat = 16.0
        let flagHeight: CGFloat = 12.0
        let flagX = x + poleWidth / 2
        let flagY = markerY + 2

        let flagRect = CGRect(x: flagX, y: flagY, width: flagWidth, height: flagHeight)

        context.setFillColor(marker.color.nsColor.cgColor)
        context.fill(flagRect)

        // Draw flag border
        if isSelected {
            context.setStrokeColor(NSColor.white.cgColor)
            context.setLineWidth(2.0)
        } else {
            context.setStrokeColor(NSColor.black.cgColor)
            context.setLineWidth(1.0)
        }
        context.stroke(flagRect)

        // Draw label if space allows
        if let notes = marker.notes, !notes.isEmpty && markerWidthAtX(x) > 40 {
            drawLabel(notes, in: CGRect(x: flagX + flagWidth + 4, y: flagY, width: markerWidthAtX(x) - flagX - flagWidth - 4, height: flagHeight))
        }

        // Draw marker time if space allows
        let timeString = formatTime(marker.time)
        if markerWidthAtX(x) > 60 {
            drawTimeLabel(timeString, in: CGRect(x: x - 20, y: markerY + flagHeight + 2, width: 40, height: 12))
        }

        // Draw selection highlight
        if isSelected {
            let selectionRect = CGRect(x: x - hitRadius - 2, y: markerY - 2, width: hitRadius * 2 + 4, height: markerHeight + 4)
            context.setStrokeColor(NSColor.white.cgColor)
            context.setLineWidth(2.0)
            context.stroke(selectionRect)
        }
    }

    private func drawLabel(_ text: String, in rect: CGRect) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraphStyle
        ]

        let attributedString = NSAttributedString(string: text, attributes: attributes)
        attributedString.draw(with: rect, options: .usesLineFragmentOrigin, context: nil)
    }

    private func drawTimeLabel(_ text: String, in rect: CGRect) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10, weight: .regular),
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraphStyle
        ]

        let attributedString = NSAttributedString(string: text, attributes: attributes)
        attributedString.draw(with: rect, options: .usesLineFragmentOrigin, context: nil)
    }

    private func markerWidthAtX(_ x: CGFloat) -> CGFloat {
        // Calculate available width for marker label
        let rightEdge = bounds.width
        return rightEdge - x
    }

    private func formatTime(_ time: CMTime) -> String {
        let totalSeconds = CMTimeGetSeconds(time)
        let minutes = Int(totalSeconds) / 60
        let seconds = Int(totalSeconds) % 60
        let fractional = Int((totalSeconds.truncatingRemainder(dividingBy: 1.0)) * 100)

        if minutes > 0 {
            return String(format: "%d:%02d", minutes, seconds)
        } else {
            return String(format: "%d.%02d", seconds, fractional)
        }
    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)

        // Check if clicking on a marker
        if let marker = getMarkerAtPoint(location.x) {
            selectedMarker = marker
            dragStartLocation = location
            needsDisplay = true

            // Notify delegate of selection
            delegate?.chapterMarkerSelected(marker)
        } else {
            selectedMarker = nil
            needsDisplay = true
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let selectedMarker = selectedMarker else { return }

        let location = convert(event.locationInWindow, from: nil)
        let newTime = xPositionToTime(location.x)

        // Create updated marker with new time
        let updatedMarker = ChapterMarker(
            id: selectedMarker.id,
            name: selectedMarker.name,
            time: newTime,
            notes: selectedMarker.notes,
            color: selectedMarker.color
        )

        updateChapterMarker(updatedMarker)
        delegate?.chapterMarkerMoved(updatedMarker, from: selectedMarker.time)
    }

    override func mouseUp(with event: NSEvent) {
        if let selectedMarker = selectedMarker {
            delegate?.chapterMarkerSelected(selectedMarker)
        }
        dragStartLocation = .zero
    }

    override func cursorUpdate(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)

        if isPointInMarker(location.x) {
            self.addCursor(.pointingHand)
        } else {
            self.addCursor(.arrow)
        }
    }

    private func addCursor(_ cursor: NSCursor) {
        cursor.push()
        NSCursor.pop()
    }
}

// MARK: - ChapterMarkerDelegate

protocol ChapterMarkerDelegate: AnyObject {
    func chapterMarkerSelected(_ marker: ChapterMarker)
    func chapterMarkerMoved(_ marker: ChapterMarker, from oldTime: CMTime)
}