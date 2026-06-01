import AppKit
import SwiftUI

/// Borderless, always-on-top panel that hosts the SwiftUI mini-player.
/// Persists its frame and restores it on launch. Click-and-drag from anywhere
/// in the panel moves the window.
final class FloatingPanel: NSPanel {

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView, .resizable],
            backing: .buffered,
            defer: false
        )
        isMovableByWindowBackground = true
        isMovable = true
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        backgroundColor = .clear
        hasShadow = true
        isOpaque = false
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        hidesOnDeactivate = false
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true
        minSize = NSSize(width: 280, height: 96)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }

    func setAlwaysOnTop(_ alwaysOnTop: Bool) {
        level = alwaysOnTop ? .floating : .normal
    }
}
