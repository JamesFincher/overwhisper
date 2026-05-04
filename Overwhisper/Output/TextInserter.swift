import AppKit
import Carbon.HIToolbox

@MainActor
class TextInserter {
    enum InsertionResult {
        case pasted
        case copiedToClipboard(CopyFallbackReason)
    }

    enum CopyFallbackReason {
        case accessibilityPermissionMissing
        case pasteFailed

        var notificationBody: String {
            switch self {
            case .accessibilityPermissionMissing:
                return "Accessibility permission needed for auto-paste. Text copied to clipboard - press Cmd+V to paste."
            case .pasteFailed:
                return "Auto-paste failed. Text copied to clipboard - press Cmd+V to paste."
            }
        }
    }

    private let pasteboardDelay: UInt64 = 100_000_000

    private struct PasteboardSnapshot {
        let items: [Item]

        init(from pasteboard: NSPasteboard) {
            items = pasteboard.pasteboardItems?.map(Item.init) ?? []
        }

        func restore(to pasteboard: NSPasteboard) {
            pasteboard.clearContents()
            guard !items.isEmpty else { return }
            pasteboard.writeObjects(items.map { $0.pasteboardItem })
        }

        struct Item {
            let values: [(type: NSPasteboard.PasteboardType, data: Data)]

            init(item: NSPasteboardItem) {
                values = item.types.compactMap { type in
                    guard let data = item.data(forType: type) else { return nil }
                    return (type, data)
                }
            }

            var pasteboardItem: NSPasteboardItem {
                let item = NSPasteboardItem()
                for value in values {
                    item.setData(value.data, forType: value.type)
                }
                return item
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
    /// Returns whether auto-paste succeeded or text was left on the clipboard for manual paste.
    @discardableResult
    func insertText(_ text: String) async -> InsertionResult {
        let pasteboard = NSPasteboard.general

        // Check accessibility permission before attempting paste
        guard Self.hasAccessibilityPermission() else {
            // No permission - just copy to clipboard (don't restore previous)
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            AppLogger.system.warning("Accessibility permission not granted - text copied to clipboard only")
            return .copiedToClipboard(.accessibilityPermissionMissing)
        }

        // Save every current clipboard item/type so rich text, images, and file URLs survive auto-paste.
        let previousContents = PasteboardSnapshot(from: pasteboard)

        // Copy transcription to clipboard
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Small delay to ensure clipboard is ready
        do {
            try await Task.sleep(nanoseconds: pasteboardDelay)
        } catch {
            AppLogger.system.warning("Paste cancelled before Cmd+V was sent - text left on clipboard")
            return .copiedToClipboard(.pasteFailed)
        }

        guard simulatePaste() else {
            // Paste failed - keep transcription on the clipboard for manual paste.
            return .copiedToClipboard(.pasteFailed)
        }

        // Restore original clipboard after paste has been reported as sent.
        do {
            try await Task.sleep(nanoseconds: pasteboardDelay)
        } catch {
            AppLogger.system.warning("Paste succeeded but clipboard restore was cancelled")
            return .pasted
        }

        previousContents.restore(to: pasteboard)

        return .pasted
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
    @discardableResult
    func insertTextViaAccessibility(_ text: String) async -> InsertionResult {
        let systemWideElement = AXUIElementCreateSystemWide()

        var focusedElement: AnyObject?
        let error = AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )

        guard error == .success, let element = focusedElement else {
            // Fall back to clipboard method
            return await insertText(text)
        }

        // Try to set the value directly
        let setError = AXUIElementSetAttributeValue(
            element as! AXUIElement,
            kAXValueAttribute as CFString,
            text as CFTypeRef
        )

        if setError != .success {
            // Fall back to clipboard method
            return await insertText(text)
        }

        return .pasted
    }
}
