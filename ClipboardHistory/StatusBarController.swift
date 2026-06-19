import AppKit

@MainActor
final class StatusBarController {
    private let statusItem: NSStatusItem
    private let onQuit: () -> Void
    private let onRequestAX: () -> Void
    private var axMenuItem: NSMenuItem?
    private var checkTimer: Timer?

    init(onQuit: @escaping () -> Void, onRequestAX: @escaping () -> Void) {
        self.onQuit = onQuit
        self.onRequestAX = onRequestAX
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard",
                                   accessibilityDescription: "Clipboard History")
            button.image?.isTemplate = true
        }

        buildMenu()
        startPermissionCheck()
    }

    private func buildMenu() {
        let menu = NSMenu()

        let axItem = NSMenuItem(
            title: "⚠️ アクセシビリティを許可（自動ペーストに必要）",
            action: #selector(requestAX),
            keyEquivalent: ""
        )
        axItem.target = self
        axItem.isHidden = PasteHelper.hasAccessibilityPermission()
        menu.addItem(axItem)
        self.axMenuItem = axItem

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "ClipboardHistory を終了",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    // 権限が付与されたらメニュー項目を隠す
    private func startPermissionCheck() {
        checkTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.axMenuItem?.isHidden = PasteHelper.hasAccessibilityPermission()
            }
        }
    }

    @objc private func requestAX() {
        onRequestAX()
    }

    @objc private func quit() {
        onQuit()
    }
}
