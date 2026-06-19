import AppKit
import Carbon.HIToolbox

final class GlobalHotkeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var localMonitor: Any?

    var onActivate: (() -> Void)?
    var onDismiss: (() -> Void)?
    var onConfirm: (() -> Void)?
    var onNavigate: ((Int) -> Void)?

    // Static ref for C-convention callback
    private static weak var instance: GlobalHotkeyManager?

    func startGlobalMonitoring() {
        guard hotKeyRef == nil else { return }
        GlobalHotkeyManager.instance = self

        // Register Cmd+Shift+V as a system hotkey — no permission required
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = fourCharCode("CLPH")
        hotKeyID.id = 1

        let status = RegisterEventHotKey(
            UInt32(kVK_ANSI_V),
            UInt32(cmdKey | shiftKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        NSLog("[CH] RegisterEventHotKey status: \(status), ref: \(String(describing: hotKeyRef))")

        // InstallApplicationEventHandler is a C inline — use InstallEventHandler directly
        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, _, _) -> OSStatus in
                NSLog("[CH] Hotkey event fired!")
                DispatchQueue.main.async {
                    GlobalHotkeyManager.instance?.onActivate?()
                }
                return noErr
            },
            1,
            &eventSpec,
            nil,
            &eventHandlerRef
        )
        NSLog("[CH] InstallEventHandler status: \(handlerStatus)")
    }

    func startLocalMonitoring() {
        guard localMonitor == nil else { return }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            return self?.handleLocalEvent(event) ?? event
        }
    }

    func stopLocalMonitoring() {
        if let l = localMonitor { NSEvent.removeMonitor(l) }
        localMonitor = nil
    }

    func stop() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let ref = eventHandlerRef {
            RemoveEventHandler(ref)
            eventHandlerRef = nil
        }
        stopLocalMonitoring()
    }

    private func handleLocalEvent(_ event: NSEvent) -> NSEvent? {
        switch event.keyCode {
        case 53: // ESC
            DispatchQueue.main.async { [weak self] in self?.onDismiss?() }
            return nil
        case 36, 76: // Return, numpad Enter
            DispatchQueue.main.async { [weak self] in self?.onConfirm?() }
            return nil
        case 125: // Down arrow
            DispatchQueue.main.async { [weak self] in self?.onNavigate?(1) }
            return nil
        case 126: // Up arrow
            DispatchQueue.main.async { [weak self] in self?.onNavigate?(-1) }
            return nil
        default:
            return event
        }
    }
}

private func fourCharCode(_ string: String) -> OSType {
    var result: OSType = 0
    for byte in string.utf8.prefix(4) {
        result = result << 8 | OSType(byte)
    }
    return result
}
