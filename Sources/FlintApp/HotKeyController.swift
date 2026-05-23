import AppKit
import Carbon.HIToolbox

final class HotKeyController {
    private var hotKeyRef: EventHotKeyRef?
    private let action: () -> Void
    nonisolated(unsafe) private static var activeController: HotKeyController?

    init(action: @escaping () -> Void) {
        self.action = action
        Self.activeController = self
        registerDefaultHotKey()
    }

    deinit {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
    }

    private func registerDefaultHotKey() {
        let hotKeyID = EventHotKeyID(signature: OSType("FLNT".fourCharCode), id: 1)
        let modifiers = UInt32(cmdKey | shiftKey)
        let keyCode = UInt32(kVK_Space)

        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        guard status == noErr else {
            NSLog("Flint failed to register global hotkey: \\(status)")
            return
        }

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hotKeyID = EventHotKeyID()
            GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            if hotKeyID.id == 1 {
                DispatchQueue.main.async {
                    HotKeyController.activeController?.action()
                }
            }
            return noErr
        }, 1, &eventType, nil, nil)
    }
}

private extension String {
    var fourCharCode: UInt32 {
        utf8.reduce(0) { ($0 << 8) + UInt32($1) }
    }
}
