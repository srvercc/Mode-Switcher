import SwiftUI
import AppKit
@preconcurrency import MASShortcut

struct SettingsView: View {
    @ObservedObject var displayModeManager: DisplayModeManager
    @ObservedObject var shortcutManager: ShortcutManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                shortcutSection
                statusSection
                tipsSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .frame(minWidth: 440, idealWidth: 460, minHeight: 320, idealHeight: 360, alignment: .topLeading)
    }

    private var shortcutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Keyboard Shortcut")
                .font(.headline)
            ShortcutRecorderView(shortcutManager: shortcutManager)
                .frame(height: 36)
            Text("Use this shortcut from anywhere while Mode Switcher is running to toggle mirrored and extended display layouts.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Status")
                .font(.headline)
            Text(displayModeManager.fullStatusText)
            if displayModeManager.externalDisplayCount == 0 {
                Text("Connect an external display to enable mode switching.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            if let lastErrorMessage = displayModeManager.lastErrorMessage {
                Text(lastErrorMessage)
                    .font(.caption)
                    .foregroundColor(.pink)
            }
        }
    }

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tips")
                .font(.headline)

            Text("Grant Mode Switcher accessibility access (System Settings → Privacy & Security → Accessibility) so the shortcut can be registered globally.")
                .font(.caption)
                .foregroundColor(.secondary)

            Button("Open Display Settings") {
                openDisplaySettings()
            }
            .buttonStyle(.link)
        }
    }
}

struct ShortcutRecorderView: NSViewRepresentable {
    @ObservedObject var shortcutManager: ShortcutManager

    func makeNSView(context: Context) -> MASShortcutView {
        let view = MASShortcutView()
        view.style = .rounded
        view.setAcceptsFirstResponder(true)
        view.shortcutValue = shortcutManager.currentShortcut
        view.shortcutValueChange = { sender in
            shortcutManager.updateShortcut(sender.shortcutValue)
        }

        return view
    }

    func updateNSView(_ nsView: MASShortcutView, context: Context) {
        if nsView.shortcutValue != shortcutManager.currentShortcut {
            nsView.shortcutValue = shortcutManager.currentShortcut
        }
    }
}

private func openDisplaySettings() {
    let workspace = NSWorkspace.shared
    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.displays"), workspace.open(url) {
        return
    }

    let prefPaneURL = URL(fileURLWithPath: "/System/Library/PreferencePanes/Displays.prefPane")
    workspace.open(prefPaneURL)
}
