import Cocoa
import Combine
import CoreMedia

/// Inspector sheet for editing transition properties
/// Provides tabbed interface for Properties, Presets, and Preview
@MainActor
final class TransitionInspectorViewController: NSViewController {
    // MARK: - Properties

    /// The transition being edited
    private var transition: TransitionClip

    /// Original transition for reset functionality
    private var originalTransition: TransitionClip

    /// Callback when transition is applied
    private var onApply: (TransitionClip) -> Void

    /// Callback when transition is deleted
    private var onDelete: () -> Void

    /// Tab view for organizing inspector sections
    private lazy var tabView: NSTabView = {
        let tabView = NSTabView()
        tabView.translatesAutoresizingMaskIntoConstraints = false
        return tabView
    }()

    /// Properties tab view
    private lazy var propertiesTabView: NSTabViewItem = {
        let tabItem = NSTabViewItem(viewController: propertiesViewController)
        tabItem.label = "Properties"
        return tabItem
    }()

    /// Presets tab view
    private lazy var presetsTabView: NSTabViewItem = {
        let tabItem = NSTabViewItem(viewController: NSViewController())
        tabItem.label = "Presets"
        return tabItem
    }()

    /// Preview tab view
    private lazy var previewTabView: NSTabViewItem = {
        let tabItem = NSTabViewItem(viewController: NSViewController())
        tabItem.label = "Preview"
        return tabItem
    }()

    /// Properties view controller containing all parameter controls
    private lazy var propertiesViewController: NSViewController = {
        let controller = NSViewController()
        controller.view = propertiesScrollView
        return controller
    }()

    /// Scroll view for properties
    private lazy var propertiesScrollView: NSScrollView = {
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.documentView = propertiesContentView
        return scrollView
    }()

