import SwiftUI
@preconcurrency import MASShortcut
import Carbon.HIToolbox.Events

@MainActor
final class ShortcutManager: NSObject, ObservableObject {
    static let defaultsKey = "ModeSwitcherToggleShortcut"

    @Published private(set) var currentShortcut: MASShortcut

    private let monitor: MASShortcutMonitor
    private let defaultShortcut: MASShortcut
    private let toggleAction: () -> Void

    init?(toggleAction: @escaping () -> Void) {
        guard let monitorInstance = MASShortcutMonitor.shared() else {
            return nil
        }

        let defaultShortcut = MASShortcut(
            keyCode: Int(kVK_ANSI_0),
            modifierFlags: [.command, .shift]
        )

        self.monitor = monitorInstance
        self.defaultShortcut = defaultShortcut
        self.toggleAction = toggleAction

        let storedShortcut = ShortcutManager.loadFromDefaults() ?? defaultShortcut
        currentShortcut = storedShortcut

        super.init()

        applyShortcut(storedShortcut)
    }

    deinit {
        monitor.unregisterAllShortcuts()
    }

    func updateShortcut(_ shortcut: MASShortcut?) {
        let newShortcut = shortcut ?? defaultShortcut
        applyShortcut(newShortcut)
    }

    var displayText: String {
        currentShortcut.description
    }
}

@MainActor
private extension ShortcutManager {
    func applyShortcut(_ shortcut: MASShortcut) {
        monitor.unregisterAllShortcuts()
        if monitor.register(shortcut, withAction: toggleAction) {
            currentShortcut = shortcut
            ShortcutManager.saveToDefaults(shortcut)
        } else if currentShortcut != shortcut {
            // If registration fails, roll back to the current shortcut.
            _ = monitor.register(currentShortcut, withAction: toggleAction)
        }
    }

    static func loadFromDefaults() -> MASShortcut? {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else {
            return nil
        }

        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: MASShortcut.self, from: data)
    }

    static func saveToDefaults(_ shortcut: MASShortcut) {
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: shortcut, requiringSecureCoding: true) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }
}
