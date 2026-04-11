import AppKit
import SwiftUI

// MARK: - SettingsWindow

@MainActor
final class SettingsWindow: NSObject, NSWindowDelegate {

    // MARK: - Properties

    private var window: NSWindow?

    // MARK: - Show

    func show(viewModel: SettingsViewModel) {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let contentView = SettingsView(viewModel: viewModel)
        let hosting = NSHostingView(rootView: contentView)

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 450),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        win.title = String(localized: "settings.title")
        win.contentView = hosting
        win.delegate = self
        win.isReleasedWhenClosed = false
        win.center()
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = win
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}
