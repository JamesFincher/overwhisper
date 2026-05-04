import AppKit
import Carbon.HIToolbox

class TextInserter {

    private struct PasteboardSnapshot {
        private struct Item {
            let contentsByType: [(type: NSPasteboard.PasteboardType, data: Data)]
        }

        private let items: [Item]

        init(pasteboard: NSPasteboard) {
            items = pasteboard.pasteboardItems?.map { item in
                Item(
                    contentsByType: item.types.compactMap { type in
                        guard let data = item.data(forType: type) else {
                            return nil
                        }
                        return (type, data)
                    }
                )
            } ?? []
        }

        func restore(to pasteboard: NSPasteboard) {
            pasteboard.clearContents()

            let pasteboardItems = items.compactMap { item -> NSPasteboardItem? in
                guard !item.contentsByType.isEmpty else {
                    return nil
                }

                let pasteboardItem = NSPasteboardItem()
                for content in item.contentsByType {
                    pasteboardItem.setData(content.data, forType: content.type)
                }
                return pasteboardItem
            }

            guard !pasteboardItems.isEmpty else {
                return
            }

            if !pasteboard.writeObjects(pasteboardItems) {
                AppLogger.system.error("Failed to restore previous clipboard contents")
            }
        }
    }

    /// Check if accessibility permission is granted
    static func hasAccessibilityPermission() -> Bool {
        return AXIsProcessTrusted()
    }

    /// Prompt the user to grant accessibility permission
    /// Returns true if permission is already granted
    static func requestAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Insert text at the current cursor position
    /// Returns true if auto-paste was attempted, false if text was only copied to clipboard
    @discardableResult
    func insertText(_ text: String) -> Bool {
        let pasteboard = NSPasteboard.general

        // Check accessibility permission before attempting paste
        guard Self.hasAccessibilityPermission() else {
            // No permission - just copy to clipboard (don't restore previous)
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            AppLogger.system.warning("Accessibility permission not granted - text copied to clipboard only")
            return false
        }

        // Save every current clipboard item/type so rich text, images, and file URLs survive auto-paste.
        let previousContents = PasteboardSnapshot(pasteboard: pasteboard)

        // Copy transcription to clipboard
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Small delay to ensure clipboard is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            // Simulate Cmd+V
            let didPaste = self?.simulatePaste() ?? false

            guard didPaste else {
                AppLogger.system.warning("Paste failed - transcription left on clipboard")
                return
            }

            // Restore original clipboard after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                previousContents.restore(to: pasteboard)
            }
        }

        return true
    }

    private func simulatePaste() -> Bool {
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            AppLogger.system.error("Failed to create event source")
            return false
        }

        let vKeyCode: CGKeyCode = CGKeyCode(kVK_ANSI_V)

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true) else {
            AppLogger.system.error("Failed to create key down event")
            return false
        }
        keyDown.flags = .maskCommand

        guard let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) else {
            AppLogger.system.error("Failed to create key up event")
            return false
        }
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)

        return true
    }

    // Alternative method using Accessibility API (more reliable in some apps)
    func insertTextViaAccessibility(_ text: String) {
        let systemWideElement = AXUIElementCreateSystemWide()

        var focusedElement: AnyObject?
        let error = AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )

        guard error == .success, let element = focusedElement else {
            // Fall back to clipboard method
            insertText(text)
            return
        }

        // Try to set the value directly
        let setError = AXUIElementSetAttributeValue(
            element as! AXUIElement,
            kAXValueAttribute as CFString,
            text as CFTypeRef
        )

        if setError != .success {
            // Fall back to clipboard method
            insertText(text)
        }
    }
}
