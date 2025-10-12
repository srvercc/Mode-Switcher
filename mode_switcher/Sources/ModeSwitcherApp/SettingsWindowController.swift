import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()

    private weak var window: NSWindow?

    private override init() {
        super.init()
    }

    func show(manager: DisplayModeManager, shortcutManager: ShortcutManager) {
        if let existingWindow = window {
            update(existingWindow, with: manager, shortcutManager: shortcutManager)
            bringToFront(existingWindow)
            return
        }

        let hostingController = SettingsHostingController(manager: manager, shortcutManager: shortcutManager)
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 360),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        newWindow.title = "Mode Switcher Settings"
        newWindow.isReleasedWhenClosed = false
        newWindow.contentViewController = hostingController
        hostingController.view.layoutSubtreeIfNeeded()
        var fittingSize = hostingController.view.fittingSize
        if fittingSize == .zero {
            fittingSize = NSSize(width: 440, height: 360)
        }
        newWindow.setContentSize(fittingSize)
        newWindow.standardWindowButton(.zoomButton)?.isHidden = true
        newWindow.setFrameAutosaveName("ModeSwitcherSettingsWindow")
        newWindow.center()
        newWindow.delegate = self
        newWindow.collectionBehavior = [.fullScreenAuxiliary, .moveToActiveSpace, .canJoinAllSpaces]
        newWindow.level = .floating
        window = newWindow

        bringToFront(newWindow)
        configure(window: newWindow)
        newWindow.makeKeyAndOrderFront(nil)
        newWindow.orderFrontRegardless()
        newWindow.makeFirstResponder(hostingController.view)
    }

    func windowWillClose(_ notification: Notification) {
        guard let closedWindow = notification.object as? NSWindow,
              closedWindow === window else { return }
        window = nil
    }

    private func update(_ window: NSWindow, with manager: DisplayModeManager, shortcutManager: ShortcutManager) {
        guard let hostingController = window.contentViewController as? SettingsHostingController else { return }
        hostingController.update(manager: manager, shortcutManager: shortcutManager)
        hostingController.view.layoutSubtreeIfNeeded()
        var fittingSize = hostingController.view.fittingSize
        if fittingSize == .zero {
            fittingSize = window.frame.size
        }
        window.setContentSize(fittingSize)
        configure(window: window)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        window.makeFirstResponder(hostingController.view)
    }

    private func bringToFront(_ window: NSWindow) {
        NSApp.activate(ignoringOtherApps: true)
        configure(window: window)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        window.makeFirstResponder(window.contentView)
    }

    private func configure(window: NSWindow) {
        window.level = .floating
        window.collectionBehavior.insert([.canJoinAllSpaces, .fullScreenAuxiliary, .moveToActiveSpace])
    }
}

@MainActor
private final class SettingsHostingController: NSHostingController<SettingsView> {
    private var shortcutManager: ShortcutManager

        init(manager: DisplayModeManager, shortcutManager: ShortcutManager) {
            self.shortcutManager = shortcutManager
            super.init(rootView: SettingsView(displayModeManager: manager, shortcutManager: shortcutManager))
        }

    @available(*, unavailable)
    dynamic required init?(coder aDecoder: NSCoder) {
        nil
    }

    func update(manager: DisplayModeManager, shortcutManager: ShortcutManager) {
        self.shortcutManager = shortcutManager
        rootView = SettingsView(displayModeManager: manager, shortcutManager: shortcutManager)
    }
}
