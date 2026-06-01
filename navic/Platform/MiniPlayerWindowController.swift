import AppKit
import SwiftUI

@MainActor
final class MiniPlayerWindowController {

    private let panel: FloatingPanel
    private let settings: AppSettings
    private var frameObservation: NSObjectProtocol?
    private var isVisibleState: Bool = false

    init(coordinator: PlayerCoordinator, settings: AppSettings) {
        self.settings = settings

        let defaultFrame = NSRect(x: 200, y: 200, width: 360, height: 120)
        let storedFrame = settings.loadMiniPlayerFrame() ?? defaultFrame

        self.panel = FloatingPanel(contentRect: storedFrame)
        let root = MiniPlayerView(coordinator: coordinator)
            .environment(settings)
        panel.contentView = NSHostingView(rootView: root)
        panel.setFrame(storedFrame, display: false)
        panel.setAlwaysOnTop(settings.alwaysOnTop)
        panel.hasShadow = settings.widgetBackgroundStyle != .transparent

        frameObservation = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.settings.saveMiniPlayerFrame(self.panel.frame)
            }
        }
    }

    deinit {
        if let frameObservation {
            NotificationCenter.default.removeObserver(frameObservation)
        }
    }

    func show() {
        resizeToFitContent()
        if !panel.isVisible {
            panel.alphaValue = 0
            panel.orderFrontRegardless()
        }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.22
            ctx.allowsImplicitAnimation = true
            panel.animator().alphaValue = 1
        }
        isVisibleState = true
    }

    func hide() {
        guard panel.isVisible else {
            isVisibleState = false
            return
        }
        let panel = self.panel
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.22
            ctx.allowsImplicitAnimation = true
            panel.animator().alphaValue = 0
        }, completionHandler: {
            if panel.alphaValue <= 0.01 {
                panel.orderOut(nil)
                panel.alphaValue = 1
            }
        })
        isVisibleState = false
    }

    func setVisible(_ isVisible: Bool) {
        if isVisible {
            show()
        } else {
            hide()
        }
    }

    var isShowing: Bool { isVisibleState }

    func applyAlwaysOnTop(_ value: Bool) {
        panel.setAlwaysOnTop(value)
    }

    func applyBackgroundStyle(_ style: WidgetBackgroundStyle) {
        panel.hasShadow = style != .transparent
    }

    func resizeToFitContent() {
        let oldFrame = panel.frame
        let newSize = calculatedPanelSize()
        var frame = anchoredFrame(from: oldFrame, newSize: newSize)
        frame = clampedFrame(frame)
        panel.setFrame(frame, display: true, animate: true)
        settings.saveMiniPlayerFrame(panel.frame)
    }

    private func calculatedPanelSize() -> NSSize {
        let widgetPadding: CGFloat = 12
        let outerPadding: CGFloat = 8
        let artworkSize = CGFloat(settings.artworkSize)
        let artworkDisplayWidth = artworkSize * artworkEffectAspectRatio
        let showArtwork = settings.showArtwork || !settings.showText
        let showText = settings.showText || !settings.showArtwork
        let spacing = CGFloat(settings.artworkTextSpacing)
        let textWidth = calculatedTextWidth()
        let secondaryFontSize = calculatedSecondaryFontSize()
        let extraRows = CGFloat(max(0, textRowCount - 2))
        let textHeight = extraRows * (secondaryFontSize + 5)
        let contentSpacing = showArtwork && showText ? spacing : 0
        let textContentWidth = showText ? textWidth : 0
        let artworkContentWidth = showArtwork ? artworkDisplayWidth : 0
        let artworkContentHeight = showArtwork ? artworkSize : 0

        let contentSize: CGSize
        switch settings.widgetLayout {
        case .horizontal:
            contentSize = CGSize(
                width: max(120, artworkContentWidth + contentSpacing + textContentWidth + widgetPadding * 2),
                height: max(78, showArtwork ? artworkContentHeight + 24 : 78 + textHeight)
            )
        case .vertical:
            let verticalHeight = artworkContentHeight + contentSpacing + (showText ? 78 + textHeight : 0) + widgetPadding * 2
            contentSize = CGSize(
                width: max(120, max(artworkContentWidth, textContentWidth) + widgetPadding * 2),
                height: max(78, verticalHeight)
            )
        case .textOnly:
            if showText {
                contentSize = CGSize(width: max(120, textWidth + widgetPadding * 2), height: 78 + textHeight)
            } else {
                contentSize = CGSize(width: max(120, artworkSize + widgetPadding * 2), height: max(78, artworkSize + widgetPadding * 2))
            }
        }

        return NSSize(
            width: max(panel.minSize.width, contentSize.width + outerPadding),
            height: max(panel.minSize.height, contentSize.height + outerPadding)
        )
    }

    private func calculatedTextWidth() -> CGFloat {
        if settings.widgetWidthMode == .custom {
            return CGFloat(settings.textAreaWidth)
        }

        let artworkDisplayWidth = CGFloat(settings.artworkSize) * artworkEffectAspectRatio
        switch settings.widgetLayout {
        case .horizontal:
            return max(160, min(420, artworkDisplayWidth))
        case .vertical:
            return max(180, min(520, artworkDisplayWidth))
        case .textOnly:
            return max(220, min(520, CGFloat(settings.textAreaWidth)))
        }
    }

    private var artworkEffectAspectRatio: CGFloat {
        switch settings.artworkPresentationEffect {
        case .none:
            return 1
        case .cdCase:
            return 452.0 / 413.0
        case .vinylBox:
            return 722.0 / 615.0
        case .cassette:
            return 1421.0 / 898.0
        }
    }

    private func calculatedSecondaryFontSize() -> CGFloat {
        switch settings.textSize {
        case .small: return 10
        case .medium: return 11
        case .large: return 13
        case .extraLarge: return 15
        }
    }

    private var textRowCount: Int {
        switch settings.trackInfoLayout {
        case .twoLines: return 2
        case .threeLines: return 3
        case .fourLines: return 4
        }
    }

    private func anchoredFrame(from oldFrame: NSRect, newSize: NSSize) -> NSRect {
        let screenFrame = (panel.screen ?? NSScreen.main)?.visibleFrame
        let anchorRight: Bool
        let anchorTop: Bool

        if let screenFrame {
            anchorRight = abs(screenFrame.maxX - oldFrame.maxX) < abs(oldFrame.minX - screenFrame.minX)
            anchorTop = abs(screenFrame.maxY - oldFrame.maxY) < abs(oldFrame.minY - screenFrame.minY)
        } else {
            anchorRight = false
            anchorTop = true
        }

        let originX = anchorRight ? oldFrame.maxX - newSize.width : oldFrame.minX
        let originY = anchorTop ? oldFrame.maxY - newSize.height : oldFrame.minY
        return NSRect(origin: NSPoint(x: originX, y: originY), size: newSize)
    }

    private func clampedFrame(_ frame: NSRect) -> NSRect {
        guard let visibleFrame = (panel.screen ?? NSScreen.main)?.visibleFrame else { return frame }
        var clamped = frame

        if clamped.width <= visibleFrame.width {
            clamped.origin.x = min(max(clamped.minX, visibleFrame.minX), visibleFrame.maxX - clamped.width)
        } else {
            clamped.origin.x = visibleFrame.minX
        }

        if clamped.height <= visibleFrame.height {
            clamped.origin.y = min(max(clamped.minY, visibleFrame.minY), visibleFrame.maxY - clamped.height)
        } else {
            clamped.origin.y = visibleFrame.minY
        }

        return clamped
    }
}
