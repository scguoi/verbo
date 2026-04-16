import AppKit
import SwiftUI

final class FloatingPanel: NSPanel {

    static let panelWidth: CGFloat = 320
    static let panelHeight: CGFloat = 320

    private static let bottomMargin: CGFloat = 96
    private static let dragThreshold: CGFloat = 3

    // Drag tracking
    private var dragStartScreenLocation: NSPoint = .zero
    private var dragStartFrameOrigin: NSPoint = .zero
    private var wasDragged = false

    /// After a drag, stores the pill's position as a RELATIVE offset
    /// from the screen's bottom-center default. On subsequent `show()`
    /// calls, this offset is applied to whichever screen the mouse is
    /// on — so the pill follows screens but remembers user adjustment.
    private var dragOffsetFromDefault: NSPoint?

    init(contentView: NSView) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: Self.panelWidth, height: Self.panelHeight),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered, defer: false
        )
        self.level = .floating
        self.isMovable = false
        self.isMovableByWindowBackground = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        self.contentView = contentView
        self.isReleasedWhenClosed = false
        self.acceptsMouseMovedEvents = true
        self.hidesOnDeactivate = false
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    // MARK: - Drag vs Tap

    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown:
            dragStartScreenLocation = NSEvent.mouseLocation
            dragStartFrameOrigin = frame.origin
            wasDragged = false
            super.sendEvent(event)

        case .leftMouseDragged:
            let current = NSEvent.mouseLocation
            let dx = current.x - dragStartScreenLocation.x
            let dy = current.y - dragStartScreenLocation.y
            if !wasDragged && (abs(dx) > Self.dragThreshold || abs(dy) > Self.dragThreshold) {
                wasDragged = true
            }
            if wasDragged {
                setFrameOrigin(NSPoint(
                    x: dragStartFrameOrigin.x + dx,
                    y: dragStartFrameOrigin.y + dy
                ))
            }

        case .leftMouseUp:
            if wasDragged {
                // Compute offset from where default position WOULD be
                // on the current screen, so we can replay it on any screen.
                let defaultOrigin = Self.defaultOrigin(for: NSEvent.mouseLocation)
                dragOffsetFromDefault = NSPoint(
                    x: frame.origin.x - defaultOrigin.x,
                    y: frame.origin.y - defaultOrigin.y
                )
                wasDragged = false
            } else {
                super.sendEvent(event)
            }

        default:
            super.sendEvent(event)
        }
    }

    // MARK: - Show / Hide

    /// Show the panel on the mouse's current screen, applying any
    /// user drag offset. Always follows the active screen.
    func show() {
        let origin = Self.defaultOrigin(for: NSEvent.mouseLocation)
        if let offset = dragOffsetFromDefault {
            setFrameOrigin(NSPoint(x: origin.x + offset.x, y: origin.y + offset.y))
        } else {
            setFrameOrigin(origin)
        }
        orderFrontRegardless()
    }

    func hide() {
        orderOut(nil)
    }

    func positionNearBottomRight() {
        dragOffsetFromDefault = nil
        show()
    }

    /// Compute the default bottom-center origin for the screen
    /// containing the given point.
    private static func defaultOrigin(for point: NSPoint) -> NSPoint {
        let mouseScreen = NSScreen.screens.first { $0.frame.contains(point) }
        let screen = mouseScreen ?? NSScreen.main ?? NSScreen.screens.first!
        let visible = screen.visibleFrame
        return NSPoint(
            x: visible.midX - panelWidth / 2,
            y: visible.minY + bottomMargin
        )
    }
}
