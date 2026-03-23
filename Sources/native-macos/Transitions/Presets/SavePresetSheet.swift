import Cocoa
import Combine

/// Result of save preset sheet
struct PresetSaveResult {
    let name: String
    let folder: String
}

/// Modal dialog for saving a preset as a favorite
@MainActor
final class SavePresetSheet: NSWindowController {

    private let nameTextField = NSTextField()
    private let folderPopUpButton = NSPopUpButton()
    private let saveButton = NSButton()
    private let cancelButton = NSButton()

    private var continuation: CheckedContinuation<PresetSaveResult, Error>?

    /// Transition settings to save (set before showing)
    var transition: TransitionClip?

    /// Available folders
    var availableFolders: [String] = ["My Transitions"]

    /// Show the sheet and return result
    func show() async throws -> PresetSaveResult {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            guard let window = self.window else {
                continuation.resume(throwing: PresetError.saveFailed(reason: "No window"))
                return
            }

            // Reset UI
            nameTextField.stringValue = ""
            saveButton.isEnabled = false
            updateFolderMenu()

            // Show as sheet
            if let parentWindow = NSApp.keyWindow {
                parentWindow.beginSheet(window) { [weak self] response in
                    guard let self = self else { return }

                    if response == .OK {
                        let result = PresetSaveResult(
                            name: self.nameTextField.stringValue,
                            folder: self.folderPopUpButton.titleOfSelectedItem ?? ""
                        )
                        continuation.resume(returning: result)
                    } else {
                        continuation.resume(throwing: PresetError.saveFailed(reason: "Cancelled"))
                    }
                }
            } else {
                continuation.resume(throwing: PresetError.saveFailed(reason: "No parent window"))
            }
        }
    }

    private func updateFolderMenu() {
        folderPopUpButton.removeAllItems()

        for folder in availableFolders {
            folderPopUpButton.addItem(withTitle: folder)
        }

        folderPopUpButton.addItem(withSeparator: NSMenuItem.separator())

        let newItem = NSMenuItem(title: "New Folder...", action: #selector(showNewFolderAlert), keyEquivalent: "")
        newItem.target = self
        folderPopUpButton.menu?.addItem(newItem)
    }

    @objc private func showNewFolderAlert() {
        let alert = NSAlert()
        alert.messageText = "New Folder"
        alert.informativeText = "Enter a name for the new folder:"
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        input.placeholderString = "Folder Name"
        alert.accessoryView = input

        alert.beginSheetModal(for: window!) { response in
            if response == .OK {
                let folderName = input.stringValue.trimmingCharacters(in: .whitespaces)
                if !folderName.isEmpty {
                    self.availableFolders.append(folderName)
                    self.updateFolderMenu()
                    self.folderPopUpButton.selectItem(withTitle: folderName)
                }
            }
        }

        // Focus the input field
        DispatchQueue.main.async {
            window?.makeFirstResponder(input)
        }
    }

    private var isNameValid: Bool {
        !nameTextField.stringValue.trimmingCharacters(in: .whitespaces).isEmpty
    }

    @objc private func nameChanged(_ sender: NSTextField) {
        saveButton.isEnabled = isNameValid
    }
}

extension SavePresetSheet: NSWindowDelegate {
    func windowDidLoad() {
        super.windowDidLoad()

        guard let window = self.window else { return }

        window.title = "Save Transition Preset"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false

        let contentView = NSView()
        window.contentView = contentView

        // Create UI
        let nameLabel = NSTextField(labelWithString: "Name:")
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        nameTextField.placeholderString = "My Dramatic Wipe"
        nameTextField.translatesAutoresizingMaskIntoConstraints = false
        nameTextField.target = self
        nameTextField.action = #selector(nameChanged(_:))

        let folderLabel = NSTextField(labelWithString: "Folder:")
        folderLabel.translatesAutoresizingMaskIntoConstraints = false

        folderPopUpButton.translatesAutoresizingMaskIntoConstraints = false

        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false

        let nameRow = NSStackView()
        nameRow.orientation = .horizontal
        nameRow.spacing = 8
        nameRow.addArrangedSubview(nameLabel)
        nameRow.addArrangedSubview(nameTextField)

        let folderRow = NSStackView()
        folderRow.orientation = .horizontal
        folderRow.spacing = 8
        folderRow.addArrangedSubview(folderLabel)
        folderRow.addArrangedSubview(folderPopUpButton)

        stackView.addArrangedSubview(nameRow)
        stackView.addArrangedSubview(folderRow)

        contentView.addSubview(stackView)

        // Button row
        let buttonRow = NSStackView()
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 8
        buttonRow.translatesAutoresizingMaskIntoConstraints = false
        buttonRow.addArrangedSubview(cancelButton)
        buttonRow.addArrangedSubview(saveButton)
        contentView.addSubview(buttonRow)

        // Configure buttons
        cancelButton.title = "Cancel"
        cancelButton.target = self
        cancelButton.action = #selector(cancelClicked(_:))

        saveButton.title = "Save"
        saveButton.keyEquivalent = "\r"
        saveButton.target = self
        saveButton.action = #selector(saveClicked(_:))
        saveButton.isEnabled = false

        // Constraints
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            buttonRow.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            buttonRow.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            nameTextField.widthAnchor.constraint(equalToConstant: 240),
            folderPopUpButton.widthAnchor.constraint(equalToConstant: 240)
        ])

        // Focus name field on load
        DispatchQueue.main.async {
            window.makeFirstResponder(nameTextField)
        }
    }

    @objc private func cancelClicked(_ sender: NSButton) {
        window?.sheetParent?.endSheet(window!, returnCode: .cancel)
    }

    @objc private func saveClicked(_ sender: NSButton) {
        window?.sheetParent?.endSheet(window!, returnCode: .OK)
    }
}
