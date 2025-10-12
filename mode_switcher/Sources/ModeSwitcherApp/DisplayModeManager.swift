import AppKit
import CoreGraphics

@MainActor
final class DisplayModeManager: ObservableObject {
    enum LayoutState: Equatable {
        case builtInOnly
        case mirrored
        case extended
        case unknown
    }

    enum DisplayLayoutMode {
        case mirrorIntegrated
        case extend
    }

    enum ModeError: LocalizedError {
        case noBuiltInDisplay
        case noExternalDisplay
        case configuration(CGError)
        case displayQuery(CGError)

        var errorDescription: String? {
            switch self {
            case .noBuiltInDisplay:
                return "Unable to locate the integrated display."
            case .noExternalDisplay:
                return "No external displays are connected."
            case .configuration(let code):
                return "macOS rejected the display configuration change (error \(code.rawValue))."
            case .displayQuery(let code):
                return "Failed to query connected displays (error \(code.rawValue))."
            }
        }
    }

    @Published private(set) var state: LayoutState = .unknown
    @Published private(set) var externalDisplayCount: Int = 0
    @Published var lastErrorMessage: String?

    private var didRegisterCallback = false
    private var extendedLayoutCache: [CGDirectDisplayID: CGPoint] = [:]

    init() {
        refreshState()
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        CGDisplayRegisterReconfigurationCallback(displayReconfigurationCallback, context)
        didRegisterCallback = true
    }

    deinit {
        if didRegisterCallback {
            let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
            CGDisplayRemoveReconfigurationCallback(displayReconfigurationCallback, context)
        }
    }

    var menuTitle: String {
        switch state {
        case .mirrored:
            return "Mirrored"
        case .extended:
            return "Extended"
        case .builtInOnly:
            return "Integrated Only"
        case .unknown:
            return "Status Unknown"
        }
    }

    var menuSymbolName: String {
        switch state {
        case .mirrored:
            return "rectangle.on.rectangle"
        case .extended:
            return "rectangle.2.swap"
        case .builtInOnly:
            return "display"
        case .unknown:
            return "display.trianglebadge.exclamationmark"
        }
    }

    var toggleMenuTitle: String {
        switch state {
        case .mirrored:
            return "Switch to Extended"
        case .extended:
            return "Switch to Mirrored"
        case .builtInOnly:
            return externalDisplayCount > 0 ? "Switch Display Mode" : "Refresh Display State"
        case .unknown:
            return "Refresh Display State"
        }
    }

    var fullStatusText: String {
        switch state {
        case .mirrored:
            return "Desktop is mirrored to the integrated display."
        case .extended:
            return "Desktop is extended across \(externalDisplayCount) external display\(externalDisplayCount == 1 ? "" : "s")."
        case .builtInOnly:
            return "Only the integrated display is active."
        case .unknown:
            return "The current layout could not be determined."
        }
    }

    var isToggleActionEnabled: Bool {
        switch state {
        case .unknown:
            return true
        case .builtInOnly:
            return externalDisplayCount > 0
        case .mirrored, .extended:
            return true
        }
    }

    func toggleMode() {
        switch state {
        case .mirrored:
            setMode(.extend)
        case .extended:
            setMode(.mirrorIntegrated)
        case .builtInOnly:
            refreshState()
            if externalDisplayCount > 0 {
                setMode(.extend)
            } else {
                presentUserFacingError(ModeError.noExternalDisplay)
            }
        case .unknown:
            refreshState()
        }
    }

    func setMode(_ mode: DisplayLayoutMode) {
        do {
            try apply(mode: mode)
            lastErrorMessage = nil
            refreshState()
        } catch {
            lastErrorMessage = error.localizedDescription
            presentUserFacingError(error)
            refreshState()
        }
    }

    func refreshState() {
        do {
            let displays = try onlineDisplayIDs()
            let builtIn = displays.first(where: { CGDisplayIsBuiltin($0) != 0 })
            let externals = displays.filter { display in
                if let builtIn, display == builtIn {
                    return false
                }
                return CGDisplayIsBuiltin(display) == 0
            }
            externalDisplayCount = externals.count

            guard let builtIn else {
                state = .unknown
                externalDisplayCount = 0
                return
            }

            guard !externals.isEmpty else {
                state = .builtInOnly
                return
            }

            let mirrored = externals.allSatisfy { external in
                CGDisplayMirrorsDisplay(external) == builtIn
            }

            state = mirrored ? .mirrored : .extended

            if state == .extended {
                extendedLayoutCache = captureDisplayLayout(for: [builtIn] + externals)
            }
        } catch {
            state = .unknown
            lastErrorMessage = error.localizedDescription
        }
    }
}

