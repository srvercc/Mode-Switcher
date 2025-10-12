import AppKit
import SwiftUI

struct MenuContent: View {
    @ObservedObject var displayModeManager: DisplayModeManager
    @ObservedObject var shortcutManager: ShortcutManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(displayModeManager.fullStatusText)
                .font(.system(.body))
                .fixedSize(horizontal: false, vertical: true)

            if let errorMessage = displayModeManager.lastErrorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            Button(displayModeManager.toggleMenuTitle) {
                displayModeManager.toggleMode()
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!displayModeManager.isToggleActionEnabled)

            Button("Change Shortcut…") {
                ShortcutEditorWindowController.shared.show(shortcutManager: shortcutManager)
            }

            Button("Quit Mode Switcher") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: [.command])
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .frame(minWidth: 260)
    }
}
