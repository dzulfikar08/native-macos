import AppKit

final class HUDWindowController: NSWindowController {
    let recordingController = RecordingController()
    private let button = NSButton(title: "Start Recording", target: nil, action: nil)

    init(hudFrame: NSRect) {
        let screen = NSScreen.main
        let width: CGFloat = 500
        let height: CGFloat = 80
        let work = screen?.visibleFrame ?? NSRect(x: 100, y: 100, width: width, height: height)
        let x = work.midX - width / 2
        let y = work.minY + 40
        let frame = NSRect(x: x, y: y, width: width, height: height)

        let style: NSWindow.StyleMask = [.borderless]
        let window = NSWindow(contentRect: frame, styleMask: style, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.hasShadow = false
        window.ignoresMouseEvents = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let contentView = NSView(frame: window.contentView?.bounds ?? .zero)
        contentView.autoresizingMask = [.width, .height]

        super.init(window: window)

        button.target = self
        button.action = #selector(toggleRecording)
        button.bezelStyle = .rounded
        button.setFrameSize(NSSize(width: 200, height: 32))
        button.frame.origin = NSPoint(x: (width - button.frame.width) / 2, y: (height - button.frame.height) / 2)

        contentView.addSubview(button)
        window.contentView = contentView
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func toggleRecording() {
        Task { @MainActor in
            do {
                let url = try await recordingController.toggleRecording()
                if url != nil {
                    // Recording stopped
                    button.title = "Start Recording"
                } else {
                    // Recording started
                    button.title = "Stop Recording"
                }
            } catch {
                print("Error toggling recording: \(error)")
            }
        }
    }
}
