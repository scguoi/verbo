import AppKit
import SwiftUI

final class FloatingPanel: NSPanel {

    /// Panel dimensions. Panel is larger than the pill so the drop shadow
    /// has room to render beyond the pill's rounded rectangle.
    static let panelWidth: CGFloat = 320
    static let panelHeight: CGFloat = 96

    /// Vertical offset from the bottom of the visible screen area.
    /// Puts the pill comfortably above the dock without sitting on it.
    private static let bottomMargin: CGFloat = 96

    init(contentView: NSView) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: Self.panelWidth, height: Self.panelHeight),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered, defer: false
        )
        self.level = .floating
        // Panel auto-positions on show; disable drag to keep it anchored.
        self.isMovableByWindowBackground = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false  // Pill renders its own SwiftUI shadow
        self.contentView = contentView
        self.isReleasedWhenClosed = false
        self.acceptsMouseMovedEvents = true
        self.hidesOnDeactivate = false
    }

    // NEVER become key window — stealing focus breaks CGEvent keyboard input
    // into the user's focused app (text gets sent to Finder fallback instead).
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Show the panel centered horizontally near the bottom of the screen
    /// the user is currently looking at (by mouse location), falling back
    /// to the main screen. Call every time we show so the pill follows the
    /// user across displays.
    func show() {
        positionAtBottomCenter()
        orderFrontRegardless()
    }

    func hide() {
        orderOut(nil)
    }

    private func positionAtBottomCenter() {
        let mouseScreen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) }
        guard let screen = mouseScreen ?? NSScreen.main ?? NSScreen.screens.first else { return }
        let visible = screen.visibleFrame
        let x = visible.midX - Self.panelWidth / 2
        let y = visible.minY + Self.bottomMargin
        setFrameOrigin(NSPoint(x: x, y: y))
    }
}
