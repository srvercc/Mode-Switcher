import AppKit
import SwiftUI

@MainActor
final class ShortcutEditorWindowController: NSObject, NSWindowDelegate {
    static let shared = ShortcutEditorWindowController()

    private weak var window: NSWindow?

    private override init() {
        super.init()
    }

    func show(shortcutManager: ShortcutManager) {
        if let existingWindow = window,
           let hostingController = existingWindow.contentViewController as? NSHostingController<ShortcutEditorView> {
            hostingController.rootView = ShortcutEditorView(shortcutManager: shortcutManager)
            bringToFront(existingWindow)
            return
        }

        let hostingController = NSHostingController(rootView: ShortcutEditorView(shortcutManager: shortcutManager))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 160),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Change Shortcut"
        window.contentViewController = hostingController
        window.isReleasedWhenClosed = false
        window.center()
        window.delegate = self
        self.window = window

        bringToFront(window)
    }

    func windowWillClose(_ notification: Notification) {
        guard let closedWindow = notification.object as? NSWindow,
              closedWindow === window else { return }
        window = nil
    }

    private func bringToFront(_ window: NSWindow) {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

private struct ShortcutEditorView: View {
    @ObservedObject var shortcutManager: ShortcutManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Change Shortcut")
                .font(.headline)

            ShortcutRecorderView(shortcutManager: shortcutManager)
                .frame(height: 36)

            HStack {
                Spacer()
                Button("Done") {
                    window?.performClose(nil)
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 320)
    }

    private var window: NSWindow? {
        NSApp.keyWindow
    }
}
