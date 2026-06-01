import Foundation
import AppKit

@MainActor
final class AppEnvironment {

    static let shared = AppEnvironment()

    let settings: AppSettings
    let coordinator: PlayerCoordinator
    let miniPlayerController: MiniPlayerWindowController
    let settingsController: SettingsWindowController
    private(set) var menuBarController: MenuBarController?
    private var alwaysOnTopObserver: Task<Void, Never>?
    private var lastSettingsSnapshot: SettingsRuntimeSnapshot?
    private var resizeTask: Task<Void, Never>?

    init() {
        let settings = AppSettings.shared
        let coordinator = PlayerCoordinator(settings: settings)
        self.settings = settings
        self.coordinator = coordinator
        self.miniPlayerController = MiniPlayerWindowController(coordinator: coordinator, settings: settings)
        self.settingsController = SettingsWindowController(coordinator: coordinator, settings: settings)
    }

    func start() {
        AppIconManager.apply(settings.appIconVariant)
        applyDockIconVisibility()
        coordinator.widgetVisibilityDidChange = { [weak self] shouldShow in
            self?.miniPlayerController.setVisible(shouldShow)
        }
        coordinator.start()
        // The polling loop will publish the authoritative visibility as soon as
        // it has spoken to the server. Until then, hide the widget if we don't
        // even have credentials, so we don't flash an empty player.
        if settings.credentials == nil {
            miniPlayerController.setVisible(false)
        }
        menuBarController = MenuBarController(
            coordinator: coordinator,
            settings: settings,
            onShowSettings: { [weak self] in self?.settingsController.show() }
        )

        alwaysOnTopObserver = Task { [weak self] in
            guard let stream = self?.settings.changes() else { return }
            for await _ in stream {
                guard let self else { return }
                self.applyRuntimeSettings()
            }
        }
    }

    deinit {
        alwaysOnTopObserver?.cancel()
        resizeTask?.cancel()
    }

    private func applyDockIconVisibility() {
        NSApp.setActivationPolicy(settings.showDockIcon ? .regular : .accessory)
    }

    private func applyRuntimeSettings() {
        let snapshot = SettingsRuntimeSnapshot(settings: settings)
        guard snapshot != lastSettingsSnapshot else { return }

        if snapshot.alwaysOnTop != lastSettingsSnapshot?.alwaysOnTop {
            miniPlayerController.applyAlwaysOnTop(snapshot.alwaysOnTop)
        }

        if snapshot.widgetBackgroundStyle != lastSettingsSnapshot?.widgetBackgroundStyle {
            miniPlayerController.applyBackgroundStyle(snapshot.widgetBackgroundStyle)
        }

        if snapshot.showDockIcon != lastSettingsSnapshot?.showDockIcon {
            applyDockIconVisibility()
        }

        if snapshot.appIconVariant != lastSettingsSnapshot?.appIconVariant {
            AppIconManager.apply(snapshot.appIconVariant)
        }

        if snapshot.hideWidgetWhenIdle != lastSettingsSnapshot?.hideWidgetWhenIdle {
            miniPlayerController.setVisible(!snapshot.hideWidgetWhenIdle || coordinator.track != nil)
        }

        if lastSettingsSnapshot == nil || snapshot.layoutSizingKey != lastSettingsSnapshot?.layoutSizingKey {
            scheduleWidgetResize()
        }

        lastSettingsSnapshot = snapshot
    }

    private func scheduleWidgetResize() {
        resizeTask?.cancel()
        resizeTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 160_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.miniPlayerController.resizeToFitContent()
            }
        }
    }
}

private struct SettingsRuntimeSnapshot: Equatable {
    let alwaysOnTop: Bool
    let showDockIcon: Bool
    let hideWidgetWhenIdle: Bool
    let appIconVariant: AppIconVariant
    let widgetBackgroundStyle: WidgetBackgroundStyle
    let layoutSizingKey: String

    init(settings: AppSettings) {
        self.alwaysOnTop = settings.alwaysOnTop
        self.showDockIcon = settings.showDockIcon
        self.hideWidgetWhenIdle = settings.hideWidgetWhenIdle
        self.appIconVariant = settings.appIconVariant
        self.widgetBackgroundStyle = settings.widgetBackgroundStyle
        self.layoutSizingKey = [
            settings.widgetLayout.rawValue,
            settings.widgetWidthMode.rawValue,
            String(Int(settings.textAreaWidth)),
            String(Int(settings.artworkSize)),
            String(Int(settings.artworkTextSpacing)),
            settings.artworkPresentationEffect.rawValue,
            settings.textSize.rawValue,
            settings.trackInfoLayout.rawValue,
            settings.showArtwork ? "art" : "no-art",
            settings.showText ? "text" : "no-text"
        ].joined(separator: ":")
    }
}

enum AppIconManager {
    @MainActor
    static func apply(_ variant: AppIconVariant) {
        guard let image = paddedDockImage(for: variant) else { return }
        NSApp.applicationIconImage = image
        NSApp.dockTile.display()
        // Also push the icon onto the bundle file so it propagates beyond the
        // running process (Finder, Spotlight, Force Quit, Mission Control thumbnails).
        // `NSApp.applicationIconImage` only updates the Dock and Cmd+Tab.
        NSWorkspace.shared.setIcon(image, forFile: Bundle.main.bundlePath, options: [])
    }

    /// Returns the variant preview at its native size — used for in-app previews
    /// (icon picker, About). Don't use this for `NSApp.applicationIconImage`.
    @MainActor
    static func image(for variant: AppIconVariant) -> NSImage? {
        NSImage(named: NSImage.Name(variant.previewAssetName))
    }

    /// macOS expects an app icon to occupy roughly 80% of its canvas with a
    /// transparent margin around it. The preview PNGs fill their entire canvas,
    /// which makes the Dock render them larger than other system icons.
    /// This composes the variant onto a padded canvas so the Dock shows it at
    /// a size consistent with the rest of the system.
    @MainActor
    private static func paddedDockImage(for variant: AppIconVariant) -> NSImage? {
        guard let source = NSImage(named: NSImage.Name(variant.previewAssetName)) else {
            return NSApp.applicationIconImage
        }
        let canvasSide: CGFloat = 1024
        let contentSide: CGFloat = canvasSide * 0.80
        let inset = (canvasSide - contentSide) / 2
        let canvas = NSImage(size: NSSize(width: canvasSide, height: canvasSide))
        canvas.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        source.draw(
            in: NSRect(x: inset, y: inset, width: contentSide, height: contentSide),
            from: .zero,
            operation: .sourceOver,
            fraction: 1.0
        )
        canvas.unlockFocus()
        return canvas
    }
}
