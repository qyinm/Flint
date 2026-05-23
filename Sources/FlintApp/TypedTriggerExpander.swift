import AppKit
import ApplicationServices
import FlintCore

@MainActor
final class TypedTriggerExpander {
    enum ExpanderError: Error, CustomStringConvertible {
        case accessibilityPermissionDenied
        case eventTapUnavailable

        var description: String {
            switch self {
            case .accessibilityPermissionDenied:
                "Accessibility permission is required for typed trigger expansion."
            case .eventTapUnavailable:
                "Could not create a keyboard event tap for typed trigger expansion."
            }
        }
    }

    private let repository: TemplateRepository
    private let renderer = TemplateRenderer()
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var buffer = ""
    private var expansions: [String: String] = [:]
    private var maximumTriggerLength = 0
    private var isExpanding = false

    init(repository: TemplateRepository) {
        self.repository = repository
    }

    func start() throws {
        try reloadExpansions()
        guard !expansions.isEmpty else { return }
        guard isAccessibilityTrusted(prompt: true) else {
            throw ExpanderError.accessibilityPermissionDenied
        }

        let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let callback: CGEventTapCallBack = { proxy, type, event, userInfo in
            guard let userInfo else { return Unmanaged.passUnretained(event) }
            let expander = Unmanaged<TypedTriggerExpander>.fromOpaque(userInfo).takeUnretainedValue()
            return expander.handle(proxy: proxy, type: type, event: event)
        }

        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            throw ExpanderError.eventTapUnavailable
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        self.eventTap = eventTap
        self.runLoopSource = source
    }

    func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    private func reloadExpansions() throws {
        let templates = try repository.loadTemplates()
        expansions = Dictionary(
            uniqueKeysWithValues: try templates.flatMap { template in
                try template.triggers.typed.map { trigger in
                    (trigger, try renderer.render(template, target: "generic"))
                }
            }
        )
        maximumTriggerLength = expansions.keys.map(\.count).max() ?? 0
    }

    private nonisolated func handle(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            Task { @MainActor in
                if let eventTap {
                    CGEvent.tapEnable(tap: eventTap, enable: true)
                }
            }
            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown else { return Unmanaged.passUnretained(event) }
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let characters = event.characters
        Task { @MainActor in
            self.record(keyCode: keyCode, characters: characters)
        }
        return Unmanaged.passUnretained(event)
    }

    private func record(keyCode: Int64, characters: String?) {
        guard !isExpanding else { return }

        if keyCode == 51 {
            if !buffer.isEmpty { buffer.removeLast() }
            return
        }

        guard let characters, !characters.isEmpty else {
            return
        }

        buffer.append(characters)
        if buffer.count > maximumTriggerLength {
            buffer = String(buffer.suffix(maximumTriggerLength))
        }

        guard let match = expansions.keys.first(where: { buffer.hasSuffix($0) }),
              let expansion = expansions[match] else {
            return
        }

        expand(trigger: match, replacement: expansion)
    }

    private func expand(trigger: String, replacement: String) {
        isExpanding = true
        buffer = ""

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
            self.copyToClipboard(replacement)
            self.postDeletes(count: trigger.count)
            self.postPaste()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                self.isExpanding = false
            }
        }
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func postDeletes(count: Int) {
        guard count > 0 else { return }
        for _ in 0..<count {
            postKey(keyCode: 51)
        }
    }

    private func postPaste() {
        postKey(keyCode: 9, flags: .maskCommand)
    }

    private func postKey(keyCode: CGKeyCode, flags: CGEventFlags = []) {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        keyDown?.flags = flags
        keyUp?.flags = flags
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

    private func isAccessibilityTrusted(prompt: Bool) -> Bool {
        let options = ["AXTrustedCheckOptionPrompt": prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}

private extension CGEvent {
    var characters: String? {
        var length = 0
        var buffer = [UniChar](repeating: 0, count: 8)
        keyboardGetUnicodeString(
            maxStringLength: buffer.count,
            actualStringLength: &length,
            unicodeString: &buffer
        )
        guard length > 0 else { return nil }
        return String(utf16CodeUnits: buffer, count: length)
    }
}
