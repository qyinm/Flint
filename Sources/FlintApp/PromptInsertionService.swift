import AppKit
import ApplicationServices

struct PromptInsertionService {
    enum InsertionResult: Equatable {
        case copiedToClipboard
        case directInsertSucceeded
        case accessibilityPermissionDenied
        case directInsertFailed(String)
    }

    func copyToClipboard(_ text: String) -> InsertionResult {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        return .copiedToClipboard
    }

    func insertIntoFocusedElementOrCopy(_ text: String) -> InsertionResult {
        guard isAccessibilityTrusted(prompt: true) else {
            _ = copyToClipboard(text)
            return .accessibilityPermissionDenied
        }

        let systemWide = AXUIElementCreateSystemWide()
        var focusedObject: CFTypeRef?
        let focusStatus = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedObject
        )

        guard focusStatus == .success, let focusedObject else {
            _ = copyToClipboard(text)
            return .directInsertFailed("No focused text element was available; copied prompt to clipboard instead.")
        }

        let focusedElement = unsafeDowncast(focusedObject as AnyObject, to: AXUIElement.self)
        let setStatus = AXUIElementSetAttributeValue(
            focusedElement,
            kAXValueAttribute as CFString,
            text as CFTypeRef
        )

        guard setStatus == .success else {
            _ = copyToClipboard(text)
            return .directInsertFailed("Focused element rejected direct text insertion; copied prompt to clipboard instead.")
        }

        return .directInsertSucceeded
    }

    private func isAccessibilityTrusted(prompt: Bool) -> Bool {
        let options = ["AXTrustedCheckOptionPrompt": prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}
