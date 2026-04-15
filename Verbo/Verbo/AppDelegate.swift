import AppKit
import SwiftUI

// MARK: - AppDelegate

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Properties

    private var floatingPanel: FloatingPanel?
    private let settingsWindow = SettingsWindow()
    private let historyWindow = HistoryWindow()

    private let configManager = ConfigManager()
    private let historyManager = HistoryManager()
    private let hotkeyManager = HotkeyManager()

    private let floatingViewModel = FloatingViewModel()

    private var statusItem: NSStatusItem?

    /// IDs of scene hotkeys currently registered with `hotkeyManager`.
    /// Tracked so we can unregister them all before re-registering when the
    /// scene list / hotkey bindings change.
    private var registeredSceneHotkeyIds: Set<String> = []

    // MARK: - NSApplicationDelegate

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. Load config and history
        configManager.load()
        historyManager.load()

        // Debug: log loaded config
        let sttCfg = configManager.config.providers.stt["iflytek"]
        let configPath = configManager.configFileURL.path
        Log.config.info("Config loaded: appId=\(sttCfg?.appId ?? "nil", privacy: .public) path=\(configPath, privacy: .public)")

        // 1.5 Apply UI language override (before any UI is created)
        applyUILanguage(configManager.config.general.uiLanguage)

        // 2. Wire up floatingViewModel
        floatingViewModel.configManager = configManager
        floatingViewModel.historyManager = historyManager

        // 3. Setup floating panel
        setupFloatingPanel()

        // 4. Setup status item
        setupStatusItem()

        // 5. Request accessibility permission (needed for Fn key capture)
        requestAccessibilityIfNeeded()

        // 6. Register hotkeys + observe config changes so edits take effect live
        registerHotkeys()
        observeConfigChanges()
        observePipelineState()

        hotkeyManager.startListening()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager.stopListening()
    }

    // MARK: - Floating Panel Setup

    private func setupFloatingPanel() {
        let panelView = FloatingPanelView(viewModel: floatingViewModel)
        let hosting = NSHostingView(rootView: panelView)

        // Make hosting view fully transparent — only SwiftUI-drawn shapes are visible
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = .clear

        // Panel is created but NOT ordered front — it stays hidden until the
        // pipeline enters a non-idle state (see observePipelineState).
        let panel = FloatingPanel(contentView: hosting)
        self.floatingPanel = panel
    }

    // MARK: - Status Item Setup

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = item.button {
            button.image = NSImage(
                systemSymbolName: "waveform",
                accessibilityDescription: String(localized: "app.name")
            )
            button.image?.isTemplate = true
        }

        let menu = buildStatusMenu()
        menu.delegate = self
        item.menu = menu
        self.statusItem = item
    }

    private func buildStatusMenu() -> NSMenu {
        let menu = NSMenu()

        // Scene list
        for scene in configManager.config.scenes {
            let item = NSMenuItem(
                title: scene.name,
                action: #selector(switchScene(_:)),
                keyEquivalent: ""
            )
            item.representedObject = scene.id
            item.state = scene.id == configManager.config.defaultScene ? .on : .off
            menu.addItem(item)
        }

        menu.addItem(.separator())

        // Avg end-to-end latency (last 50 records with a measured value)
        let latencyItem = NSMenuItem(
            title: avgLatencyMenuTitle(),
            action: nil,
            keyEquivalent: ""
        )
        latencyItem.isEnabled = false
        menu.addItem(latencyItem)

        menu.addItem(.separator())

        // History
        let historyItem = NSMenuItem(
            title: String(localized: "menu.history"),
            action: #selector(showHistory),
            keyEquivalent: "h"
        )
        historyItem.keyEquivalentModifierMask = .command
        menu.addItem(historyItem)

        // Settings
        let settingsItem = NSMenuItem(
            title: String(localized: "menu.settings"),
            action: #selector(showSettings),
            keyEquivalent: ","
        )
        settingsItem.keyEquivalentModifierMask = .command
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        // Version — read from Info.plist so the menu stays in sync with builds.
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let versionItem = NSMenuItem(
            title: "Verbo v\(version)",
            action: nil,
            keyEquivalent: ""
        )
        versionItem.isEnabled = false
        menu.addItem(versionItem)

        // Quit — use our own selector so macOS doesn't auto-attach an
        // SF Symbol (it does so for system actions like terminate:).
        let quitItem = NSMenuItem(
            title: String(localized: "menu.quit"),
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        quitItem.keyEquivalentModifierMask = .command
        menu.addItem(quitItem)

        return menu
    }

    // MARK: - Hotkey Registration

    private func registerHotkeys() {
        // Drop any previously-registered scene hotkeys so renames / rebinds /
        // deletions don't leave stale entries behind.
        for id in registeredSceneHotkeyIds {
            hotkeyManager.unregister(id: id)
        }
        registeredSceneHotkeyIds.removeAll()

        let config = configManager.config

        // Per-scene hotkeys
        for scene in config.scenes {
            let sceneId = scene.id

            if let toggleHotkey = scene.hotkey.toggleRecord {
                let bindingId = "scene.\(sceneId).toggle"
                hotkeyManager.register(id: bindingId, shortcut: toggleHotkey) {
                    self.switchToScene(id: sceneId)
                    self.floatingViewModel.toggleRecording()
                }
                registeredSceneHotkeyIds.insert(bindingId)
            }
        }
    }

    /// Subscribe to `floatingViewModel.pipelineState` so the floating panel
    /// is only shown while the pipeline is active. `.idle` → hidden; anything
    /// else (recording / transcribing / processing / done / error) → visible
    /// and repositioned at the bottom-center of the current screen.
    /// `withObservationTracking` is one-shot — re-arm from the callback.
    private func observePipelineState() {
        withObservationTracking {
            _ = floatingViewModel.pipelineState
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.updateFloatingPanelVisibility()
                self.observePipelineState()  // re-arm
            }
        }
    }

    private func updateFloatingPanelVisibility() {
        if floatingViewModel.pipelineState.isIdle {
            floatingPanel?.hide()
        } else {
            floatingPanel?.show()
        }
    }

    /// Subscribe to `configManager.config` changes via `withObservationTracking`
    /// so any settings edit (hotkey rebind, scene add/delete, default change)
    /// re-registers hotkeys and rebuilds the status menu immediately.
    /// `withObservationTracking` is one-shot, so we re-arm it from the callback.
    private func observeConfigChanges() {
        withObservationTracking {
            _ = configManager.config
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.registerHotkeys()
                self.statusItem?.menu = self.buildStatusMenu()
                self.observeConfigChanges()  // re-arm
            }
        }
    }

    private func switchToScene(id: String) {
        // Fast path: scene is already default — skip the full config update
        // cycle (which would trigger observeConfigChanges → re-register all
        // hotkeys + rebuild status menu) and save ~tens of ms on the hot
        // "press hotkey to record" path.
        guard configManager.config.defaultScene != id else { return }

        let newConfig = AppConfig(
            version: configManager.config.version,
            defaultScene: id,
            scenes: configManager.config.scenes,
            providers: configManager.config.providers,
            general: configManager.config.general
        )
        configManager.update(newConfig)
        // No manual ViewModel/menu update needed — observeConfigChanges()
        // picks this up and re-renders the pill + rebuilds the menu.
    }

    // MARK: - Language

    private func applyUILanguage(_ language: UILanguage) {
        switch language {
        case .system:
            // Remove app-level override, follow system
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        case .zh:
            UserDefaults.standard.set(["zh-Hans"], forKey: "AppleLanguages")
        case .en:
            UserDefaults.standard.set(["en"], forKey: "AppleLanguages")
        }
    }

    // MARK: - Accessibility Permission

    private func requestAccessibilityIfNeeded() {
        let trusted = AXIsProcessTrusted()
        if !trusted {
            let key = "AXTrustedCheckOptionPrompt" as CFString
            let options = [key: true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
            Log.hotkey.info("Accessibility permission not granted — prompting user")
        } else {
            Log.hotkey.info("Accessibility permission granted")
        }
    }

    // MARK: - Actions

    @objc private func switchScene(_ sender: NSMenuItem) {
        guard let sceneId = sender.representedObject as? String else { return }
        switchToScene(id: sceneId)
    }

    @objc private func showHistory() {
        let vm = HistoryViewModel(historyManager: historyManager)
        historyWindow.show(viewModel: vm)
    }

    @objc private func showSettings() {
        let vm = SettingsViewModel(configManager: configManager)
        settingsWindow.show(viewModel: vm)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    // MARK: - Avg Latency

    /// Compute the menu title for the "avg end-to-end latency" item using
    /// the last 50 records that have a measured latency value.
    private func avgLatencyMenuTitle() -> String {
        let samples = historyManager.records
            .prefix(50)
            .compactMap { $0.endToEndLatencyMs }
        guard !samples.isEmpty else {
            return String(localized: "menu.avg_latency.empty")
        }
        let avg = samples.reduce(0, +) / samples.count
        let format = String(localized: "menu.avg_latency.format")
        return String.localizedStringWithFormat(format, avg, samples.count)
    }
}

// MARK: - NSMenuDelegate

extension AppDelegate: NSMenuDelegate {
    /// Rebuild the status-bar menu each time it opens so that dynamic items
    /// (avg latency, scene checkmarks) stay fresh.
    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu === statusItem?.menu else { return }
        menu.removeAllItems()
        let rebuilt = buildStatusMenu()
        for item in rebuilt.items {
            rebuilt.removeItem(item)
            menu.addItem(item)
        }
    }
}
