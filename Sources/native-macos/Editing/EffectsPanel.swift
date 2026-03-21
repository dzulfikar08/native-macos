import AppKit
import Foundation
import AVFoundation

/// Effects panel UI component for applying video and audio effects
@MainActor
final class EffectsPanel: NSView {
    // MARK: - Properties

    private var editorState: EditorState

    // UI Components
    private var tabView: NSTabView!
    private var transitionsViewController: TransitionsPaletteViewController!
    private var visualEffectView: NSVisualEffectView!

    // Expose components for testing
    var tabViewForTesting: NSTabView { tabView }

    // MARK: - Initialization

    init(editorState: EditorState) {
        self.editorState = editorState
        super.init(frame: .zero)
        setupUI()
        setupConstraints()
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

        // Create tab view
        tabView = NSTabView()
        tabView.translatesAutoresizingMaskIntoConstraints = false

        // Create Effects tab (existing effectsViewController)
        let effectsViewController = EffectsPaletteViewController(editorState: editorState)
        let effectsTab = NSTabViewItem(viewController: effectsViewController)
        effectsTab.label = "Effects"
        tabView.addTabViewItem(effectsTab)

        // Create Transitions tab
        transitionsViewController = TransitionsPaletteViewController(editorState: editorState)
        let transitionsTab = NSTabViewItem(viewController: transitionsViewController)
        transitionsTab.label = "Transitions"
        tabView.addTabViewItem(transitionsTab)

        // Add tab view to visual effect view
        visualEffectView.addSubview(tabView)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Visual effect view
            visualEffectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            visualEffectView.trailingAnchor.constraint(equalTo: trailingAnchor),
            visualEffectView.topAnchor.constraint(equalTo: topAnchor),
            visualEffectView.bottomAnchor.constraint(equalTo: bottomAnchor),

            // Tab view
            tabView.topAnchor.constraint(equalTo: visualEffectView.topAnchor, constant: 8),
            tabView.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor, constant: 8),
            tabView.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor, constant: -8),
            tabView.bottomAnchor.constraint(equalTo: visualEffectView.bottomAnchor, constant: -8)
        ])
    }

}