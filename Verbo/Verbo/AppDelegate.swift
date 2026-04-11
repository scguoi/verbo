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

        if let defaultScene = configManager.defaultScene() {
            floatingViewModel.currentSceneName = defaultScene.name
            floatingViewModel.currentHotkeyHint = HotkeyManager.displayString(for: defaultScene.hotkey.toggleRecord ?? "")
        }

        // 3. Setup floating panel
        setupFloatingPanel()

        // 4. Setup status item
        setupStatusItem()

        // 5. Register hotkeys
        registerHotkeys()

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

        let panel = FloatingPanel(contentView: hosting)
        panel.positionNearBottomRight()
        panel.makeKeyAndOrderFront(nil)
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

        item.menu = buildStatusMenu()
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

        // Version
        let versionItem = NSMenuItem(
            title: "Verbo v0.1.0",
            action: nil,
            keyEquivalent: ""
        )
        versionItem.isEnabled = false
        menu.addItem(versionItem)

        // Quit
        let quitItem = NSMenuItem(
            title: String(localized: "menu.quit"),
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quitItem.keyEquivalentModifierMask = .command
        menu.addItem(quitItem)

        return menu
    }

    // MARK: - Hotkey Registration

    private func registerHotkeys() {
        let config = configManager.config

        // Global toggle hotkey
        hotkeyManager.register(id: "global.toggle", shortcut: config.globalHotkey.toggleRecord) {
            self.floatingViewModel.toggleRecording()
        }

        // Global PTT hotkey
        if let ptt = config.globalHotkey.pushToTalk {
            hotkeyManager.register(
                id: "global.ptt",
                shortcut: ptt,
                onPress: { self.floatingViewModel.startRecording() },
                onRelease: { self.floatingViewModel.stopRecording() }
            )
        }

        // Per-scene hotkeys
        for scene in config.scenes {
            let sceneId = scene.id
            let sceneName = scene.name
            let sceneHotkeyHint = scene.hotkey.toggleRecord ?? ""

            if let toggleHotkey = scene.hotkey.toggleRecord {
                hotkeyManager.register(id: "scene.\(sceneId).toggle", shortcut: toggleHotkey) {
                    self.switchToScene(id: sceneId, name: sceneName, hotkeyHint: sceneHotkeyHint)
                    self.floatingViewModel.toggleRecording()
                }
            }

            if let pttHotkey = scene.hotkey.pushToTalk {
                hotkeyManager.register(
                    id: "scene.\(sceneId).ptt",
                    shortcut: pttHotkey,
                    onPress: {
                        self.switchToScene(id: sceneId, name: sceneName, hotkeyHint: sceneHotkeyHint)
                        self.floatingViewModel.startRecording()
                    },
                    onRelease: { self.floatingViewModel.stopRecording() }
                )
            }
        }
    }

    private func switchToScene(id: String, name: String, hotkeyHint: String) {
        let newConfig = AppConfig(
            version: configManager.config.version,
            defaultScene: id,
            globalHotkey: configManager.config.globalHotkey,
            scenes: configManager.config.scenes,
            providers: configManager.config.providers,
            general: configManager.config.general
        )
        configManager.update(newConfig)
        floatingViewModel.currentSceneName = name
        floatingViewModel.currentHotkeyHint = HotkeyManager.displayString(for: hotkeyHint)
        statusItem?.menu = buildStatusMenu()
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

    // MARK: - Actions

    @objc private func switchScene(_ sender: NSMenuItem) {
        guard let sceneId = sender.representedObject as? String,
              let scene = configManager.getScene(sceneId) else { return }
        switchToScene(
            id: sceneId,
            name: scene.name,
            hotkeyHint: scene.hotkey.toggleRecord ?? ""
        )
    }

    @objc private func showHistory() {
        let vm = HistoryViewModel(historyManager: historyManager)
        historyWindow.show(viewModel: vm)
    }

    @objc private func showSettings() {
        let vm = SettingsViewModel(configManager: configManager)
        settingsWindow.show(viewModel: vm)
    }
}
