import AppKit
import SwiftUI

final class FloatingPanel: NSPanel {
    init(contentView: NSView) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 40),
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

    func updateSize(to size: CGSize) {
        let currentFrame = frame
        let newOrigin = NSPoint(
            x: currentFrame.origin.x,
            y: currentFrame.origin.y + currentFrame.height - size.height
        )
        setFrame(NSRect(origin: newOrigin, size: size), display: true, animate: false)
    }

    func positionNearBottomRight() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let padding: CGFloat = 20
        let x = screenFrame.maxX - frame.width - padding
        let y = screenFrame.minY + padding
        setFrameOrigin(NSPoint(x: x, y: y))
    }
}
