import SwiftUI

@main
struct ModeSwitcherApp: App {
    @StateObject private var displayModeManager: DisplayModeManager
    @StateObject private var shortcutManager: ShortcutManager

    init() {
        let displayManager = DisplayModeManager()
        guard let shortcutManager = ShortcutManager(toggleAction: displayManager.toggleMode) else {
            fatalError("Unable to initialize MASShortcutManager. Check MASShortcut integration.")
        }

        _displayModeManager = StateObject(wrappedValue: displayManager)
        _shortcutManager = StateObject(wrappedValue: shortcutManager)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContent(displayModeManager: displayModeManager, shortcutManager: shortcutManager)
        } label: {
            Label(displayModeManager.menuTitle, systemImage: displayModeManager.menuSymbolName)
        }
        .menuBarExtraStyle(.window)
    }
}