    /// Content view containing all property controls
    private lazy var propertiesContentView: NSView = {
        let view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    // MARK: - Basic Properties Controls

    /// Duration slider (0.1 - 5.0 seconds)
    private lazy var durationSlider: NSSlider = {
        let slider = NSSlider(value: 1.0, minValue: 0.1, maxValue: 5.0, target: self, action: #selector(durationChanged))
        slider.translatesAutoresizingMaskIntoConstraints = false
        return slider
    }()

    /// Duration label showing current value
    private lazy var durationLabel: NSTextField = {
        let label = NSTextField(labelWithString: "1.0s")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.alignment = .right
        label.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        return label
    }()

    /// Transition type dropdown
    private lazy var typeDropdown: NSPopUpButton = {
        let button = NSPopUpButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.target = self
        button.action = #selector(typeChanged)
        button.menu?.removeAllItems()

        for type in TransitionType.allStandardTypes {
            button.addItem(withTitle: type.displayName)
            button.lastItem?.representedObject = type
        }

        return button
    }()

    /// Enabled checkbox
    private lazy var enabledCheckbox: NSButton = {
        let checkbox = NSButton(checkboxWithTitle: "Enabled", target: self, action: #selector(enabledChanged))
        checkbox.translatesAutoresizingMaskIntoConstraints = false
        checkbox.state = .on
        return checkbox
    }()

    // MARK: - Parameter Controls

    /// Fade to color: Color well
    private lazy var fadeColorWell: NSColorWell = {
        let well = NSColorWell()
        well.translatesAutoresizingMaskIntoConstraints = false
        well.color = .black
        well.action = #selector(fadeColorChanged)
        well.target = self
        return well
    }()

    /// Fade to color: Hold duration slider
    private lazy var fadeHoldDurationSlider: NSSlider = {
        let slider = NSSlider(value: 0.5, minValue: 0, maxValue: 5.0, target: self, action: #selector(fadeHoldDurationChanged))
        slider.translatesAutoresizingMaskIntoConstraints = false
        return slider
    }()

    /// Wipe: Direction dropdown
    private lazy var wipeDirectionDropdown: NSPopUpButton = {
        let button = NSPopUpButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.target = self
        button.action = #selector(wipeDirectionChanged)

        for direction in WipeDirection.allCases {
            button.addItem(withTitle: direction.rawValue.capitalized)
            button.lastItem?.representedObject = direction
        }

        return button
    }()

    /// Wipe: Softness slider
    private lazy var wipeSoftnessSlider: NSSlider = {
        let slider = NSSlider(value: 0.2, minValue: 0, maxValue: 1.0, target: self, action: #selector(wipeSoftnessChanged))
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.numberOfTickMarks = 11
        return slider
    }()

    /// Wipe: Border width slider
    private lazy var wipeBorderWidthSlider: NSSlider = {
        let slider = NSSlider(value: 0, minValue: 0, maxValue: 20.0, target: self, action: #selector(wipeBorderWidthChanged))
        slider.translatesAutoresizingMaskIntoConstraints = false
        return slider
    }()

    /// Iris: Shape dropdown
    private lazy var irisShapeDropdown: NSPopUpButton = {
        let button = NSPopUpButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.target = self
        button.action = #selector(irisShapeChanged)

        for shape in IrisShape.allCases {
            button.addItem(withTitle: shape.rawValue.capitalized)
            button.lastItem?.representedObject = shape
        }

        return button
    }()

    /// Iris: Position X slider (0.0 - 1.0)
    private lazy var irisPositionXSlider: NSSlider = {
        let slider = NSSlider(value: 0.5, minValue: 0, maxValue: 1.0, target: self, action: #selector(irisPositionChanged))
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.numberOfTickMarks = 11
        return slider
    }()

    /// Iris: Position Y slider (0.0 - 1.0)
    private lazy var irisPositionYSlider: NSSlider = {
        let slider = NSSlider(value: 0.5, minValue: 0, maxValue: 1.0, target: self, action: #selector(irisPositionChanged))
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.numberOfTickMarks = 11
        return slider
    }()

    /// Iris: Softness slider
    private lazy var irisSoftnessSlider: NSSlider = {
        let slider = NSSlider(value: 0.3, minValue: 0, maxValue: 1.0, target: self, action: #selector(irisSoftnessChanged))
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.numberOfTickMarks = 11
        return slider
    }()

    /// Blinds: Orientation dropdown
    private lazy var blindsOrientationDropdown: NSPopUpButton = {
        let button = NSPopUpButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.target = self
        button.action = #selector(blindsOrientationChanged)

        for orientation in BlindsOrientation.allCases {
            button.addItem(withTitle: orientation.rawValue.capitalized)
            button.lastItem?.representedObject = orientation
        }

        return button
    }()

    /// Blinds: Slat count slider (2 - 50)
    private lazy var blindsSlatCountSlider: NSSlider = {
        let slider = NSSlider(value: 10, minValue: 2, maxValue: 50, target: self, action: #selector(blindsSlatCountChanged))
        slider.translatesAutoresizingMaskIntoConstraints = false
        return slider
    }()

    /// Blinds: Slat count label
    private lazy var blindsSlatCountLabel: NSTextField = {
        let label = NSTextField(labelWithString: "10")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.alignment = .right
        label.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        return label
    }()

    // MARK: - Action Buttons

    /// Apply button - commits changes to EditorState
    private lazy var applyButton: NSButton = {
        let button = NSButton(title: "Apply", target: self, action: #selector(applyClicked))
        button.translatesAutoresizingMaskIntoConstraints = false
        button.bezelStyle = .push
        button.keyEquivalent = "\r"
        return button
    }()

    /// Reset button - restores original values
    private lazy var resetButton: NSButton = {
        let button = NSButton(title: "Reset", target: self, action: #selector(resetClicked))
        button.translatesAutoresizingMaskIntoConstraints = false
        button.bezelStyle = .push
        return button
    }()

    /// Delete button - removes transition
    private lazy var deleteButton: NSButton = {
        let button = NSButton(title: "Delete", target: self, action: #selector(deleteClicked))
        button.translatesAutoresizingMaskIntoConstraints = false
        button.bezelStyle = .push
        return button
    }()

    // MARK: - Parameter Control Containers

    /// Stack views for organizing parameter controls by type
    private var parameterControlsStackViews: [NSStackView] = []

    // MARK: - Initialization

    init(
        transition: TransitionClip,
        onApply: @escaping (TransitionClip) -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.transition = transition
        self.originalTransition = transition
        self.onApply = onApply
        self.onDelete = onDelete
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 500))
        view.translatesAutoresizingMaskIntoConstraints = false
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupTabView()
        setupPropertiesTab()
        setupActionButtons()
        loadTransitionValues()
    }

    // MARK: - Setup

    private func setupTabView() {
        view.addSubview(tabView)

        tabView.addTabViewItem(propertiesTabView)
        tabView.addTabViewItem(presetsTabView)
        tabView.addTabViewItem(previewTabView)

        NSLayoutConstraint.activate([
            tabView.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            tabView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            tabView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            tabView.heightAnchor.constraint(equalTo: view.heightAnchor, constant: -80)
        ])
    }

    private func setupPropertiesTab() {
        let contentView = propertiesContentView

        // Add basic properties section
        let basicStack = createBasicPropertiesStack()
        contentView.addSubview(basicStack)

        // Add parameter-specific controls based on transition type
        let parameterStack = createParameterControlsStack(for: transition.type)
        contentView.addSubview(parameterStack)

        NSLayoutConstraint.activate([
            basicStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            basicStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            basicStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            parameterStack.topAnchor.constraint(equalTo: basicStack.bottomAnchor, constant: 20),
            parameterStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            parameterStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            parameterStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])

        // Set content size
        contentView.widthAnchor.constraint(equalToConstant: 360).isActive = true
    }

    private func createBasicPropertiesStack() -> NSStackView {
        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.spacing = 12
        stack.alignment = .leading

        // Duration row
        let durationRow = createLabeledControlRow(
            label: "Duration:",
            control: durationSlider,
            secondaryControl: durationLabel
        )

        // Type row
        let typeRow = createLabeledControlRow(
            label: "Type:",
            control: typeDropdown
        )

        // Enabled checkbox
        let enabledRow = NSStackView()
        enabledRow.translatesAutoresizingMaskIntoConstraints = false
        enabledRow.spacing = 8
        enabledRow.addArrangedSubview(enabledCheckbox)
        enabledRow.addArrangedSubview(NSView()) // Spacer

        stack.addArrangedSubview(durationRow)
        stack.addArrangedSubview(typeRow)
        stack.addArrangedSubview(enabledRow)

        return stack
    }

    private func createLabeledControlRow(
        label: String,
        control: NSView,
        secondaryControl: NSView? = nil
    ) -> NSStackView {
        let row = NSStackView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.spacing = 8
        row.alignment = .centerY

        let labelField = NSTextField(labelWithString: label)
        labelField.translatesAutoresizingMaskIntoConstraints = false
        labelField.widthAnchor.constraint(equalToConstant: 80).isActive = true

        row.addArrangedSubview(labelField)
        row.addArrangedSubview(control)

        if let secondary = secondaryControl {
            row.addArrangedSubview(secondary)
        } else {
            row.addArrangedSubview(NSView()) // Spacer
        }

        return row
    }

    private func createParameterControlsStack(for type: TransitionType) -> NSStackView {
        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.spacing = 12
        stack.alignment = .leading

        // Add separator
        let separator = createSeparator()
        stack.addArrangedSubview(separator)

        // Add type-specific controls
        switch type {
        case .crossfade:
            // No additional parameters
            let label = NSTextField(labelWithString: "No additional parameters for crossfade")
            label.textColor = .secondaryLabelColor
            stack.addArrangedSubview(label)

        case .fadeToColor:
            addFadeToColorControls(to: stack)

        case .wipe:
            addWipeControls(to: stack)

        case .iris:
            addIrisControls(to: stack)

        case .blinds:
            addBlindsControls(to: stack)

        case .custom:
            let label = NSTextField(labelWithString: "Custom transitions use predefined parameters")
            label.textColor = .secondaryLabelColor
            stack.addArrangedSubview(label)
        }

        return stack
    }

    private func createSeparator() -> NSBox {
        let box = NSBox()
        box.translatesAutoresizingMaskIntoConstraints = false
        box.boxType = .separator
        box.widthAnchor.constraint(equalToConstant: 360).isActive = true
        return box
    }

    // MARK: - Parameter Control Groups

    private func addFadeToColorControls(to stack: NSStackView) {
        let titleLabel = NSTextField(labelWithString: "Fade to Color Parameters")
        titleLabel.font = .boldSystemFont(ofSize: NSFont.systemFontSize)
        stack.addArrangedSubview(titleLabel)

        // Color row
        let colorRow = createLabeledControlRow(label: "Color:", control: fadeColorWell)
        stack.addArrangedSubview(colorRow)

        // Hold duration row
        let holdDurationRow = createLabeledControlRow(
            label: "Hold Duration:",
            control: fadeHoldDurationSlider
        )
        stack.addArrangedSubview(holdDurationRow)
    }

    private func addWipeControls(to stack: NSStackView) {
        let titleLabel = NSTextField(labelWithString: "Wipe Parameters")
        titleLabel.font = .boldSystemFont(ofSize: NSFont.systemFontSize)
        stack.addArrangedSubview(titleLabel)

        // Direction row
        let directionRow = createLabeledControlRow(label: "Direction:", control: wipeDirectionDropdown)
        stack.addArrangedSubview(directionRow)

        // Softness row
        let softnessRow = createLabeledControlRow(label: "Softness:", control: wipeSoftnessSlider)
        stack.addArrangedSubview(softnessRow)

        // Border width row
        let borderWidthRow = createLabeledControlRow(label: "Border Width:", control: wipeBorderWidthSlider)
        stack.addArrangedSubview(borderWidthRow)
    }

    private func addIrisControls(to stack: NSStackView) {
        let titleLabel = NSTextField(labelWithString: "Iris Parameters")
        titleLabel.font = .boldSystemFont(ofSize: NSFont.systemFontSize)
        stack.addArrangedSubview(titleLabel)

        // Shape row
        let shapeRow = createLabeledControlRow(label: "Shape:", control: irisShapeDropdown)
        stack.addArrangedSubview(shapeRow)

        // Position X row
        let posXRow = createLabeledControlRow(label: "Position X:", control: irisPositionXSlider)
        stack.addArrangedSubview(posXRow)

        // Position Y row
        let posYRow = createLabeledControlRow(label: "Position Y:", control: irisPositionYSlider)
        stack.addArrangedSubview(posYRow)

        // Softness row
        let softnessRow = createLabeledControlRow(label: "Softness:", control: irisSoftnessSlider)
        stack.addArrangedSubview(softnessRow)
    }

    private func addBlindsControls(to stack: NSStackView) {
        let titleLabel = NSTextField(labelWithString: "Blinds Parameters")
        titleLabel.font = .boldSystemFont(ofSize: NSFont.systemFontSize)
        stack.addArrangedSubview(titleLabel)

        // Orientation row
        let orientationRow = createLabeledControlRow(label: "Orientation:", control: blindsOrientationDropdown)
        stack.addArrangedSubview(orientationRow)

        // Slat count row
        let slatCountRow = createLabeledControlRow(
            label: "Slat Count:",
            control: blindsSlatCountSlider,
            secondaryControl: blindsSlatCountLabel
        )
        stack.addArrangedSubview(slatCountRow)
    }

    private func setupActionButtons() {
        let buttonStack = NSStackView()
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 12
        buttonStack.distribution = .fillEqually

        buttonStack.addArrangedSubview(applyButton)
        buttonStack.addArrangedSubview(resetButton)
        buttonStack.addArrangedSubview(deleteButton)

        view.addSubview(buttonStack)

        NSLayoutConstraint.activate([
            buttonStack.topAnchor.constraint(equalTo: tabView.bottomAnchor, constant: 12),
            buttonStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            buttonStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            buttonStack.heightAnchor.constraint(equalToConstant: 32)
        ])
    }

    // MARK: - Load Transition Values

    private func loadTransitionValues() {
        // Load basic properties
        durationSlider.doubleValue = transition.duration.seconds
        durationLabel.stringValue = String(format: "%.1fs", transition.duration.seconds)

        if let typeIndex = typeDropdown.itemArray.firstIndex(where: { $0.representedObject as? TransitionType == transition.type }) {
            typeDropdown.selectItem(at: typeIndex)
        }

        enabledCheckbox.state = transition.isEnabled ? .on : .off

        // Load type-specific parameters
        loadParametersValues()
    }

    private func loadParametersValues() {
        switch transition.parameters {
        case .crossfade:
            break // No parameters

        case .fadeToColor(let color, let holdDuration):
            fadeColorWell.color = NSColor(
                calibratedRed: CGFloat(color.red),
                green: CGFloat(color.green),
                blue: CGFloat(color.blue),
                alpha: CGFloat(color.alpha)
            )
            fadeHoldDurationSlider.doubleValue = holdDuration

        case .wipe(let direction, let softness, let borderWidth):
            if let index = wipeDirectionDropdown.itemArray.firstIndex(where: { $0.representedObject as? WipeDirection == direction }) {
                wipeDirectionDropdown.selectItem(at: index)
            }
            wipeSoftnessSlider.doubleValue = softness
            wipeBorderWidthSlider.doubleValue = borderWidth

        case .iris(let shape, let position, let softness):
            if let index = irisShapeDropdown.itemArray.firstIndex(where: { $0.representedObject as? IrisShape == shape }) {
                irisShapeDropdown.selectItem(at: index)
            }
            irisPositionXSlider.doubleValue = Double(position.x)
            irisPositionYSlider.doubleValue = Double(position.y)
            irisSoftnessSlider.doubleValue = softness

        case .blinds(let orientation, let slatCount):
            if let index = blindsOrientationDropdown.itemArray.firstIndex(where: { $0.representedObject as? BlindsOrientation == orientation }) {
                blindsOrientationDropdown.selectItem(at: index)
            }
            blindsSlatCountSlider.doubleValue = Double(slatCount)
            blindsSlatCountLabel.stringValue = "\(slatCount)"

        case .custom:
            break // Custom parameters not editable
        }
    }

    // MARK: - Control Actions

    @objc private func durationChanged(_ sender: NSSlider) {
        let duration = sender.doubleValue
        durationLabel.stringValue = String(format: "%.1fs", duration)

        let newDuration = CMTime(seconds: duration, preferredTimescale: 600)
        transition = transition.withDuration(newDuration)
    }

    @objc private func typeChanged(_ sender: NSPopUpButton) {
        guard let selectedItem = sender.selectedItem,
              let newType = selectedItem.representedObject as? TransitionType else {
            return
        }

        // Update transition with new type (resets to default parameters)
        transition = transition.withType(newType)

        // Reload parameter controls for new type
        reloadParameterControls()
    }

    @objc private func enabledChanged(_ sender: NSButton) {
        let isEnabled = sender.state == .on
        transition = transition.withEnabled(isEnabled)
    }

    @objc private func fadeColorChanged(_ sender: NSColorWell) {
        guard case .fadeToColor(_, let holdDuration) = transition.parameters else { return }

        let color = sender.color
        let transitionColor = TransitionColor(
            red: Double(color.redComponent),
            green: Double(color.greenComponent),
            blue: Double(color.blueComponent),
            alpha: Double(color.alphaComponent)
        )

        let newParameters = TransitionParameters.fadeToColor(color: transitionColor, holdDuration: holdDuration)
        transition = transition.withParameters(newParameters)
    }

    @objc private func fadeHoldDurationChanged(_ sender: NSSlider) {
        guard case .fadeToColor(let color, _) = transition.parameters else { return }

        let holdDuration = sender.doubleValue
        let newParameters = TransitionParameters.fadeToColor(color: color, holdDuration: holdDuration)
        transition = transition.withParameters(newParameters)
    }

    @objc private func wipeDirectionChanged(_ sender: NSPopUpButton) {
        guard case .wipe(_, let softness, let borderWidth) = transition.parameters,
              let selectedItem = sender.selectedItem,
              let newDirection = selectedItem.representedObject as? WipeDirection else {
            return
        }

        let newParameters = TransitionParameters.wipe(direction: newDirection, softness: softness, borderWidth: borderWidth)
        transition = transition.withParameters(newParameters)
    }

    @objc private func wipeSoftnessChanged(_ sender: NSSlider) {
        guard case .wipe(let direction, _, let borderWidth) = transition.parameters else { return }

        let softness = sender.doubleValue
        let newParameters = TransitionParameters.wipe(direction: direction, softness: softness, borderWidth: borderWidth)
        transition = transition.withParameters(newParameters)
    }

    @objc private func wipeBorderWidthChanged(_ sender: NSSlider) {
        guard case .wipe(let direction, let softness, _) = transition.parameters else { return }

        let borderWidth = sender.doubleValue
        let newParameters = TransitionParameters.wipe(direction: direction, softness: softness, borderWidth: borderWidth)
        transition = transition.withParameters(newParameters)
    }

    @objc private func irisShapeChanged(_ sender: NSPopUpButton) {
        guard case .iris(_, let position, let softness) = transition.parameters,
              let selectedItem = sender.selectedItem,
              let newShape = selectedItem.representedObject as? IrisShape else {
            return
        }

        let newParameters = TransitionParameters.iris(shape: newShape, position: position, softness: softness)
        transition = transition.withParameters(newParameters)
    }

    @objc private func irisPositionChanged(_ sender: NSSlider) {
        guard case .iris(let shape, _, let softness) = transition.parameters else { return }

        let newPosition = CGPoint(x: irisPositionXSlider.doubleValue, y: irisPositionYSlider.doubleValue)
        let newParameters = TransitionParameters.iris(shape: shape, position: newPosition, softness: softness)
        transition = transition.withParameters(newParameters)
    }

    @objc private func irisSoftnessChanged(_ sender: NSSlider) {
        guard case .iris(let shape, let position, _) = transition.parameters else { return }

        let softness = sender.doubleValue
        let newParameters = TransitionParameters.iris(shape: shape, position: position, softness: softness)
        transition = transition.withParameters(newParameters)
    }

    @objc private func blindsOrientationChanged(_ sender: NSPopUpButton) {
        guard case .blinds(_, let slatCount) = transition.parameters,
              let selectedItem = sender.selectedItem,
              let newOrientation = selectedItem.representedObject as? BlindsOrientation else {
            return
        }

        let newParameters = TransitionParameters.blinds(orientation: newOrientation, slatCount: slatCount)
        transition = transition.withParameters(newParameters)
    }

    @objc private func blindsSlatCountChanged(_ sender: NSSlider) {
        guard case .blinds(let orientation, _) = transition.parameters else { return }

        let slatCount = Int(sender.doubleValue)
        blindsSlatCountLabel.stringValue = "\(slatCount)"

        let newParameters = TransitionParameters.blinds(orientation: orientation, slatCount: slatCount)
        transition = transition.withParameters(newParameters)
    }

    // MARK: - Button Actions

    @objc private func applyClicked(_ sender: NSButton) {
        onApply(transition)
        dismiss(sender)
    }

    @objc private func resetClicked(_ sender: NSButton) {
        transition = originalTransition
        loadTransitionValues()
    }

    @objc private func deleteClicked(_ sender: NSButton) {
        let alert = NSAlert()
        alert.messageText = "Delete Transition"
        alert.informativeText = "Are you sure you want to delete this transition?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            onDelete()
            dismiss(sender)
        }
    }

    // MARK: - Helper Methods

    private func reloadParameterControls() {
        // Remove old parameter controls
        propertiesContentView.subviews.forEach { $0.removeFromSuperview() }

        // Recreate properties tab with new controls
        setupPropertiesTab()
        loadTransitionValues()
    }
}
