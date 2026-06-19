import AppKit

struct PasteHelper {

    static func requestAccessibilityPermission() {
        let options: NSDictionary = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ]
        _ = AXIsProcessTrustedWithOptions(options)
    }

    static func hasAccessibilityPermission() -> Bool {
        let options: NSDictionary = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false
        ]
        return AXIsProcessTrustedWithOptions(options)
    }

    static func simulatePaste(to targetApp: NSRunningApplication? = nil) {
        let hasAX = hasAccessibilityPermission()
        NSLog("[CH] simulatePaste: hasAX=\(hasAX), frontmost=\(NSWorkspace.shared.frontmostApplication?.localizedName ?? "nil")")

        let src = CGEventSource(stateID: .combinedSessionState)
        let keyDown = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true)
        let keyUp   = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false)

        guard keyDown != nil, keyUp != nil else {
            NSLog("[CH] simulatePaste: failed to create CGEvent")
            return
        }

        keyDown?.flags = .maskCommand
        keyUp?.flags   = .maskCommand

        if let target = targetApp {
            let pid = target.processIdentifier
            NSLog("[CH] postToPid \(pid) (\(target.localizedName ?? "unknown"))")
            keyDown?.postToPid(pid)
            keyUp?.postToPid(pid)
        } else if let front = NSWorkspace.shared.frontmostApplication {
            let pid = front.processIdentifier
            NSLog("[CH] post to frontmost pid \(pid) (\(front.localizedName ?? "unknown"))")
            keyDown?.postToPid(pid)
            keyUp?.postToPid(pid)
        } else {
            NSLog("[CH] post to session tap (no target)")
            keyDown?.post(tap: .cgAnnotatedSessionEventTap)
            keyUp?.post(tap: .cgAnnotatedSessionEventTap)
        }
    }
}
