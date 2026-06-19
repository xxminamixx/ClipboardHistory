import AppKit
import SwiftUI

@MainActor
final class HistoryPickerWindowController: NSWindowController, NSWindowDelegate {
    private let hotkeyManager: GlobalHotkeyManager
    private let clipboardMonitor: ClipboardMonitor
    private var selectedIndex: Int = 0
    private var previousApp: NSRunningApplication?
    private var isSelectingItem = false

    init(clipboardMonitor: ClipboardMonitor, hotkeyManager: GlobalHotkeyManager) {
        self.clipboardMonitor = clipboardMonitor
        self.hotkeyManager = hotkeyManager

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 240),
            styleMask: [
                .titled,
                .fullSizeContentView,
                // .nonactivatingPanel を外す → キーウィンドウになれるようにする
                .hudWindow
            ],
            backing: .buffered,
            defer: true
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.backgroundColor = .clear
        panel.hasShadow = true

        super.init(window: panel)
        panel.delegate = self
    }

    required init?(coder: NSCoder) { fatalError() }

    func show() {
        guard let panel = window as? NSPanel else { return }

        let history = clipboardMonitor.history
        NSLog("[CH] show() — history count: \(history.count)")
        guard !history.isEmpty else { return }

        // ① フォーカスを渡す前に元アプリを記録
        previousApp = NSWorkspace.shared.frontmostApplication
        NSLog("[CH] previousApp: \(previousApp?.localizedName ?? "nil")")

        selectedIndex = 0
        rebuildView()
        positionPanel(panel)

        hotkeyManager.onDismiss = { [weak self] in self?.dismiss() }
        hotkeyManager.onConfirm = { [weak self] in
            guard let self else { return }
            self.selectItem(at: self.selectedIndex)
        }
        hotkeyManager.onNavigate = { [weak self] delta in
            guard let self else { return }
            let count = self.clipboardMonitor.history.count
            guard count > 0 else { return }
            self.selectedIndex = (self.selectedIndex + delta + count) % count
            self.rebuildView()
        }

        hotkeyManager.startLocalMonitoring()

        // ② 自アプリをアクティブ化してキーウィンドウにする → ↑↓キーが届く
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
        panel.makeKeyAndOrderFront(nil)
    }

    func dismiss() {
        hotkeyManager.onDismiss = nil
        hotkeyManager.onConfirm = nil
        hotkeyManager.onNavigate = nil
        hotkeyManager.stopLocalMonitoring()
        window?.orderOut(nil)

        // ③ 元アプリのフォーカスを返す
        if let app = previousApp {
            NSLog("[CH] dismiss: restoring focus to \(app.localizedName ?? "unknown")")
            app.activate(options: .activateIgnoringOtherApps)
        }
        previousApp = nil
    }

    // パネル外クリックで自動 dismiss（selectItem 中は呼ばない）
    func windowDidResignKey(_ notification: Notification) {
        NSLog("[CH] windowDidResignKey isSelecting=\(isSelectingItem)")
        guard !isSelectingItem else { return }
        dismiss()
    }

    private func rebuildView() {
        let history = clipboardMonitor.history
        let view = HistoryPickerView(
            items: history,
            selectedIndex: selectedIndex,
            onSelect: { [weak self] index in self?.selectItem(at: index) }
        )
        window?.contentView = NSHostingView(rootView: view)
    }

    private func selectItem(at index: Int) {
        guard !isSelectingItem else { return }
        isSelectingItem = true

        let history = clipboardMonitor.history
        guard index < history.count else { isSelectingItem = false; return }
        let item = history[index]

        NSLog("[CH] selectItem[\(index)]: '\(item.text.prefix(30))' targetApp=\(previousApp?.localizedName ?? "nil")")

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.text, forType: .string)
        clipboardMonitor.suppressNextChange()

        let targetApp = previousApp
        dismiss()
        isSelectingItem = false

        // 元アプリがフォーカスを取り戻すのを待ってから Cmd+V
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            NSLog("[CH] paste timer fired, frontmost=\(NSWorkspace.shared.frontmostApplication?.localizedName ?? "nil")")
            PasteHelper.simulatePaste(to: targetApp)

            if !PasteHelper.hasAccessibilityPermission() {
                self.showAccessibilityHintOnce()
            }
        }
    }

    private func showAccessibilityHintOnce() {
        let key = "axHintShownV1"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)

        let alert = NSAlert()
        alert.messageText = "自動ペーストを有効にするには"
        alert.informativeText = """
        テキストはクリップボードにコピーされました。⌘V で貼り付けできます。

        自動ペーストを有効にするには：
        システム設定 → プライバシーとセキュリティ → アクセシビリティ
        で ClipboardHistory を許可してください。
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "システム設定を開く")
        alert.addButton(withTitle: "閉じる")

        if #available(macOS 14.0, *) { NSApp.activate() } else { NSApp.activate(ignoringOtherApps: true) }
        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    private func positionPanel(_ panel: NSPanel) {
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: {
            NSMouseInRect(mouseLocation, $0.frame, false)
        }) ?? NSScreen.main ?? NSScreen.screens[0]
        let screenFrame = screen.visibleFrame
        let panelSize = panel.frame.size

        var origin = NSPoint(
            x: mouseLocation.x - panelSize.width / 2,
            y: mouseLocation.y - panelSize.height - 20
        )

        if origin.y < screenFrame.minY + 8 {
            origin.y = mouseLocation.y + 20
        }

        origin.x = max(screenFrame.minX + 8,
                       min(origin.x, screenFrame.maxX - panelSize.width - 8))
        origin.y = min(origin.y, screenFrame.maxY - panelSize.height - 8)

        panel.setFrameOrigin(origin)
    }
}
