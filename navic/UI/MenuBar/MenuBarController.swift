import AppKit
import SwiftUI

@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {

    private let statusItem: NSStatusItem
    private let coordinator: PlayerCoordinator
    private let settings: AppSettings
    private let onShowSettings: () -> Void
    private let menu = NSMenu()

    init(
        coordinator: PlayerCoordinator,
        settings: AppSettings,
        onShowSettings: @escaping () -> Void
    ) {
        self.coordinator = coordinator
        self.settings = settings
        self.onShowSettings = onShowSettings

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        statusItem.button?.image = menuBarIcon()
        statusItem.button?.image?.isTemplate = true

        menu.delegate = self
        statusItem.menu = menu
        rebuild(menu)
    }

    /// AppKit calls this every time the user clicks the menu bar item, so we
    /// only do the (cheap) menu rebuild when it's actually about to be shown.
    /// No background timer, no work when the menu is closed.
    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuild(menu)
    }

    private func rebuild(_ menu: NSMenu) {
        menu.removeAllItems()
        populate(menu)
    }

    private func populate(_ menu: NSMenu) {
        if let track = coordinator.track {
            let title = NSMenuItem(title: "\(track.title) — \(track.artist)", action: nil, keyEquivalent: "")
            title.isEnabled = false
            menu.addItem(title)
        } else {
            let title = NSMenuItem(title: "Nothing playing", action: nil, keyEquivalent: "")
            title.isEnabled = false
            menu.addItem(title)
        }
        menu.addItem(.separator())

        menu.addItem(makeItem("Reload player", #selector(refresh), systemImage: "arrow.clockwise"))

        let dockItem = makeItem("Dock Icon", #selector(toggleDockIcon), systemImage: "dock.rectangle")
        dockItem.state = settings.showDockIcon ? .on : .off
        menu.addItem(dockItem)

        let topItem = makeItem("Always on Top", #selector(toggleAlwaysOnTop), systemImage: "pin")
        topItem.state = settings.alwaysOnTop ? .on : .off
        menu.addItem(topItem)

        if let url = navidromeWebURL {
            let item = makeItem("Open Navidrome", #selector(openNavidromeWeb), systemImage: "arrow.up.forward.square")
            item.representedObject = url
            menu.addItem(item)
        }
        menu.addItem(.separator())
        menu.addItem(makeItem("Settings...", #selector(showSettings), keyEquivalent: ",", systemImage: "gearshape"))
        menu.addItem(.separator())
        menu.addItem(makeItem("Quit", #selector(quit), keyEquivalent: "q"))

        for item in menu.items where item.action != nil { item.target = self }
    }

    private func makeItem(_ title: String, _ action: Selector, keyEquivalent: String = "", systemImage: String? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        if let systemImage {
            item.image = NSImage(systemSymbolName: systemImage, accessibilityDescription: title)
        }
        return item
    }

    private var navidromeWebURL: URL? {
        guard let url = URL(string: settings.serverURLString), url.scheme != nil else { return nil }
        return url
    }

    private func menuBarIcon() -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: 18, weight: .regular)
        return NSImage(systemSymbolName: "play.circle.fill", accessibilityDescription: "Navic")?
            .withSymbolConfiguration(configuration)
    }

    // MARK: - Selectors

    @objc private func showSettings() { onShowSettings() }
    @objc private func refresh() { coordinator.refreshNow() }
    @objc private func toggleDockIcon() {
        settings.showDockIcon.toggle()
    }
    @objc private func toggleAlwaysOnTop() {
        settings.alwaysOnTop.toggle()
    }
    @objc private func openNavidromeWeb(_ sender: NSMenuItem) {
        if let url = sender.representedObject as? URL {
            NSWorkspace.shared.open(url)
        }
    }
    @objc private func quit() { NSApp.terminate(nil) }
}
