import AppKit
import SwiftUI

/// Shows the Settings window for a menu-bar / accessory app.
///
/// Accessory apps (`NSApp.setActivationPolicy(.accessory)`) can't reliably bring
/// a regular NSWindow to the foreground because they lack an app menu and Dock
/// presence. The reliable pattern is:
///   1. Temporarily switch to `.regular` policy so the system gives us focus.
///   2. Activate the app and order the window front *regardless*.
///   3. When the window closes, switch back to `.accessory`.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {

    private var window: NSWindow?
    private let coordinator: PlayerCoordinator
    private let settings: AppSettings
    private(set) var isVisible: Bool = false

    init(coordinator: PlayerCoordinator, settings: AppSettings) {
        self.coordinator = coordinator
        self.settings = settings
        super.init()
    }

    func show() {
        if window == nil {
            window = createWindow()
        }
        guard let window else { return }

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        if !settings.showDockIcon {
            NSApp.setActivationPolicy(.accessory)
        }
        isVisible = true
    }

    func windowWillClose(_ notification: Notification) {
        isVisible = false
        NSApp.setActivationPolicy(settings.showDockIcon ? .regular : .accessory)
        // Drop the window so SwiftUI state, image previews, and hosting
        // controllers are released when Settings is closed. It rebuilds cheaply
        // on next open.
        window?.delegate = nil
        window = nil
    }

    private func createWindow() -> NSWindow {
        let root = SettingsView(settings: settings, coordinator: coordinator)
        let hosting = NSHostingController(rootView: root)
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 580),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        win.title = "Navic Settings"
        win.contentViewController = hosting
        win.minSize = NSSize(width: 760, height: 580)
        win.maxSize = NSSize(width: 900, height: 720)
        win.isReleasedWhenClosed = false
        win.collectionBehavior.remove(.fullScreenPrimary)
        win.standardWindowButton(.zoomButton)?.isEnabled = false
        win.delegate = self
        win.center()
        return win
    }
}
