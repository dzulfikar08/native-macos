import AppKit

/// On-screen wheel UI component for shuttle/scrub control
@MainActor
final class ShuttleWheelControl: NSView {

    // MARK: - State

    enum State: Equatable {
        case idle
        case dragging
        case springing
    }

    // MARK: - Properties

    private(set) var state: State = .idle

    @Published var position: Double = 0.0 {
        didSet {
            needsDisplay = true
            updateSpeed()
        }
    }

    @Published var speed: Double = 0.0 {
        didSet {
            needsDisplay = true
        }
    }

    // MARK: - Constants

    private struct Constants {
        static let maxPosition: Double = 50.0
        static let minPosition: Double = -50.0
        static let maxSpeed: Double = 4.0
        static let minSpeed: Double = -4.0
        static let wheelRadius: CGFloat = 80.0
        static let springDuration: TimeInterval = 0.5
        static let springDamping: CGFloat = 0.8
    }

    // MARK: - Private Properties

    private var isDragging = false
    private var dragStartPoint: CGPoint = .zero
    private var dragStartPosition: Double = 0.0
    private var lastUpdateTime: Date = Date()

    // MARK: - Initialization

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.darkGray.cgColor
        layer?.borderColor = NSColor.lightGray.cgColor
        layer?.borderWidth = 1.0
        layer?.cornerRadius = 10.0
    }

    // MARK: - Public Methods

    func handleMouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)

        // Check if click is within wheel bounds
        let centerPoint = CGPoint(x: bounds.midX, y: bounds.midY)
        let distance = sqrt(pow(location.x - centerPoint.x, 2) + pow(location.y - centerPoint.y, 2))

        if distance <= Constants.wheelRadius {
            isDragging = true
            dragStartPoint = location
            dragStartPosition = position

            state = .dragging
            needsDisplay = true
        }
    }

    func handleMouseDragged(with event: NSEvent) {
        guard isDragging else { return }

        let location = convert(event.locationInWindow, from: nil)
        let centerPoint = CGPoint(x: bounds.midX, y: bounds.midY)

        // Calculate drag vector from center
        let deltaX = location.x - centerPoint.x

        // Convert pixel drag to position value
        // Scale down: max 50px drag = max 50 position units
        let dragDistance = deltaX / bounds.width * Constants.maxPosition * 2

        // Apply new position with bounds
        let newPosition = dragStartPosition + dragDistance
        position = max(Constants.minPosition, min(Constants.maxPosition, newPosition))
    }

    func handleMouseUp(with event: NSEvent) {
        guard isDragging else { return }

        isDragging = false
        state = .springing

        // Start spring animation back to center
        startSpringAnimation()

        needsDisplay = true
    }

    func advanceAnimationTime(_ timeInterval: TimeInterval) {
        guard state == .springing else { return }

        // Simple spring animation
        animateSpring()
    }

    // MARK: - Private Methods

    private func updateSpeed() {
        // Calculate speed based on position
        // Linear relationship: position 50 = speed 4, position -50 = speed -4
        let normalizedPosition = position / Constants.maxPosition
        speed = normalizedPosition * Constants.maxSpeed
    }

    private func startSpringAnimation() {
        // Start spring animation
        state = .springing
        animateSpring()
    }

    private func animateSpring() {
        let springForce = 0.15  // Spring constant
        let damping = 0.85      // Damping factor
        let minVelocity = 0.1  // Minimum velocity to continue

        // Spring physics: F = -kx - cv (spring force + damping)
        let springAcceleration = -position * springForce
        let dampingAcceleration = -speed * damping
        let totalAcceleration = springAcceleration + dampingAcceleration

        // Update speed and position
        speed += totalAcceleration * 0.016  // 60 timestep
        position += speed * 0.016

        // Stop animation when close to center and moving slowly
        if abs(position) < 0.5 && abs(speed) < minVelocity {
            position = 0.0
            speed = 0.0
            state = .idle
        } else if state == .springing {
            // Continue animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.016) { [weak self] in
                self?.animateSpring()
            }
        }
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let context = NSGraphicsContext.current?.cgContext
        guard let ctx = context else { return }

        // Draw wheel background
        drawWheelBackground(in: ctx)

        // Draw wheel markers/indicators
        drawWheelIndicators(in: ctx)

        // Draw position indicator
        drawPositionIndicator(in: ctx)
    }

    private func drawWheelBackground(in ctx: CGContext) {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = Constants.wheelRadius

        // Draw wheel circle
        ctx.setFillColor(NSColor.darkGray.cgColor)
        ctx.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))

        // Draw border
        ctx.setStrokeColor(NSColor.lightGray.cgColor)
        ctx.setLineWidth(2.0)
        ctx.strokeEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }

    private func drawWheelIndicators(in ctx: CGContext) {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = Constants.wheelRadius - 10

        // Draw center line
        ctx.setStrokeColor(NSColor.white.cgColor)
        ctx.setLineWidth(1.0)

        // Horizontal line
        ctx.move(to: CGPoint(x: center.x - radius, y: center.y))
        ctx.addLine(to: CGPoint(x: center.x + radius, y: center.y))

        // Vertical line
        ctx.move(to: CGPoint(x: center.x, y: center.y - radius))
        ctx.addLine(to: CGPoint(x: center.x, y: center.y + radius))

        ctx.strokePath()
    }

    private func drawPositionIndicator(in ctx: CGContext) {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = Constants.wheelRadius - 20

        // Calculate indicator position based on current position
        let normalizedPosition = position / Constants.maxPosition
        let indicatorX = center.x + (normalizedPosition * radius)
        let indicatorY = center.y

        // Draw position indicator
        ctx.setFillColor(getIndicatorColor().cgColor)
        ctx.fillEllipse(in: CGRect(x: indicatorX - 6, y: indicatorY - 6, width: 12, height: 12))

        // Draw indicator trail
        ctx.setStrokeColor(getIndicatorColor().withAlphaComponent(0.5).cgColor)
        ctx.setLineWidth(3.0)
        ctx.move(to: CGPoint(x: center.x, y: center.y))
        ctx.addLine(to: CGPoint(x: indicatorX, y: indicatorY))
        ctx.strokePath()
    }

    private func getIndicatorColor() -> NSColor {
        switch state {
        case .idle:
            return NSColor.systemBlue
        case .dragging:
            return NSColor.systemGreen
        case .springing:
            return NSColor.systemOrange
        }
    }
}

