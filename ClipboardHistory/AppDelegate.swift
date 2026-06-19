import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController!
    private var clipboardMonitor: ClipboardMonitor!
    private var hotkeyManager: GlobalHotkeyManager!
    private var pickerWindowController: HistoryPickerWindowController!
    private var axPermissionTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        clipboardMonitor = ClipboardMonitor()
        hotkeyManager = GlobalHotkeyManager()

        pickerWindowController = HistoryPickerWindowController(
            clipboardMonitor: clipboardMonitor,
            hotkeyManager: hotkeyManager
        )

        statusBarController = StatusBarController(
            onQuit: { NSApplication.shared.terminate(nil) },
            onRequestAX: {
                PasteHelper.requestAccessibilityPermission()
            }
        )

        clipboardMonitor.start()

        hotkeyManager.onActivate = { [weak self] in
            NSLog("[CH] onActivate called → show picker")
            self?.pickerWindowController.show()
        }

        // RegisterEventHotKey needs no special permission
        hotkeyManager.startGlobalMonitoring()
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardMonitor.stop()
        hotkeyManager.stop()
    }
}
