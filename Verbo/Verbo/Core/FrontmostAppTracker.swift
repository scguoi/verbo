import AppKit
import Foundation

/// Continuously tracks the frontmost non-Verbo application.
///
/// Problem: calling `NSWorkspace.shared.frontmostApplication` at recording time
/// is unreliable — momentary focus shifts (toast hover, system notifications,
/// SwiftUI text selection) can cause it to return the wrong app.
///
/// Solution: subscribe to `didActivateApplicationNotification` and always keep
/// the most recent non-self app as the target. This way, even if at recording
/// time the frontmost is briefly something else, we still have the correct target.
@MainActor
final class FrontmostAppTracker {
    private(set) var target: NSRunningApplication?
    private var observer: Any?

    init() {
        // Capture initial state
        if let current = NSWorkspace.shared.frontmostApplication,
           current.bundleIdentifier != Bundle.main.bundleIdentifier {
            target = current
        }

        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.bundleIdentifier != Bundle.main.bundleIdentifier else {
                return
            }
            Task { @MainActor in
                self?.target = app
                Log.ui.debug("FrontmostAppTracker updated: \(app.bundleIdentifier ?? "nil", privacy: .public)")
            }
        }
    }

    // Note: observer is cleaned up automatically when the process exits.
    // Not removing in deinit to avoid Swift 6 concurrency issues (NSWorkspace
    // notification observers aren't Sendable).
}