private let displayReconfigurationCallback: CGDisplayReconfigurationCallBack = { _, _, userInfo in
    guard let userInfo else { return }
    let manager = Unmanaged<DisplayModeManager>.fromOpaque(userInfo).takeUnretainedValue()
    Task { @MainActor in
        manager.refreshState()
    }
}

@MainActor
private extension DisplayModeManager {
    func onlineDisplayIDs() throws -> [CGDirectDisplayID] {
        let maxDisplays: UInt32 = 16
        var onlineDisplays = [CGDirectDisplayID](repeating: 0, count: Int(maxDisplays))
        var displayCount: UInt32 = 0
        let error = CGGetOnlineDisplayList(maxDisplays, &onlineDisplays, &displayCount)
        guard error == .success else {
            throw ModeError.displayQuery(error)
        }

        return Array(onlineDisplays.prefix(Int(displayCount)))
    }

    func apply(mode: DisplayLayoutMode) throws {
        let displays = try onlineDisplayIDs()
        guard let builtIn = displays.first(where: { CGDisplayIsBuiltin($0) != 0 }) else {
            throw ModeError.noBuiltInDisplay
        }

        let externals = displays.filter { display in
            display != builtIn && CGDisplayIsBuiltin(display) == 0
        }

        guard !externals.isEmpty else {
            throw ModeError.noExternalDisplay
        }

        var configRef: CGDisplayConfigRef?
        let beginError = CGBeginDisplayConfiguration(&configRef)

        guard beginError == .success, let configRef else {
            throw ModeError.configuration(beginError)
        }

        var didCompleteConfiguration = false
        defer {
            if !didCompleteConfiguration {
                CGCancelDisplayConfiguration(configRef)
            }
        }

        let allDisplays = [builtIn] + externals

        // Always start by removing the built-in display from any mirror group.
        try configureMirror(display: builtIn, target: kCGNullDirectDisplay, in: configRef)

        switch mode {
        case .mirrorIntegrated:
            // Preserve the current extended layout so we can restore it when un-mirroring.
            extendedLayoutCache = captureDisplayLayout(for: allDisplays)

            for external in externals {
                try configureMirror(display: external, target: builtIn, in: configRef)
            }
            // Ensure the integrated display remains the primary origin.
            let origin = extendedLayoutCache[builtIn] ?? .zero
            try configureOrigin(display: builtIn, x: Int(origin.x), y: Int(origin.y), in: configRef)
        case .extend:
            // Break mirroring for every external display, then restore any cached layout.
            for external in externals {
                try configureMirror(display: external, target: kCGNullDirectDisplay, in: configRef)
            }

            let layout = extendedLayoutCache
            let builtInOrigin = layout[builtIn] ?? .zero
            try configureOrigin(display: builtIn, x: Int(builtInOrigin.x), y: Int(builtInOrigin.y), in: configRef)

            var fallbackX = Int(CGDisplayBounds(builtIn).width)
            for external in externals {
                if let origin = layout[external] {
                    try configureOrigin(display: external, x: Int(origin.x), y: Int(origin.y), in: configRef)
                } else {
                    try configureOrigin(display: external, x: fallbackX, y: 0, in: configRef)
                    fallbackX += Int(CGDisplayBounds(external).width)
                }
            }
        }

        let completeError = CGCompleteDisplayConfiguration(configRef, .permanently)
        guard completeError == .success else {
            throw ModeError.configuration(completeError)
        }
        didCompleteConfiguration = true
    }

    func presentUserFacingError(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Display Mode Update Failed"
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: "OK")

        if !NSApp.isActive {
            NSApp.activate(ignoringOtherApps: true)
        }

        let alertWindow = alert.window
        alertWindow.level = .floating
        alertWindow.collectionBehavior.insert([.canJoinAllSpaces, .fullScreenAuxiliary])
        alertWindow.orderFrontRegardless()

        alert.runModal()
    }

    func configureMirror(display: CGDirectDisplayID, target: CGDirectDisplayID, in config: CGDisplayConfigRef) throws {
        let error = CGConfigureDisplayMirrorOfDisplay(config, display, target)
        guard error == .success else {
            throw ModeError.configuration(error)
        }
    }

    func configureOrigin(display: CGDirectDisplayID, x: Int, y: Int, in config: CGDisplayConfigRef) throws {
        let error = CGConfigureDisplayOrigin(config, display, Int32(x), Int32(y))
        guard error == .success else {
            throw ModeError.configuration(error)
        }
    }

    func captureDisplayLayout(for displays: [CGDirectDisplayID]) -> [CGDirectDisplayID: CGPoint] {
        var layout: [CGDirectDisplayID: CGPoint] = [:]
        for display in displays {
            let bounds = CGDisplayBounds(display)
            layout[display] = bounds.origin
        }
        return layout
    }
}
