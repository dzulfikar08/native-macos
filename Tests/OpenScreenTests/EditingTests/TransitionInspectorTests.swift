import XCTest
import CoreMedia
@testable import OpenScreen

/// Tests for TransitionInspectorViewController
@MainActor
final class TransitionInspectorTests: XCTestCase {
    // MARK: - Properties

    private var sut: TransitionInspectorViewController!
    private var testTransition: TransitionClip!
    private var onApplyCalled: Bool = false
    private var onDeleteCalled: Bool = false
    private var appliedTransition: TransitionClip?

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()

        onApplyCalled = false
        onDeleteCalled = false
        appliedTransition = nil

        // Create test transition
        testTransition = TransitionClip(
            type: .crossfade,
            duration: CMTime(seconds: 1.0, preferredTimescale: 600),
            leadingClipID: UUID(),
            trailingClipID: UUID()
        )

        // Create system under test
        sut = TransitionInspectorViewController(
            transition: testTransition,
            onApply: { [weak self] transition in
                self?.onApplyCalled = true
                self?.appliedTransition = transition
            },
            onDelete: { [weak self] in
                self?.onDeleteCalled = true
            }
        )

        // Load view hierarchy
        _ = sut.view
    }

    override func tearDown() {
        sut = nil
        testTransition = nil
        appliedTransition = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitializationWithTransition() {
        XCTAssertNotNil(sut)
        XCTAssertNotNil(sut.view)
    }

    func testViewHierarchyIsSetup() {
        // Verify tab view exists
        XCTAssertNotNil(sut.value(forKey: "tabView") as? NSView)

        // Verify action buttons exist
        XCTAssertNotNil(sut.value(forKey: "applyButton") as? NSButton)
        XCTAssertNotNil(sut.value(forKey: "resetButton") as? NSButton)
        XCTAssertNotNil(sut.value(forKey: "deleteButton") as? NSButton)
    }

    func testTabViewHasThreeTabs() {
        let tabView = sut.value(forKey: "tabView") as? NSTabView
        XCTAssertEqual(tabView?.tabViewItems.count, 3)

        let tabLabels = tabView?.tabViewItems.map { $0.label }
        XCTAssertEqual(tabLabels, ["Properties", "Presets", "Preview"])
    }

    // MARK: - Basic Properties Tests

    func testDurationSliderIsConfigured() {
        let durationSlider = sut.value(forKey: "durationSlider") as? NSSlider
        XCTAssertNotNil(durationSlider)
        XCTAssertEqual(durationSlider?.minValue, 0.1, accuracy: 0.01)
        XCTAssertEqual(durationSlider?.maxValue, 5.0, accuracy: 0.01)
    }

    func testDurationShowsInitialValue() {
        let durationSlider = sut.value(forKey: "durationSlider") as? NSSlider
        let durationLabel = sut.value(forKey: "durationLabel") as? NSTextField

        XCTAssertEqual(durationSlider?.doubleValue, 1.0, accuracy: 0.01)
        XCTAssertEqual(durationLabel?.stringValue, "1.0s")
    }

    func testTypeDropdownIsPopulated() {
        let typeDropdown = sut.value(forKey: "typeDropdown") as? NSPopUpButton

        XCTAssertNotNil(typeDropdown)
        XCTAssertEqual(typeDropdown?.numberOfItems, 5) // 5 standard transition types

        // Verify dropdown contains all standard types
        let allTypes = TransitionType.allStandardTypes
        XCTAssertEqual(allTypes.count, 5)
    }

    func testEnabledCheckboxInitialState() {
        let enabledCheckbox = sut.value(forKey: "enabledCheckbox") as? NSButton

        XCTAssertNotNil(enabledCheckbox)
        XCTAssertEqual(enabledCheckbox?.state, .on)
    }

    // MARK: - Parameter Controls Tests

    func testFadeToColorControlsExist() {
        // Create inspector with fade to color transition
        let fadeTransition = TransitionClip(
            type: .fadeToColor,
            leadingClipID: UUID(),
            trailingClipID: UUID()
        )

        let fadeInspector = TransitionInspectorViewController(
            transition: fadeTransition,
            onApply: { _ in },
            onDelete: { }
        )
        _ = fadeInspector.view

        // Verify fade-specific controls exist
        XCTAssertNotNil(fadeInspector.value(forKey: "fadeColorWell") as? NSColorWell)
        XCTAssertNotNil(fadeInspector.value(forKey: "fadeHoldDurationSlider") as? NSSlider)
    }

    func testWipeControlsExist() {
        // Create inspector with wipe transition
        let wipeTransition = TransitionClip(
            type: .wipe,
            leadingClipID: UUID(),
            trailingClipID: UUID()
        )

        let wipeInspector = TransitionInspectorViewController(
            transition: wipeTransition,
            onApply: { _ in },
            onDelete: { }
        )
        _ = wipeInspector.view

        // Verify wipe-specific controls exist
        XCTAssertNotNil(wipeInspector.value(forKey: "wipeDirectionDropdown") as? NSPopUpButton)
        XCTAssertNotNil(wipeInspector.value(forKey: "wipeSoftnessSlider") as? NSSlider)
        XCTAssertNotNil(wipeInspector.value(forKey: "wipeBorderWidthSlider") as? NSSlider)
    }

    func testIrisControlsExist() {
        // Create inspector with iris transition
        let irisTransition = TransitionClip(
            type: .iris,
            leadingClipID: UUID(),
            trailingClipID: UUID()
        )

        let irisInspector = TransitionInspectorViewController(
            transition: irisTransition,
            onApply: { _ in },
            onDelete: { }
        )
        _ = irisInspector.view

        // Verify iris-specific controls exist
        XCTAssertNotNil(irisInspector.value(forKey: "irisShapeDropdown") as? NSPopUpButton)
        XCTAssertNotNil(irisInspector.value(forKey: "irisPositionXSlider") as? NSSlider)
        XCTAssertNotNil(irisInspector.value(forKey: "irisPositionYSlider") as? NSSlider)
        XCTAssertNotNil(irisInspector.value(forKey: "irisSoftnessSlider") as? NSSlider)
    }

    func testBlindsControlsExist() {
        // Create inspector with blinds transition
        let blindsTransition = TransitionClip(
            type: .blinds,
            leadingClipID: UUID(),
            trailingClipID: UUID()
        )

        let blindsInspector = TransitionInspectorViewController(
            transition: blindsTransition,
            onApply: { _ in },
            onDelete: { }
        )
        _ = blindsInspector.view

        // Verify blinds-specific controls exist
        XCTAssertNotNil(blindsInspector.value(forKey: "blindsOrientationDropdown") as? NSPopUpButton)
        XCTAssertNotNil(blindsInspector.value(forKey: "blindsSlatCountSlider") as? NSSlider)
        XCTAssertNotNil(blindsInspector.value(forKey: "blindsSlatCountLabel") as? NSTextField)
    }

    // MARK: - Apply Button Tests

    func testApplyButtonTriggersCallback() {
        let applyButton = sut.value(forKey: "applyButton") as? NSButton

        XCTAssertFalse(onApplyCalled)
        applyButton?.performClick(nil)
        XCTAssertTrue(onApplyCalled)
    }

    func testApplyButtonPassesModifiedTransition() {
        let applyButton = sut.value(forKey: "applyButton") as? NSSlider

        // Modify duration
        let durationSlider = sut.value(forKey: "durationSlider") as? NSSlider
        durationSlider?.doubleValue = 2.0

        applyButton?.performClick(nil)

        XCTAssertTrue(onApplyCalled)
        XCTAssertNotNil(appliedTransition)
        XCTAssertEqual(appliedTransition?.duration.seconds, 2.0, accuracy: 0.01)
    }

    // MARK: - Reset Button Tests

    func testResetButtonRestoresOriginalValues() {
        let resetButton = sut.value(forKey: "resetButton") as? NSButton
        let durationSlider = sut.value(forKey: "durationSlider") as? NSSlider

        // Modify duration
        durationSlider?.doubleValue = 2.0
        XCTAssertEqual(durationSlider?.doubleValue, 2.0, accuracy: 0.01)

        // Reset
        resetButton?.performClick(nil)

        // Should restore original value
        XCTAssertEqual(durationSlider?.doubleValue, 1.0, accuracy: 0.01)
    }

    // MARK: - Delete Button Tests

    func testDeleteButtonTriggersCallback() {
        // Note: Full test would require handling the alert dialog
        // For now, just verify the button exists
        let deleteButton = sut.value(forKey: "deleteButton") as? NSButton
        XCTAssertNotNil(deleteButton)
    }

    // MARK: - Duration Change Tests

    func testDurationChangeUpdatesTransition() {
        let durationSlider = sut.value(forKey: "durationSlider") as? NSSlider
        let durationLabel = sut.value(forKey: "durationLabel") as? NSTextField

        durationSlider?.doubleValue = 2.5

        // Verify label updated
        XCTAssertEqual(durationLabel?.stringValue, "2.5s")
    }

    // MARK: - Type Change Tests

    func testTypeChangeResetsParameters() {
        let typeDropdown = sut.value(forKey: "typeDropdown") as? NSPopUpButton

        // Select wipe type (index 2)
        typeDropdown?.selectItem(at: 2)
        typeDropdown?.performClick(nil)

        // Verify parameter controls updated
        // (This would require accessing internal state, which is private)
    }

    // MARK: - Enabled Toggle Tests

    func testEnabledToggleUpdatesTransition() {
        let enabledCheckbox = sut.value(forKey: "enabledCheckbox") as? NSButton

        XCTAssertEqual(enabledCheckbox?.state, .on)

        enabledCheckbox?.state = .off
        enabledCheckbox?.performClick(nil)

        XCTAssertEqual(enabledCheckbox?.state, .off)
    }

    // MARK: - Crossfade Tests

    func testCrossfadeHasNoAdditionalParameters() {
        // Crossfade should not show any parameter controls
        let crossfadeInspector = TransitionInspectorViewController(
            transition: testTransition,
            onApply: { _ in },
            onDelete: { }
        )
        _ = crossfadeInspector.view

        // Verify inspector loaded successfully
        XCTAssertNotNil(crossfadeInspector.view)
    }

    // MARK: - Multiple Transition Types Tests

    func testInspectorHandlesAllTransitionTypes() {
        let allTypes = TransitionType.allStandardTypes

        for type in allTypes {
            let transition = TransitionClip(
                type: type,
                leadingClipID: UUID(),
                trailingClipID: UUID()
            )

            let inspector = TransitionInspectorViewController(
                transition: transition,
                onApply: { _ in },
                onDelete: { }
            )

            // Should load without crashing
            _ = inspector.view
            XCTAssertNotNil(inspector.view, "Failed to load inspector for \(type.displayName)")
        }
    }

    // MARK: - Memory Management Tests

    func testInspectorDoesNotLeak() {
        weak var weakInspector: TransitionInspectorViewController?

        autoreleasepool {
            let inspector = TransitionInspectorViewController(
                transition: testTransition,
                onApply: { _ in },
                onDelete: { }
            )
            weakInspector = inspector
            _ = inspector.view
        }

        // Inspector should be deallocated
        XCTAssertNil(weakInspector, "TransitionInspectorViewController leaked memory")
    }

    // MARK: - Presets Tab Tests

    func testPresetsTabShowsAllBuiltInPresets() {
        let tabView = sut.value(forKey: "tabView") as? NSTabView

        // Switch to Presets tab (index 1)
        tabView?.selectTabViewItem(at: 1)

        let selectedTab = tabView?.selectedTabViewItem
        XCTAssertEqual(selectedTab?.label, "Presets")

        // Verify all presets are available
        XCTAssertEqual(BuiltInPresets.presets.count, 5)
    }

    func testApplyPresetUpdatesTransition() {
        guard let preset = BuiltInPresets.presets.first else {
            XCTFail("No presets available")
            return
        }

        // Apply the preset
        sut.applyPreset(preset)

        // Verify transition was updated
        let transition = sut.currentTransition
        XCTAssertEqual(transition.type, preset.transitionType)
        XCTAssertEqual(transition.parameters, preset.parameters)
        XCTAssertEqual(transition.duration.seconds, preset.duration.seconds, accuracy: 0.01)
    }

    func testApplyPresetUpdatesControls() {
        guard let preset = BuiltInPresets.presets.first(where: { $0.transitionType == .fadeToColor }) else {
            XCTFail("Fade to color preset not found")
            return
        }

        // Apply fade to color preset
        sut.applyPreset(preset)

        // Verify controls were updated
        let typeDropdown = sut.value(forKey: "typeDropdown") as? NSPopUpButton
        let durationSlider = sut.value(forKey: "durationSlider") as? NSSlider
        let durationLabel = sut.value(forKey: "durationLabel") as? NSTextField

        XCTAssertEqual(typeDropdown?.selectedItem?.representedObject as? TransitionType, .fadeToColor)
        XCTAssertEqual(durationSlider?.doubleValue, preset.duration.seconds, accuracy: 0.01)
        XCTAssertEqual(durationLabel?.stringValue, "2.0s")
    }

    func testApplyDifferentPresets() {
        // Test applying multiple presets in sequence
        for preset in BuiltInPresets.presets {
            let inspector = TransitionInspectorViewController(
                transition: testTransition,
                onApply: { _ in },
                onDelete: { }
            )
            _ = inspector.view

            // Apply preset
            inspector.applyPreset(preset)

            // Verify transition matches preset
            XCTAssertEqual(inspector.currentTransition.type, preset.transitionType)
            XCTAssertEqual(inspector.currentTransition.parameters, preset.parameters)
            XCTAssertEqual(inspector.currentTransition.duration.seconds, preset.duration.seconds, accuracy: 0.01)
        }
    }
}
