import AppKit
import SwiftUI

final class FloatingPanel: NSPanel {

    /// Fixed width: toast(260) + spacing(8) + pill(166) + padding(16) = 450
    static let panelWidth: CGFloat = 450
    static let panelHeight: CGFloat = 200

    init(contentView: NSView) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: Self.panelWidth, height: Self.panelHeight),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered, defer: false
        )
        self.level = .floating
        self.isMovableByWindowBackground = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        self.contentView = contentView
        self.isReleasedWhenClosed = false
        self.acceptsMouseMovedEvents = true
        self.hidesOnDeactivate = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    func positionNearBottomRight() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let padding: CGFloat = 20
        let x = screenFrame.maxX - Self.panelWidth - padding
        let y = screenFrame.minY + padding
        setFrameOrigin(NSPoint(x: x, y: y))
    }
}
