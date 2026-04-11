# Verbo macOS Native Swift Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS voice input tool using Swift/SwiftUI that floats above all windows, records audio, transcribes via iFlytek STT, optionally processes through LLM, and outputs text to the focused application.

**Architecture:** SwiftUI + AppKit hybrid. NSPanel (nonactivating) for the floating window, AVAudioEngine for audio capture, CGEvent for keyboard simulation. Pipeline engine as a Swift actor orchestrates sequential steps (STT → optional LLM → output). JSON config drives scenes and provider credentials.

**Tech Stack:** Swift 6, SwiftUI, AppKit (NSPanel, NSStatusItem), AVFoundation (AVAudioEngine), CryptoKit (HMAC-SHA256), URLSession (WebSocket + SSE), CGEvent, XcodeGen

---

## File Structure

```
Verbo/
├── project.yml                            — XcodeGen project spec
├── Verbo/
│   ├── VerboApp.swift                     — @main SwiftUI entry point
│   ├── AppDelegate.swift                  — NSPanel + NSStatusItem lifecycle
│   ├── Info.plist                         — LSUIElement, usage descriptions
│   ├── Verbo.entitlements                 — Audio input entitlement
│   │
│   ├── Models/
│   │   ├── AppConfig.swift                — Root config (Codable)
│   │   ├── Scene.swift                    — Scene + PipelineStep
│   │   ├── PipelineState.swift            — Pipeline state machine enum
│   │   └── HistoryRecord.swift            — History entry
│   │
│   ├── Core/
│   │   ├── ConfigManager.swift            — JSON config read/write (@Observable)
│   │   ├── AudioRecorder.swift            — AVAudioEngine wrapper
│   │   ├── TextOutputService.swift        — CGEvent simulate + clipboard fallback
│   │   ├── HotkeyManager.swift            — Global key event monitoring
│   │   └── HistoryManager.swift           — History persistence
│   │
│   ├── Adapters/
│   │   ├── STTAdapter.swift               — Protocol
│   │   ├── IFlytekSTTAdapter.swift        — WebSocket streaming
│   │   ├── LLMAdapter.swift               — Protocol
│   │   └── OpenAILLMAdapter.swift         — HTTP SSE streaming
│   │
│   ├── Views/
│   │   ├── Floating/
│   │   │   ├── FloatingPanel.swift        — NSPanel subclass
│   │   │   ├── FloatingPanelView.swift    — Root SwiftUI view
│   │   │   ├── PillView.swift             — Compact pill widget
│   │   │   ├── BubbleView.swift           — Expanded text bubble
│   │   │   └── WaveformView.swift         — Audio waveform bars
│   │   ├── Settings/
│   │   │   ├── SettingsWindow.swift        — NSWindow wrapper
│   │   │   ├── SettingsView.swift          — Root settings with tab nav
│   │   │   ├── ScenesSettingsView.swift    — Scene list + editor
│   │   │   ├── ProvidersSettingsView.swift — STT/LLM credentials
│   │   │   ├── GeneralSettingsView.swift   — Behavior, language, data
│   │   │   └── AboutView.swift             — Version, links
│   │   └── History/
│   │       ├── HistoryWindow.swift         — NSWindow wrapper
│   │       └── HistoryView.swift           — Search, filter, list
│   │
│   ├── ViewModels/
│   │   ├── FloatingViewModel.swift        — Pipeline state + UI state (@Observable)
│   │   ├── SettingsViewModel.swift        — Config editing (@Observable)
│   │   └── HistoryViewModel.swift         — Search/filter state (@Observable)
│   │
│   ├── Resources/
│   │   ├── Assets.xcassets/               — App icon, colors
│   │   └── Localizable.xcstrings          — i18n strings (zh-Hans, en)
│   │
│   └── Utilities/
│       ├── DesignTokens.swift             — Colors, fonts, spacing constants
│       └── Localization.swift             — L10n helper
│
└── VerboTests/
    ├── Models/
    │   ├── AppConfigTests.swift
    │   ├── SceneTests.swift
    │   ├── PipelineStateTests.swift
    │   └── HistoryRecordTests.swift
    ├── Core/
    │   ├── ConfigManagerTests.swift
    │   ├── AudioRecorderTests.swift
    │   ├── TextOutputServiceTests.swift
    │   └── HistoryManagerTests.swift
    ├── Adapters/
    │   ├── IFlytekSTTAdapterTests.swift
    │   └── OpenAILLMAdapterTests.swift
    └── PipelineEngineTests.swift
```

---

## Task 1: Xcode Project Setup with XcodeGen

**Files:**
- Create: `Verbo/project.yml`
- Create: `Verbo/Verbo/Info.plist`
- Create: `Verbo/Verbo/Verbo.entitlements`
- Create: `Verbo/Verbo/VerboApp.swift` (minimal placeholder)
- Create: `Verbo/Verbo/Resources/Assets.xcassets/Contents.json`
- Create: `Verbo/Verbo/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`

- [ ] **Step 1: Install XcodeGen if needed**

Run: `which xcodegen || brew install xcodegen`

- [ ] **Step 2: Create project.yml**

```yaml
# Verbo/project.yml
name: Verbo
options:
  bundleIdPrefix: com.verbo
  deploymentTarget:
    macOS: "14.0"
  xcodeVersion: "16.0"
  minimumXcodeGenVersion: "2.40.0"

settings:
  base:
    SWIFT_VERSION: "6.0"
    MACOSX_DEPLOYMENT_TARGET: "14.0"
    SWIFT_STRICT_CONCURRENCY: complete

targets:
  Verbo:
    type: application
    platform: macOS
    sources:
      - path: Verbo
    settings:
      base:
        INFOPLIST_FILE: Verbo/Info.plist
        CODE_SIGN_ENTITLEMENTS: Verbo/Verbo.entitlements
        PRODUCT_BUNDLE_IDENTIFIER: com.verbo.app
        PRODUCT_NAME: Verbo
        GENERATE_INFOPLIST_FILE: false
    entitlements:
      path: Verbo/Verbo.entitlements
      properties:
        com.apple.security.device.audio-input: true

  VerboTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - path: VerboTests
    dependencies:
      - target: Verbo
    settings:
      base:
        GENERATE_INFOPLIST_FILE: true
        TEST_HOST: "$(BUILT_PRODUCTS_DIR)/Verbo.app/Contents/MacOS/Verbo"
        BUNDLE_LOADER: "$(TEST_HOST)"
```

- [ ] **Step 3: Create Info.plist**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>Verbo</string>
    <key>CFBundleDisplayName</key>
    <string>Verbo</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>LSMinimumSystemVersion</key>
    <string>$(MACOSX_DEPLOYMENT_TARGET)</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>Verbo needs microphone access to record your voice for speech-to-text.</string>
    <key>NSMainStoryboardFile</key>
    <string></string>
</dict>
</plist>
```

- [ ] **Step 4: Create entitlements file**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.device.audio-input</key>
    <true/>
</dict>
</plist>
```

- [ ] **Step 5: Create minimal VerboApp.swift**

```swift
import SwiftUI

@main
struct VerboApp: App {
    var body: some Scene {
        Settings {
            Text("Verbo v0.1.0")
        }
    }
}
```

- [ ] **Step 6: Create Assets.xcassets structure**

`Verbo/Verbo/Resources/Assets.xcassets/Contents.json`:
```json
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

`Verbo/Verbo/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`:
```json
{
  "images" : [
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "16x16"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "16x16"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "32x32"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "32x32"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "128x128"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "128x128"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "256x256"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "256x256"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "512x512"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "512x512"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

- [ ] **Step 7: Generate Xcode project and verify build**

```bash
cd Verbo && xcodegen generate
xcodebuild -project Verbo.xcodeproj -scheme Verbo -configuration Debug build
```

Expected: BUILD SUCCEEDED

- [ ] **Step 8: Commit**

```bash
git add Verbo/project.yml Verbo/Verbo/Info.plist Verbo/Verbo/Verbo.entitlements \
       Verbo/Verbo/VerboApp.swift Verbo/Verbo/Resources/
git commit -m "feat: scaffold Xcode project with XcodeGen"
```

---

## Task 2: Data Models

**Files:**
- Create: `Verbo/Verbo/Models/AppConfig.swift`
- Create: `Verbo/Verbo/Models/Scene.swift`
- Create: `Verbo/Verbo/Models/PipelineState.swift`
- Create: `Verbo/Verbo/Models/HistoryRecord.swift`
- Create: `Verbo/VerboTests/Models/AppConfigTests.swift`
- Create: `Verbo/VerboTests/Models/SceneTests.swift`
- Create: `Verbo/VerboTests/Models/PipelineStateTests.swift`
- Create: `Verbo/VerboTests/Models/HistoryRecordTests.swift`

- [ ] **Step 1: Write failing tests for AppConfig**

```swift
// VerboTests/Models/AppConfigTests.swift
import Testing
import Foundation
@testable import Verbo

@Suite("AppConfig")
struct AppConfigTests {
    @Test("Default config has expected values")
    func defaultConfig() {
        let config = AppConfig.default
        #expect(config.version == 1)
        #expect(config.defaultScene == "dictate")
        #expect(config.scenes.count == 3)
        #expect(config.globalHotkey.toggleRecord == "CommandOrControl+Shift+H")
    }

    @Test("Round-trip JSON encoding/decoding")
    func jsonRoundTrip() throws {
        let config = AppConfig.default
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(AppConfig.self, from: data)
        #expect(decoded.version == config.version)
        #expect(decoded.defaultScene == config.defaultScene)
        #expect(decoded.scenes.count == config.scenes.count)
    }

    @Test("Decoding from minimal JSON fills defaults")
    func minimalJson() throws {
        let json = """
        {"version":1,"defaultScene":"dictate","globalHotkey":{"toggleRecord":"Cmd+H"},"scenes":[],"providers":{"stt":{},"llm":{}}}
        """
        let config = try JSONDecoder().decode(AppConfig.self, from: Data(json.utf8))
        #expect(config.version == 1)
        #expect(config.scenes.isEmpty)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd Verbo && xcodegen generate && xcodebuild test -project Verbo.xcodeproj -scheme VerboTests -configuration Debug 2>&1 | tail -20
```

Expected: FAIL — `AppConfig` not defined

- [ ] **Step 3: Implement AppConfig model**

```swift
// Verbo/Models/AppConfig.swift
import Foundation

struct GlobalHotkey: Codable, Equatable, Sendable {
    var toggleRecord: String
    var pushToTalk: String?
}

struct ProvidersConfig: Codable, Equatable, Sendable {
    var stt: [String: STTProviderConfig]
    var llm: [String: LLMProviderConfig]
}

struct STTProviderConfig: Codable, Equatable, Sendable {
    var appId: String
    var apiKey: String
    var apiSecret: String
    var enabledLangs: [String]

    init(appId: String = "", apiKey: String = "", apiSecret: String = "", enabledLangs: [String] = ["zh", "en"]) {
        self.appId = appId
        self.apiKey = apiKey
        self.apiSecret = apiSecret
        self.enabledLangs = enabledLangs
    }
}

struct LLMProviderConfig: Codable, Equatable, Sendable {
    var apiKey: String
    var model: String
    var baseUrl: String

    init(apiKey: String = "", model: String = "gpt-4o-mini", baseUrl: String = "https://api.openai.com/v1") {
        self.apiKey = apiKey
        self.model = model
        self.baseUrl = baseUrl
    }
}

struct GeneralConfig: Codable, Equatable, Sendable {
    var outputMode: OutputMode
    var autoCollapseDelay: Double
    var launchAtStartup: Bool
    var uiLanguage: UILanguage
    var historyRetentionDays: Int?

    init(
        outputMode: OutputMode = .simulate,
        autoCollapseDelay: Double = 1.5,
        launchAtStartup: Bool = false,
        uiLanguage: UILanguage = .system,
        historyRetentionDays: Int? = 90
    ) {
        self.outputMode = outputMode
        self.autoCollapseDelay = autoCollapseDelay
        self.launchAtStartup = launchAtStartup
        self.uiLanguage = uiLanguage
        self.historyRetentionDays = historyRetentionDays
    }
}

enum OutputMode: String, Codable, Sendable {
    case simulate
    case clipboard
}

enum UILanguage: String, Codable, Sendable {
    case system
    case zh
    case en
}

struct AppConfig: Codable, Equatable, Sendable {
    var version: Int
    var defaultScene: String
    var globalHotkey: GlobalHotkey
    var scenes: [Scene]
    var providers: ProvidersConfig
    var general: GeneralConfig

    init(
        version: Int = 1,
        defaultScene: String = "dictate",
        globalHotkey: GlobalHotkey = GlobalHotkey(toggleRecord: "CommandOrControl+Shift+H", pushToTalk: "CommandOrControl+Shift+G"),
        scenes: [Scene] = Scene.presets,
        providers: ProvidersConfig = ProvidersConfig(
            stt: ["iflytek": STTProviderConfig()],
            llm: ["openai": LLMProviderConfig()]
        ),
        general: GeneralConfig = GeneralConfig()
    ) {
        self.version = version
        self.defaultScene = defaultScene
        self.globalHotkey = globalHotkey
        self.scenes = scenes
        self.providers = providers
        self.general = general
    }

    static let `default` = AppConfig()
}
```

- [ ] **Step 4: Write failing tests for Scene**

```swift
// VerboTests/Models/SceneTests.swift
import Testing
import Foundation
@testable import Verbo

@Suite("Scene")
struct SceneTests {
    @Test("Preset scenes contain dictate, polish, translate")
    func presets() {
        let presets = Scene.presets
        #expect(presets.count == 3)
        #expect(presets[0].id == "dictate")
        #expect(presets[1].id == "polish")
        #expect(presets[2].id == "translate")
    }

    @Test("Dictate scene has one STT step")
    func dictateScene() {
        let dictate = Scene.presets[0]
        #expect(dictate.pipeline.count == 1)
        #expect(dictate.pipeline[0].type == .stt)
    }

    @Test("Polish scene has STT + LLM steps")
    func polishScene() {
        let polish = Scene.presets[1]
        #expect(polish.pipeline.count == 2)
        #expect(polish.pipeline[0].type == .stt)
        #expect(polish.pipeline[1].type == .llm)
        #expect(polish.pipeline[1].prompt?.contains("{{input}}") == true)
    }

    @Test("Scene JSON round-trip")
    func jsonRoundTrip() throws {
        let scene = Scene.presets[1]
        let data = try JSONEncoder().encode(scene)
        let decoded = try JSONDecoder().decode(Scene.self, from: data)
        #expect(decoded.id == scene.id)
        #expect(decoded.pipeline.count == scene.pipeline.count)
    }
}
```

- [ ] **Step 5: Implement Scene model**

```swift
// Verbo/Models/Scene.swift
import Foundation

struct SceneHotkey: Codable, Equatable, Sendable {
    var toggleRecord: String?
    var pushToTalk: String?
}

struct PipelineStep: Codable, Equatable, Sendable {
    var type: StepType
    var provider: String
    var lang: String?
    var prompt: String?

    enum StepType: String, Codable, Sendable {
        case stt
        case llm
    }
}

struct Scene: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var name: String
    var hotkey: SceneHotkey
    var pipeline: [PipelineStep]
    var output: OutputMode

    init(id: String, name: String, hotkey: SceneHotkey = SceneHotkey(), pipeline: [PipelineStep], output: OutputMode = .simulate) {
        self.id = id
        self.name = name
        self.hotkey = hotkey
        self.pipeline = pipeline
        self.output = output
    }

    static let presets: [Scene] = [
        Scene(
            id: "dictate",
            name: "语音输入",
            hotkey: SceneHotkey(toggleRecord: "Alt+D"),
            pipeline: [
                PipelineStep(type: .stt, provider: "iflytek", lang: "zh")
            ]
        ),
        Scene(
            id: "polish",
            name: "润色输入",
            hotkey: SceneHotkey(toggleRecord: "Alt+J"),
            pipeline: [
                PipelineStep(type: .stt, provider: "iflytek", lang: "zh"),
                PipelineStep(type: .llm, provider: "openai", prompt: "请润色以下口语化文字，使其更书面化，保持原意，直接输出结果：\n{{input}}")
            ]
        ),
        Scene(
            id: "translate",
            name: "中译英",
            hotkey: SceneHotkey(toggleRecord: "Alt+T"),
            pipeline: [
                PipelineStep(type: .stt, provider: "iflytek", lang: "zh"),
                PipelineStep(type: .llm, provider: "openai", prompt: "将以下中文翻译为英文，直接输出翻译结果：\n{{input}}")
            ]
        )
    ]
}
```

- [ ] **Step 6: Write failing tests for PipelineState and HistoryRecord**

```swift
// VerboTests/Models/PipelineStateTests.swift
import Testing
@testable import Verbo

@Suite("PipelineState")
struct PipelineStateTests {
    @Test("State transitions are well-defined")
    func stateValues() {
        let idle = PipelineState.idle
        let recording = PipelineState.recording
        let transcribing = PipelineState.transcribing(partial: "hello")
        let processing = PipelineState.processing(source: "hello", partial: "")
        let done = PipelineState.done(result: "Hello!", source: "hello")
        let error = PipelineState.error(message: "Network error")

        #expect(idle.isIdle)
        #expect(recording.isRecording)
        #expect(!idle.isRecording)

        if case .transcribing(let partial) = transcribing {
            #expect(partial == "hello")
        }
        if case .done(let result, let source) = done {
            #expect(result == "Hello!")
            #expect(source == "hello")
        }
        if case .error(let msg) = error {
            #expect(msg == "Network error")
        }
        _ = processing // suppress unused warning
    }
}
```

```swift
// VerboTests/Models/HistoryRecordTests.swift
import Testing
import Foundation
@testable import Verbo

@Suite("HistoryRecord")
struct HistoryRecordTests {
    @Test("Create and JSON round-trip")
    func roundTrip() throws {
        let record = HistoryRecord(
            sceneId: "polish",
            sceneName: "润色输入",
            originalText: "我觉得这个方案还行",
            finalText: "我认为这个方案可行",
            outputStatus: .inserted,
            pipelineSteps: ["stt:iflytek", "llm:openai"]
        )
        #expect(record.sceneId == "polish")
        #expect(record.outputStatus == .inserted)

        let data = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(HistoryRecord.self, from: data)
        #expect(decoded.id == record.id)
        #expect(decoded.finalText == record.finalText)
    }

    @Test("hasLLMProcessing returns true when original differs from final")
    func hasLLMProcessing() {
        let withLLM = HistoryRecord(
            sceneId: "polish", sceneName: "润色", originalText: "raw", finalText: "polished",
            outputStatus: .inserted, pipelineSteps: ["stt:iflytek", "llm:openai"]
        )
        let withoutLLM = HistoryRecord(
            sceneId: "dictate", sceneName: "听写", originalText: "text", finalText: "text",
            outputStatus: .inserted, pipelineSteps: ["stt:iflytek"]
        )
        #expect(withLLM.hasLLMProcessing)
        #expect(!withoutLLM.hasLLMProcessing)
    }
}
```

- [ ] **Step 7: Implement PipelineState and HistoryRecord**

```swift
// Verbo/Models/PipelineState.swift
import Foundation

enum PipelineState: Sendable, Equatable {
    case idle
    case recording
    case transcribing(partial: String)
    case processing(source: String, partial: String)
    case done(result: String, source: String?)
    case error(message: String)

    var isIdle: Bool {
        if case .idle = self { return true }
        return false
    }

    var isRecording: Bool {
        if case .recording = self { return true }
        return false
    }

    var isDone: Bool {
        if case .done = self { return true }
        return false
    }

    var isError: Bool {
        if case .error = self { return true }
        return false
    }
}
```

```swift
// Verbo/Models/HistoryRecord.swift
import Foundation

struct HistoryRecord: Codable, Identifiable, Sendable, Equatable {
    let id: UUID
    let timestamp: Date
    let sceneId: String
    let sceneName: String
    let originalText: String
    let finalText: String
    let outputStatus: OutputStatus
    let pipelineSteps: [String]

    var hasLLMProcessing: Bool {
        originalText != finalText
    }

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        sceneId: String,
        sceneName: String,
        originalText: String,
        finalText: String,
        outputStatus: OutputStatus,
        pipelineSteps: [String]
    ) {
        self.id = id
        self.timestamp = timestamp
        self.sceneId = sceneId
        self.sceneName = sceneName
        self.originalText = originalText
        self.finalText = finalText
        self.outputStatus = outputStatus
        self.pipelineSteps = pipelineSteps
    }

    enum OutputStatus: String, Codable, Sendable {
        case inserted
        case copied
        case failed
    }
}
```

- [ ] **Step 8: Run all model tests**

```bash
cd Verbo && xcodegen generate && xcodebuild test -project Verbo.xcodeproj -scheme VerboTests -configuration Debug 2>&1 | grep -E "(Test Suite|Test Case|passed|failed)"
```

Expected: All tests PASS

- [ ] **Step 9: Commit**

```bash
git add Verbo/Verbo/Models/ Verbo/VerboTests/Models/
git commit -m "feat: add data models (AppConfig, Scene, PipelineState, HistoryRecord)"
```

---

## Task 3: Design Tokens

**Files:**
- Create: `Verbo/Verbo/Utilities/DesignTokens.swift`

No tests needed — pure constants.

- [ ] **Step 1: Implement DesignTokens**

```swift
// Verbo/Utilities/DesignTokens.swift
import SwiftUI

enum DesignTokens {
    // MARK: - Colors (Warm Parchment Palette)
    enum Colors {
        // Primary
        static let nearBlack = Color(hex: 0x141413)
        static let terracotta = Color(hex: 0xc96442)
        static let coral = Color(hex: 0xd97757)

        // Surface
        static let parchment = Color(hex: 0xf5f4ed)
        static let ivory = Color(hex: 0xfaf9f5)
        static let warmSand = Color(hex: 0xe8e6dc)
        static let darkSurface = Color(hex: 0x30302e)

        // Text
        static let charcoalWarm = Color(hex: 0x4d4c48)
        static let oliveGray = Color(hex: 0x5e5d59)
        static let stoneGray = Color(hex: 0x87867f)
        static let warmSilver = Color(hex: 0xb0aea5)

        // Border
        static let borderCream = Color(hex: 0xf0eee6)
        static let borderWarm = Color(hex: 0xe8e6dc)

        // Semantic
        static let errorCrimson = Color(hex: 0xb53333)
        static let focusBlue = Color(hex: 0x3898ec)

        // Recording states
        static let recordingRed = terracotta
        static let processingCoral = coral
    }

    // MARK: - Typography
    enum Typography {
        static let headlineFont = Font.system(.title, design: .serif)
        static let bodyFont = Font.system(.body, design: .default)
        static let captionFont = Font.system(.caption, design: .default)
        static let monoFont = Font.system(.body, design: .monospaced)

        // Pill
        static let pillText = Font.system(size: 13, weight: .medium)
        static let pillTimer = Font.system(size: 12, weight: .medium, design: .monospaced)
        static let pillHotkey = Font.system(size: 11, weight: .regular)

        // Bubble
        static let bubbleText = Font.system(size: 14, weight: .regular)
        static let bubbleStatus = Font.system(size: 12, weight: .medium)

        // Settings
        static let settingsTitle = Font.system(size: 13, weight: .semibold)
        static let settingsBody = Font.system(size: 13, weight: .regular)
        static let settingsCaption = Font.system(size: 11, weight: .regular)
    }

    // MARK: - Spacing
    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    // MARK: - Corner Radius
    enum Radius {
        static let small: CGFloat = 6
        static let medium: CGFloat = 8
        static let large: CGFloat = 12
        static let pill: CGFloat = 18
        static let bubble: CGFloat = 16
    }

    // MARK: - Shadows (Ring-based)
    enum Shadows {
        static let ring = Color.black.opacity(0.08)
        static let whisper = Color.black.opacity(0.05)
    }

    // MARK: - Animation
    enum Animation {
        static let quick = SwiftUI.Animation.easeInOut(duration: 0.15)
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.25)
        static let expand = SwiftUI.Animation.spring(response: 0.35, dampingFraction: 0.8)
    }

    // MARK: - Pill Dimensions
    enum Pill {
        static let height: CGFloat = 36
        static let minWidth: CGFloat = 150
        static let dotSize: CGFloat = 8
    }
}

// MARK: - Color Hex Init
extension Color {
    init(hex: UInt32, opacity: Double = 1.0) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue, opacity: opacity)
    }
}
```

- [ ] **Step 2: Regenerate project and verify build**

```bash
cd Verbo && xcodegen generate && xcodebuild -project Verbo.xcodeproj -scheme Verbo -configuration Debug build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Verbo/Verbo/Utilities/DesignTokens.swift
git commit -m "feat: add design tokens (colors, typography, spacing)"
```

---

## Task 4: ConfigManager

**Files:**
- Create: `Verbo/Verbo/Core/ConfigManager.swift`
- Create: `Verbo/VerboTests/Core/ConfigManagerTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// VerboTests/Core/ConfigManagerTests.swift
import Testing
import Foundation
@testable import Verbo

@Suite("ConfigManager")
struct ConfigManagerTests {
    let tempDir: URL

    init() throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    @Test("Loads default config when no file exists")
    func loadDefault() async throws {
        let manager = ConfigManager(directory: tempDir)
        await manager.load()
        let config = await manager.config
        #expect(config.version == 1)
        #expect(config.scenes.count == 3)
    }

    @Test("Saves and loads config round-trip")
    func saveAndLoad() async throws {
        let manager = ConfigManager(directory: tempDir)
        await manager.load()
        var config = await manager.config
        config = AppConfig(
            version: config.version,
            defaultScene: "polish",
            globalHotkey: config.globalHotkey,
            scenes: config.scenes,
            providers: config.providers,
            general: config.general
        )
        await manager.update(config)
        try await manager.save()

        let manager2 = ConfigManager(directory: tempDir)
        await manager2.load()
        let loaded = await manager2.config
        #expect(loaded.defaultScene == "polish")
    }

    @Test("Config file path is correct")
    func configPath() async {
        let manager = ConfigManager(directory: tempDir)
        let path = await manager.configFileURL
        #expect(path.lastPathComponent == "config.json")
    }
}
```

- [ ] **Step 2: Run tests to verify failure**

```bash
cd Verbo && xcodegen generate && xcodebuild test -project Verbo.xcodeproj -scheme VerboTests 2>&1 | tail -20
```

Expected: FAIL — `ConfigManager` not defined

- [ ] **Step 3: Implement ConfigManager**

```swift
// Verbo/Core/ConfigManager.swift
import Foundation
import Observation

@Observable
@MainActor
final class ConfigManager: Sendable {
    private(set) var config: AppConfig = .default
    let configFileURL: URL

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    private let decoder = JSONDecoder()

    init(directory: URL? = nil) {
        let dir = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("Verbo")
        self.configFileURL = dir.appendingPathComponent("config.json")
    }

    func load() {
        guard FileManager.default.fileExists(atPath: configFileURL.path) else {
            config = .default
            return
        }
        do {
            let data = try Data(contentsOf: configFileURL)
            config = try decoder.decode(AppConfig.self, from: data)
        } catch {
            print("[ConfigManager] Failed to load config: \(error). Using defaults.")
            config = .default
        }
    }

    func update(_ newConfig: AppConfig) {
        config = newConfig
    }

    func save() throws {
        let dir = configFileURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        let data = try encoder.encode(config)
        try data.write(to: configFileURL, options: .atomic)
    }

    func getSTTProviderConfig(_ name: String) -> STTProviderConfig? {
        config.providers.stt[name]
    }

    func getLLMProviderConfig(_ name: String) -> LLMProviderConfig? {
        config.providers.llm[name]
    }

    func getScene(_ id: String) -> Scene? {
        config.scenes.first { $0.id == id }
    }

    func defaultScene() -> Scene? {
        getScene(config.defaultScene)
    }
}
```

- [ ] **Step 4: Run tests**

```bash
cd Verbo && xcodegen generate && xcodebuild test -project Verbo.xcodeproj -scheme VerboTests 2>&1 | grep -E "(Test Suite|passed|failed)"
```

Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add Verbo/Verbo/Core/ConfigManager.swift Verbo/VerboTests/Core/ConfigManagerTests.swift
git commit -m "feat: add ConfigManager with JSON persistence"
```

---

## Task 5: STT Adapter Protocol + iFlytek Implementation

**Files:**
- Create: `Verbo/Verbo/Adapters/STTAdapter.swift`
- Create: `Verbo/Verbo/Adapters/IFlytekSTTAdapter.swift`
- Create: `Verbo/VerboTests/Adapters/IFlytekSTTAdapterTests.swift`

- [ ] **Step 1: Write failing tests for iFlytek auth URL and response parsing**

```swift
// VerboTests/Adapters/IFlytekSTTAdapterTests.swift
import Testing
import Foundation
@testable import Verbo

@Suite("IFlytekSTTAdapter")
struct IFlytekSTTAdapterTests {
    @Test("Auth URL contains required query parameters")
    func authUrl() throws {
        let url = IFlytekSTTAdapter.buildAuthURL(
            appId: "test_app",
            apiKey: "test_key",
            apiSecret: "test_secret"
        )
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        let queryItems = components.queryItems ?? []
        let paramNames = Set(queryItems.map(\.name))
        #expect(paramNames.contains("authorization"))
        #expect(paramNames.contains("date"))
        #expect(paramNames.contains("host"))
        #expect(components.host == "iat-api.xfyun.cn")
        #expect(components.path == "/v2/iat")
    }

    @Test("Parse single response frame")
    func parseSingleFrame() throws {
        let json = """
        {"code":0,"data":{"result":{"ws":[{"cw":[{"w":"你好","sc":0}]}],"sn":1,"ls":false,"pgs":"apd"},"status":1}}
        """
        let frame = try JSONDecoder().decode(IFlytekResponseFrame.self, from: Data(json.utf8))
        #expect(frame.code == 0)
        #expect(frame.data?.result?.ws?.first?.cw?.first?.w == "你好")
        #expect(frame.data?.result?.sn == 1)
        #expect(frame.data?.result?.pgs == "apd")
    }

    @Test("Accumulator handles append mode")
    func accumulatorAppend() {
        var acc = IFlytekResultAccumulator()
        acc.process(sn: 1, pgs: "apd", rg: nil, text: "你好")
        acc.process(sn: 2, pgs: "apd", rg: nil, text: "世界")
        #expect(acc.currentText == "你好世界")
    }

    @Test("Accumulator handles replace mode")
    func accumulatorReplace() {
        var acc = IFlytekResultAccumulator()
        acc.process(sn: 1, pgs: "apd", rg: nil, text: "你好")
        acc.process(sn: 2, pgs: "apd", rg: nil, text: "世界")
        acc.process(sn: 3, pgs: "rpl", rg: [1, 2], text: "你好世界！")
        #expect(acc.currentText == "你好世界！")
    }

    @Test("Accumulator handles multiple replaces")
    func accumulatorMultipleReplaces() {
        var acc = IFlytekResultAccumulator()
        acc.process(sn: 1, pgs: "apd", rg: nil, text: "今天")
        acc.process(sn: 2, pgs: "apd", rg: nil, text: "天气")
        acc.process(sn: 3, pgs: "rpl", rg: [1, 2], text: "今天天气")
        acc.process(sn: 4, pgs: "apd", rg: nil, text: "很好")
        #expect(acc.currentText == "今天天气很好")
    }
}
```

- [ ] **Step 2: Run tests to verify failure**

Expected: FAIL — types not defined

- [ ] **Step 3: Implement STTAdapter protocol**

```swift
// Verbo/Adapters/STTAdapter.swift
import Foundation

protocol STTAdapter: Sendable {
    var name: String { get }
    var supportsStreaming: Bool { get }

    func transcribe(audio: Data, lang: String) async throws -> String

    func transcribeStream(
        audioStream: AsyncStream<Data>,
        lang: String
    ) -> AsyncThrowingStream<String, Error>
}
```

- [ ] **Step 4: Implement iFlytek response types and accumulator**

```swift
// Verbo/Adapters/IFlytekSTTAdapter.swift (part 1 — types + accumulator)
import Foundation
import CryptoKit

// MARK: - Response Types

struct IFlytekResponseFrame: Codable, Sendable {
    let code: Int
    let message: String?
    let data: IFlytekData?
    let sid: String?
}

struct IFlytekData: Codable, Sendable {
    let result: IFlytekResult?
    let status: Int?
}

struct IFlytekResult: Codable, Sendable {
    let ws: [IFlytekWord]?
    let sn: Int?
    let ls: Bool?
    let pgs: String?
    let rg: [Int]?
}

struct IFlytekWord: Codable, Sendable {
    let cw: [IFlytekChar]?
}

struct IFlytekChar: Codable, Sendable {
    let w: String
    let sc: Double?
}

// MARK: - Result Accumulator

struct IFlytekResultAccumulator: Sendable {
    private var sentences: [(sn: Int, text: String)] = []

    var currentText: String {
        sentences.map(\.text).joined()
    }

    mutating func process(sn: Int, pgs: String?, rg: [Int]?, text: String) {
        if pgs == "rpl", let rg, rg.count == 2 {
            let rgBegin = rg[0]
            let rgEnd = rg[1]
            sentences.removeAll { $0.sn >= rgBegin && $0.sn <= rgEnd }
        }
        sentences.append((sn: sn, text: text))
        sentences.sort { $0.sn < $1.sn }
    }

    mutating func reset() {
        sentences = []
    }
}
```

- [ ] **Step 5: Implement iFlytek auth URL builder and adapter**

```swift
// Verbo/Adapters/IFlytekSTTAdapter.swift (part 2 — adapter)

// MARK: - Adapter

final class IFlytekSTTAdapter: STTAdapter, @unchecked Sendable {
    let name = "iflytek"
    let supportsStreaming = true

    private let appId: String
    private let apiKey: String
    private let apiSecret: String

    init(appId: String, apiKey: String, apiSecret: String) {
        self.appId = appId
        self.apiKey = apiKey
        self.apiSecret = apiSecret
    }

    static func buildAuthURL(appId: String, apiKey: String, apiSecret: String) -> URL {
        let host = "iat-api.xfyun.cn"
        let path = "/v2/iat"

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
        formatter.timeZone = TimeZone(identifier: "GMT")
        let date = formatter.string(from: Date())

        let signatureOrigin = "host: \(host)\ndate: \(date)\nGET \(path) HTTP/1.1"
        let key = SymmetricKey(data: Data(apiSecret.utf8))
        let hmac = HMAC<SHA256>.authenticationCode(for: Data(signatureOrigin.utf8), using: key)
        let signature = Data(hmac).base64EncodedString()

        let authorizationOrigin = "api_key=\"\(apiKey)\", algorithm=\"hmac-sha256\", headers=\"host date request-line\", signature=\"\(signature)\""
        let authorization = Data(authorizationOrigin.utf8).base64EncodedString()

        let dateEncoded = date.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
        let hostEncoded = host.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
        let authEncoded = authorization.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!

        let urlString = "wss://\(host)\(path)?authorization=\(authEncoded)&date=\(dateEncoded)&host=\(hostEncoded)"
        return URL(string: urlString)!
    }

    func transcribe(audio: Data, lang: String) async throws -> String {
        let stream = AsyncStream<Data> { continuation in
            let chunkSize = 1280
            var offset = 0
            while offset < audio.count {
                let end = min(offset + chunkSize, audio.count)
                continuation.yield(audio[offset..<end])
                offset = end
            }
            continuation.finish()
        }
        var finalText = ""
        for try await text in transcribeStream(audioStream: stream, lang: lang) {
            finalText = text
        }
        return finalText
    }

    func transcribeStream(
        audioStream: AsyncStream<Data>,
        lang: String
    ) -> AsyncThrowingStream<String, Error> {
        let appId = self.appId
        let apiKey = self.apiKey
        let apiSecret = self.apiSecret

        return AsyncThrowingStream { continuation in
            let task = Task {
                let url = Self.buildAuthURL(appId: appId, apiKey: apiKey, apiSecret: apiSecret)
                let session = URLSession.shared
                let wsTask = session.webSocketTask(with: url)
                wsTask.resume()

                var accumulator = IFlytekResultAccumulator()
                var frameIndex = 0

                // Start receiving in background
                let receiveTask = Task {
                    while !Task.isCancelled {
                        let message: URLSessionWebSocketTask.Message
                        do {
                            message = try await wsTask.receive()
                        } catch {
                            continuation.finish(throwing: error)
                            return
                        }

                        let data: Data
                        switch message {
                        case .string(let text):
                            data = Data(text.utf8)
                        case .data(let d):
                            data = d
                        @unknown default:
                            continue
                        }

                        do {
                            let frame = try JSONDecoder().decode(IFlytekResponseFrame.self, from: data)
                            if frame.code != 0 {
                                continuation.finish(throwing: IFlytekError.apiError(code: frame.code, message: frame.message ?? "Unknown"))
                                return
                            }
                            if let result = frame.data?.result,
                               let ws = result.ws, let sn = result.sn {
                                let text = ws.flatMap { $0.cw ?? [] }.map(\.w).joined()
                                if !text.isEmpty {
                                    accumulator.process(sn: sn, pgs: result.pgs, rg: result.rg, text: text)
                                    continuation.yield(accumulator.currentText)
                                }
                            }
                            if frame.data?.status == 2 {
                                continuation.finish()
                                return
                            }
                        } catch {
                            continuation.finish(throwing: error)
                            return
                        }
                    }
                }

                // Send audio chunks
                let iflytekLang: String
                switch lang {
                case "en": iflytekLang = "en_us"
                default: iflytekLang = "zh_cn"
                }

                for await chunk in audioStream {
                    let base64Audio = chunk.base64EncodedString()
                    let status: Int
                    if frameIndex == 0 {
                        status = 0 // first frame
                    } else {
                        status = 1 // continue frame
                    }

                    var params: [String: Any] = [
                        "data": [
                            "status": status,
                            "format": "audio/L16;rate=16000",
                            "encoding": "raw",
                            "audio": base64Audio
                        ] as [String: Any]
                    ]

                    if frameIndex == 0 {
                        params["common"] = ["app_id": appId] as [String: Any]
                        params["business"] = [
                            "language": iflytekLang,
                            "domain": "iat",
                            "accent": iflytekLang == "zh_cn" ? "mandarin" : iflytekLang,
                            "dwa": "wpgs",
                            "ptt": 1,
                            "vad_eos": 3000
                        ] as [String: Any]
                    }

                    let jsonData = try JSONSerialization.data(withJSONObject: params)
                    let jsonString = String(data: jsonData, encoding: .utf8)!
                    try await wsTask.send(.string(jsonString))
                    frameIndex += 1
                }

                // Send last frame
                let lastParams: [String: Any] = [
                    "data": [
                        "status": 2,
                        "format": "audio/L16;rate=16000",
                        "encoding": "raw",
                        "audio": ""
                    ] as [String: Any]
                ]
                let lastData = try JSONSerialization.data(withJSONObject: lastParams)
                let lastString = String(data: lastData, encoding: .utf8)!
                try await wsTask.send(.string(lastString))

                // Wait for receive to finish
                _ = await receiveTask.result
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}

enum IFlytekError: Error, LocalizedError {
    case apiError(code: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .apiError(let code, let message):
            return "iFlytek API error \(code): \(message)"
        }
    }
}
```

- [ ] **Step 6: Run tests**

```bash
cd Verbo && xcodegen generate && xcodebuild test -project Verbo.xcodeproj -scheme VerboTests 2>&1 | grep -E "(Test Suite|passed|failed)"
```

Expected: All tests PASS

- [ ] **Step 7: Commit**

```bash
git add Verbo/Verbo/Adapters/STTAdapter.swift Verbo/Verbo/Adapters/IFlytekSTTAdapter.swift \
       Verbo/VerboTests/Adapters/IFlytekSTTAdapterTests.swift
git commit -m "feat: add STT adapter protocol and iFlytek WebSocket implementation"
```

---

## Task 6: LLM Adapter Protocol + OpenAI Implementation

**Files:**
- Create: `Verbo/Verbo/Adapters/LLMAdapter.swift`
- Create: `Verbo/Verbo/Adapters/OpenAILLMAdapter.swift`
- Create: `Verbo/VerboTests/Adapters/OpenAILLMAdapterTests.swift`

- [ ] **Step 1: Write failing tests for SSE parsing**

```swift
// VerboTests/Adapters/OpenAILLMAdapterTests.swift
import Testing
import Foundation
@testable import Verbo

@Suite("OpenAILLMAdapter")
struct OpenAILLMAdapterTests {
    @Test("Parse SSE line extracts data content")
    func parseSSELine() {
        let line = "data: {\"choices\":[{\"delta\":{\"content\":\"Hello\"}}]}"
        let content = OpenAISSEParser.parseContentFromLine(line)
        #expect(content == "Hello")
    }

    @Test("Parse SSE done signal returns nil")
    func parseSSEDone() {
        let line = "data: [DONE]"
        let content = OpenAISSEParser.parseContentFromLine(line)
        #expect(content == nil)
    }

    @Test("Parse SSE non-data line returns nil")
    func parseNonDataLine() {
        let content = OpenAISSEParser.parseContentFromLine(": keep-alive")
        #expect(content == nil)
    }

    @Test("Build request body has correct structure")
    func buildRequestBody() throws {
        let body = OpenAILLMAdapter.buildRequestBody(
            model: "gpt-4o-mini",
            prompt: "Hello, world!",
            stream: true
        )
        let json = try JSONSerialization.jsonObject(with: body) as! [String: Any]
        let messages = json["messages"] as! [[String: String]]
        #expect(messages.count == 1)
        #expect(messages[0]["role"] == "user")
        #expect(messages[0]["content"] == "Hello, world!")
        #expect(json["stream"] as! Bool == true)
        #expect(json["model"] as! String == "gpt-4o-mini")
    }

    @Test("Parse SSE with Chinese content")
    func parseChineseSSE() {
        let line = "data: {\"choices\":[{\"delta\":{\"content\":\"你好\"}}]}"
        let content = OpenAISSEParser.parseContentFromLine(line)
        #expect(content == "你好")
    }
}
```

- [ ] **Step 2: Run tests to verify failure**

Expected: FAIL — types not defined

- [ ] **Step 3: Implement LLM protocol**

```swift
// Verbo/Adapters/LLMAdapter.swift
import Foundation

protocol LLMAdapter: Sendable {
    var name: String { get }

    func complete(prompt: String) async throws -> String

    func completeStream(prompt: String) -> AsyncThrowingStream<String, Error>
}
```

- [ ] **Step 4: Implement OpenAI adapter with SSE parser**

```swift
// Verbo/Adapters/OpenAILLMAdapter.swift
import Foundation

// MARK: - SSE Parser

enum OpenAISSEParser {
    static func parseContentFromLine(_ line: String) -> String? {
        guard line.hasPrefix("data: ") else { return nil }
        let payload = String(line.dropFirst(6))
        guard payload != "[DONE]" else { return nil }

        guard let data = payload.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let delta = choices.first?["delta"] as? [String: Any],
              let content = delta["content"] as? String else {
            return nil
        }
        return content
    }
}

// MARK: - Adapter

final class OpenAILLMAdapter: LLMAdapter, @unchecked Sendable {
    let name = "openai"

    private let apiKey: String
    private let model: String
    private let baseUrl: String

    init(apiKey: String, model: String = "gpt-4o-mini", baseUrl: String = "https://api.openai.com/v1") {
        self.apiKey = apiKey
        self.model = model
        self.baseUrl = baseUrl
    }

    static func buildRequestBody(model: String, prompt: String, stream: Bool) -> Data {
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "stream": stream
        ]
        return try! JSONSerialization.data(withJSONObject: body)
    }

    private func buildRequest(stream: Bool, prompt: String) -> URLRequest {
        let url = URL(string: "\(baseUrl)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = Self.buildRequestBody(model: model, prompt: prompt, stream: stream)
        return request
    }

    func complete(prompt: String) async throws -> String {
        let request = buildRequest(stream: false, prompt: prompt)
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            let body = String(data: data, encoding: .utf8) ?? ""
            throw OpenAIError.httpError(statusCode: statusCode, body: body)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw OpenAIError.parseError
        }
        return content
    }

    func completeStream(prompt: String) -> AsyncThrowingStream<String, Error> {
        let request = buildRequest(stream: true, prompt: prompt)

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                        continuation.finish(throwing: OpenAIError.httpError(statusCode: statusCode, body: ""))
                        return
                    }

                    var accumulated = ""
                    for try await line in bytes.lines {
                        if let content = OpenAISSEParser.parseContentFromLine(line) {
                            accumulated += content
                            continuation.yield(accumulated)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}

enum OpenAIError: Error, LocalizedError {
    case httpError(statusCode: Int, body: String)
    case parseError

    var errorDescription: String? {
        switch self {
        case .httpError(let code, let body):
            return "OpenAI API error \(code): \(body)"
        case .parseError:
            return "Failed to parse OpenAI response"
        }
    }
}
```

- [ ] **Step 5: Run tests**

```bash
cd Verbo && xcodegen generate && xcodebuild test -project Verbo.xcodeproj -scheme VerboTests 2>&1 | grep -E "(Test Suite|passed|failed)"
```

Expected: All tests PASS

- [ ] **Step 6: Commit**

```bash
git add Verbo/Verbo/Adapters/LLMAdapter.swift Verbo/Verbo/Adapters/OpenAILLMAdapter.swift \
       Verbo/VerboTests/Adapters/OpenAILLMAdapterTests.swift
git commit -m "feat: add LLM adapter protocol and OpenAI SSE implementation"
```

---

## Task 7: AudioRecorder

**Files:**
- Create: `Verbo/Verbo/Core/AudioRecorder.swift`
- Create: `Verbo/VerboTests/Core/AudioRecorderTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// VerboTests/Core/AudioRecorderTests.swift
import Testing
import Foundation
@testable import Verbo

@Suite("AudioRecorder")
struct AudioRecorderTests {
    @Test("AudioRecorder starts in idle state")
    func initialState() async {
        let recorder = AudioRecorder()
        let isRecording = await recorder.isRecording
        #expect(!isRecording)
    }

    @Test("PCM format is 16kHz mono 16-bit")
    func pcmFormat() {
        let format = AudioRecorder.targetFormat
        #expect(format.sampleRate == 16000)
        #expect(format.channelCount == 1)
    }

    @Test("Chunk size is 1280 bytes (40ms at 16kHz 16-bit mono)")
    func chunkSize() {
        // 16000 samples/sec * 2 bytes/sample * 0.04 sec = 1280 bytes
        #expect(AudioRecorder.chunkSize == 1280)
    }
}
```

- [ ] **Step 2: Run tests to verify failure**

Expected: FAIL — `AudioRecorder` not defined

- [ ] **Step 3: Implement AudioRecorder**

```swift
// Verbo/Core/AudioRecorder.swift
import AVFoundation
import Foundation

actor AudioRecorder {
    static let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16,
        sampleRate: 16000,
        channels: 1,
        interleaved: true
    )!

    static let chunkSize = 1280 // 40ms at 16kHz 16-bit mono

    private let engine = AVAudioEngine()
    private(set) var isRecording = false
    private var audioBuffer = Data()
    private var streamContinuation: AsyncStream<Data>.Continuation?

    var audioLevels: [Float] = Array(repeating: 0, count: 5)

    func start() -> AsyncStream<Data> {
        let stream = AsyncStream<Data> { continuation in
            self.streamContinuation = continuation
        }

        do {
            let inputNode = engine.inputNode
            let inputFormat = inputNode.outputFormat(forBus: 0)

            guard let targetFormat = Self.targetFormat else {
                return stream
            }

            guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
                return stream
            }

            inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
                guard let self else { return }

                let frameCount = AVAudioFrameCount(targetFormat.sampleRate * Double(buffer.frameLength) / inputFormat.sampleRate)
                guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: frameCount) else { return }

                var error: NSError?
                let status = converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
                    outStatus.pointee = .haveData
                    return buffer
                }

                guard status != .error, error == nil else { return }

                let data = Data(
                    bytes: convertedBuffer.int16ChannelData!.pointee,
                    count: Int(convertedBuffer.frameLength) * 2
                )

                Task { await self.processAudioData(data) }
            }

            engine.prepare()
            try engine.start()
            isRecording = true
            audioBuffer = Data()
        } catch {
            print("[AudioRecorder] Failed to start: \(error)")
        }

        return stream
    }

    private func processAudioData(_ data: Data) {
        audioBuffer.append(data)
        updateAudioLevels(from: data)

        while audioBuffer.count >= Self.chunkSize {
            let chunk = audioBuffer.prefix(Self.chunkSize)
            streamContinuation?.yield(Data(chunk))
            audioBuffer.removeFirst(Self.chunkSize)
        }
    }

    private func updateAudioLevels(from data: Data) {
        data.withUnsafeBytes { rawBuffer in
            guard let samples = rawBuffer.baseAddress?.assumingMemoryBound(to: Int16.self) else { return }
            let count = data.count / 2
            guard count > 0 else { return }

            let segmentSize = count / 5
            guard segmentSize > 0 else { return }

            var newLevels = [Float](repeating: 0, count: 5)
            for i in 0..<5 {
                let start = i * segmentSize
                let end = min(start + segmentSize, count)
                var sum: Float = 0
                for j in start..<end {
                    sum += abs(Float(samples[j]))
                }
                let avg = sum / Float(end - start)
                newLevels[i] = min(avg / 8000.0, 1.0)
            }
            audioLevels = newLevels
        }
    }

    func stop() -> Data {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRecording = false

        // Flush remaining buffer
        if !audioBuffer.isEmpty {
            streamContinuation?.yield(audioBuffer)
        }
        streamContinuation?.finish()
        streamContinuation = nil

        let remaining = audioBuffer
        audioBuffer = Data()
        return remaining
    }
}
```

- [ ] **Step 4: Run tests**

```bash
cd Verbo && xcodegen generate && xcodebuild test -project Verbo.xcodeproj -scheme VerboTests 2>&1 | grep -E "(Test Suite|passed|failed)"
```

Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add Verbo/Verbo/Core/AudioRecorder.swift Verbo/VerboTests/Core/AudioRecorderTests.swift
git commit -m "feat: add AudioRecorder with AVAudioEngine streaming"
```

---

## Task 8: TextOutputService

**Files:**
- Create: `Verbo/Verbo/Core/TextOutputService.swift`
- Create: `Verbo/VerboTests/Core/TextOutputServiceTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// VerboTests/Core/TextOutputServiceTests.swift
import Testing
import Foundation
@testable import Verbo

@Suite("TextOutputService")
struct TextOutputServiceTests {
    @Test("Clipboard write and read round-trip")
    func clipboardRoundTrip() {
        let service = TextOutputService()
        let original = "Hello, 你好世界"
        service.writeToClipboard(original)
        let read = service.readFromClipboard()
        #expect(read == original)
    }

    @Test("Output mode clipboard writes to clipboard")
    func outputModeClipboard() async {
        let service = TextOutputService()
        let result = await service.output(text: "Test text", mode: .clipboard)
        #expect(result == .copied)
        let clipboard = service.readFromClipboard()
        #expect(clipboard == "Test text")
    }
}
```

- [ ] **Step 2: Run tests to verify failure**

Expected: FAIL — `TextOutputService` not defined

- [ ] **Step 3: Implement TextOutputService**

```swift
// Verbo/Core/TextOutputService.swift
import AppKit
import CoreGraphics
import Foundation

final class TextOutputService: Sendable {

    func output(text: String, mode: OutputMode) async -> HistoryRecord.OutputStatus {
        switch mode {
        case .simulate:
            return await simulateInput(text: text)
        case .clipboard:
            writeToClipboard(text)
            return .copied
        }
    }

    // MARK: - CGEvent Keyboard Simulation

    private func simulateInput(text: String) async -> HistoryRecord.OutputStatus {
        // Save current clipboard
        let savedClipboard = readFromClipboard()

        // Try CGEvent first
        let success = simulateWithCGEvent(text: text)
        if success {
            return .inserted
        }

        // Fallback: clipboard + Cmd+V
        writeToClipboard(text)
        let pasteSuccess = simulatePaste()

        // Restore original clipboard after a delay
        if pasteSuccess {
            Task {
                try? await Task.sleep(for: .milliseconds(200))
                if let saved = savedClipboard {
                    self.writeToClipboard(saved)
                }
            }
            return .inserted
        }

        return .failed
    }

    private func simulateWithCGEvent(text: String) -> Bool {
        let source = CGEventSource(stateID: .hidSystemState)

        for char in text.unicodeScalars {
            let utf16 = Array(String(char).utf16)
            guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) else {
                return false
            }
            keyDown.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)

            guard let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else {
                return false
            }
            keyUp.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)

            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)
        }

        return true
    }

    private func simulatePaste() -> Bool {
        let source = CGEventSource(stateID: .hidSystemState)

        // Cmd+V
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),  // 9 = V key
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else {
            return false
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)

        return true
    }

    // MARK: - Clipboard

    func writeToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    func readFromClipboard() -> String? {
        NSPasteboard.general.string(forType: .string)
    }
}
```

- [ ] **Step 4: Run tests**

```bash
cd Verbo && xcodegen generate && xcodebuild test -project Verbo.xcodeproj -scheme VerboTests 2>&1 | grep -E "(Test Suite|passed|failed)"
```

Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add Verbo/Verbo/Core/TextOutputService.swift Verbo/VerboTests/Core/TextOutputServiceTests.swift
git commit -m "feat: add TextOutputService with CGEvent simulation and clipboard fallback"
```

---

## Task 9: HistoryManager

**Files:**
- Create: `Verbo/Verbo/Core/HistoryManager.swift`
- Create: `Verbo/VerboTests/Core/HistoryManagerTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// VerboTests/Core/HistoryManagerTests.swift
import Testing
import Foundation
@testable import Verbo

@Suite("HistoryManager")
struct HistoryManagerTests {
    let tempDir: URL

    init() throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    @Test("Add record and retrieve")
    func addAndRetrieve() async throws {
        let manager = HistoryManager(directory: tempDir)
        await manager.load()

        let record = HistoryRecord(
            sceneId: "dictate", sceneName: "语音输入",
            originalText: "你好", finalText: "你好",
            outputStatus: .inserted, pipelineSteps: ["stt:iflytek"]
        )
        await manager.add(record)
        let records = await manager.records
        #expect(records.count == 1)
        #expect(records[0].finalText == "你好")
    }

    @Test("Persist and reload")
    func persistAndReload() async throws {
        let manager = HistoryManager(directory: tempDir)
        await manager.load()

        let record = HistoryRecord(
            sceneId: "dictate", sceneName: "语音输入",
            originalText: "test", finalText: "test",
            outputStatus: .inserted, pipelineSteps: ["stt:iflytek"]
        )
        await manager.add(record)
        try await manager.save()

        let manager2 = HistoryManager(directory: tempDir)
        await manager2.load()
        let records = await manager2.records
        #expect(records.count == 1)
    }

    @Test("Search filters by text")
    func search() async {
        let manager = HistoryManager(directory: tempDir)
        await manager.load()

        await manager.add(HistoryRecord(
            sceneId: "a", sceneName: "A", originalText: "hello world", finalText: "hello world",
            outputStatus: .inserted, pipelineSteps: []
        ))
        await manager.add(HistoryRecord(
            sceneId: "b", sceneName: "B", originalText: "goodbye", finalText: "goodbye",
            outputStatus: .inserted, pipelineSteps: []
        ))

        let results = await manager.search(query: "hello")
        #expect(results.count == 1)
        #expect(results[0].sceneId == "a")
    }

    @Test("Clear all removes all records")
    func clearAll() async throws {
        let manager = HistoryManager(directory: tempDir)
        await manager.load()

        await manager.add(HistoryRecord(
            sceneId: "a", sceneName: "A", originalText: "x", finalText: "x",
            outputStatus: .inserted, pipelineSteps: []
        ))
        await manager.clearAll()
        let records = await manager.records
        #expect(records.isEmpty)
    }
}
```

- [ ] **Step 2: Run tests to verify failure**

Expected: FAIL — `HistoryManager` not defined

- [ ] **Step 3: Implement HistoryManager**

```swift
// Verbo/Core/HistoryManager.swift
import Foundation
import Observation

@Observable
@MainActor
final class HistoryManager: Sendable {
    private(set) var records: [HistoryRecord] = []
    private let fileURL: URL

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted]
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    init(directory: URL? = nil) {
        let dir = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("Verbo")
        self.fileURL = dir.appendingPathComponent("history.json")
    }

    func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            records = []
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            records = try decoder.decode([HistoryRecord].self, from: data)
        } catch {
            print("[HistoryManager] Failed to load: \(error)")
            records = []
        }
    }

    func add(_ record: HistoryRecord) {
        records.insert(record, at: 0)
    }

    func save() throws {
        let dir = fileURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        let data = try encoder.encode(records)
        try data.write(to: fileURL, options: .atomic)
    }

    func search(query: String) -> [HistoryRecord] {
        guard !query.isEmpty else { return records }
        let lowered = query.lowercased()
        return records.filter {
            $0.finalText.lowercased().contains(lowered) ||
            $0.originalText.lowercased().contains(lowered) ||
            $0.sceneName.lowercased().contains(lowered)
        }
    }

    func filter(byScene sceneId: String) -> [HistoryRecord] {
        records.filter { $0.sceneId == sceneId }
    }

    func clearAll() {
        records = []
    }

    func pruneOlderThan(days: Int) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        records = records.filter { $0.timestamp > cutoff }
    }
}
```

- [ ] **Step 4: Run tests**

```bash
cd Verbo && xcodegen generate && xcodebuild test -project Verbo.xcodeproj -scheme VerboTests 2>&1 | grep -E "(Test Suite|passed|failed)"
```

Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add Verbo/Verbo/Core/HistoryManager.swift Verbo/VerboTests/Core/HistoryManagerTests.swift
git commit -m "feat: add HistoryManager with JSON persistence and search"
```

---

## Task 10: PipelineEngine

**Files:**
- Create: `Verbo/Verbo/Core/PipelineEngine.swift`
- Create: `Verbo/VerboTests/PipelineEngineTests.swift`

- [ ] **Step 1: Write failing tests with mock adapters**

```swift
// VerboTests/PipelineEngineTests.swift
import Testing
import Foundation
@testable import Verbo

// MARK: - Mock Adapters

final class MockSTTAdapter: STTAdapter, @unchecked Sendable {
    let name = "mock-stt"
    let supportsStreaming = true
    var transcribeResult = "你好世界"

    func transcribe(audio: Data, lang: String) async throws -> String {
        transcribeResult
    }

    func transcribeStream(audioStream: AsyncStream<Data>, lang: String) -> AsyncThrowingStream<String, Error> {
        let result = transcribeResult
        return AsyncThrowingStream { continuation in
            Task {
                // Consume audio stream
                for await _ in audioStream {}
                continuation.yield(result)
                continuation.finish()
            }
        }
    }
}

final class MockLLMAdapter: LLMAdapter, @unchecked Sendable {
    let name = "mock-llm"
    var completeResult = "Polished text"

    func complete(prompt: String) async throws -> String {
        completeResult
    }

    func completeStream(prompt: String) -> AsyncThrowingStream<String, Error> {
        let result = completeResult
        return AsyncThrowingStream { continuation in
            Task {
                for (index, char) in result.enumerated() {
                    let partial = String(result.prefix(index + 1))
                    continuation.yield(partial)
                }
                continuation.finish()
            }
        }
    }
}

@Suite("PipelineEngine")
struct PipelineEngineTests {
    @Test("Execute STT-only pipeline")
    func sttOnly() async throws {
        let mockSTT = MockSTTAdapter()
        mockSTT.transcribeResult = "你好世界"

        let engine = PipelineEngine()
        let audioStream = AsyncStream<Data> { $0.finish() }

        let steps = [PipelineStep(type: .stt, provider: "mock-stt", lang: "zh")]

        var states: [PipelineState] = []
        for try await state in await engine.execute(
            steps: steps,
            audioStream: audioStream,
            getSTT: { _ in mockSTT },
            getLLM: { _ in nil }
        ) {
            states.append(state)
        }

        let lastState = states.last!
        if case .done(let result, _) = lastState {
            #expect(result == "你好世界")
        } else {
            #expect(Bool(false), "Expected .done state, got \(lastState)")
        }
    }

    @Test("Execute STT + LLM pipeline")
    func sttAndLLM() async throws {
        let mockSTT = MockSTTAdapter()
        mockSTT.transcribeResult = "我觉得还行"

        let mockLLM = MockLLMAdapter()
        mockLLM.completeResult = "我认为可以"

        let engine = PipelineEngine()
        let audioStream = AsyncStream<Data> { $0.finish() }

        let steps = [
            PipelineStep(type: .stt, provider: "mock-stt", lang: "zh"),
            PipelineStep(type: .llm, provider: "mock-llm", prompt: "润色：{{input}}")
        ]

        var states: [PipelineState] = []
        for try await state in await engine.execute(
            steps: steps,
            audioStream: audioStream,
            getSTT: { _ in mockSTT },
            getLLM: { _ in mockLLM }
        ) {
            states.append(state)
        }

        let lastState = states.last!
        if case .done(let result, let source) = lastState {
            #expect(result == "我认为可以")
            #expect(source == "我觉得还行")
        } else {
            #expect(Bool(false), "Expected .done state")
        }
    }

    @Test("Input template replacement works")
    func templateReplacement() {
        let result = PipelineEngine.resolveTemplate("Translate: {{input}}", input: "你好")
        #expect(result == "Translate: 你好")
    }
}
```

- [ ] **Step 2: Run tests to verify failure**

Expected: FAIL — `PipelineEngine` not defined

- [ ] **Step 3: Implement PipelineEngine**

```swift
// Verbo/Core/PipelineEngine.swift
import Foundation

actor PipelineEngine {
    static func resolveTemplate(_ template: String, input: String) -> String {
        template.replacingOccurrences(of: "{{input}}", with: input)
    }

    func execute(
        steps: [PipelineStep],
        audioStream: AsyncStream<Data>,
        getSTT: @Sendable (String) -> STTAdapter?,
        getLLM: @Sendable (String) -> LLMAdapter?
    ) -> AsyncThrowingStream<PipelineState, Error> {
        let resolvedSteps = steps

        return AsyncThrowingStream { continuation in
            Task {
                var currentInput = ""
                var sttSource: String?

                for step in resolvedSteps {
                    switch step.type {
                    case .stt:
                        guard let adapter = getSTT(step.provider) else {
                            continuation.yield(.error(message: "STT provider '\(step.provider)' not found"))
                            continuation.finish()
                            return
                        }

                        continuation.yield(.transcribing(partial: ""))

                        let lang = step.lang ?? "zh"
                        if adapter.supportsStreaming {
                            var lastText = ""
                            for try await partial in adapter.transcribeStream(audioStream: audioStream, lang: lang) {
                                lastText = partial
                                continuation.yield(.transcribing(partial: partial))
                            }
                            currentInput = lastText
                        } else {
                            // Collect all audio first
                            var allAudio = Data()
                            for await chunk in audioStream {
                                allAudio.append(chunk)
                            }
                            currentInput = try await adapter.transcribe(audio: allAudio, lang: lang)
                        }
                        sttSource = currentInput

                    case .llm:
                        guard let adapter = getLLM(step.provider) else {
                            continuation.yield(.error(message: "LLM provider '\(step.provider)' not found"))
                            continuation.finish()
                            return
                        }

                        let prompt = Self.resolveTemplate(step.prompt ?? "{{input}}", input: currentInput)
                        continuation.yield(.processing(source: currentInput, partial: ""))

                        var lastText = ""
                        for try await partial in adapter.completeStream(prompt: prompt) {
                            lastText = partial
                            continuation.yield(.processing(source: sttSource ?? currentInput, partial: partial))
                        }
                        currentInput = lastText
                    }
                }

                continuation.yield(.done(result: currentInput, source: sttSource))
                continuation.finish()
            }
        }
    }
}
```

- [ ] **Step 4: Run tests**

```bash
cd Verbo && xcodegen generate && xcodebuild test -project Verbo.xcodeproj -scheme VerboTests 2>&1 | grep -E "(Test Suite|passed|failed)"
```

Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add Verbo/Verbo/Core/PipelineEngine.swift Verbo/VerboTests/PipelineEngineTests.swift
git commit -m "feat: add PipelineEngine actor with sequential step execution"
```

---

## Task 11: HotkeyManager

**Files:**
- Create: `Verbo/Verbo/Core/HotkeyManager.swift`

No unit tests — global event monitoring requires accessibility permissions and can only be verified at runtime.

- [ ] **Step 1: Implement HotkeyManager**

```swift
// Verbo/Core/HotkeyManager.swift
import AppKit
import Carbon.HIToolbox

@Observable
@MainActor
final class HotkeyManager {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var bindings: [HotkeyBinding] = []

    struct HotkeyBinding {
        let id: String
        let keyCode: UInt16
        let modifiers: NSEvent.ModifierFlags
        let onPress: @MainActor () -> Void
        let onRelease: (@MainActor () -> Void)?
    }

    func register(
        id: String,
        shortcut: String,
        onPress: @escaping @MainActor () -> Void,
        onRelease: (@MainActor () -> Void)? = nil
    ) {
        guard let parsed = Self.parseShortcut(shortcut) else {
            print("[HotkeyManager] Invalid shortcut: \(shortcut)")
            return
        }
        let binding = HotkeyBinding(
            id: id,
            keyCode: parsed.keyCode,
            modifiers: parsed.modifiers,
            onPress: onPress,
            onRelease: onRelease
        )
        bindings.removeAll { $0.id == id }
        bindings.append(binding)
    }

    func unregister(id: String) {
        bindings.removeAll { $0.id == id }
    }

    func startListening() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            Task { @MainActor in
                self?.handleEvent(event)
            }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            Task { @MainActor in
                self?.handleEvent(event)
            }
            return event
        }
    }

    func stopListening() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }

    private func handleEvent(_ event: NSEvent) {
        for binding in bindings {
            let modMatch = event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(binding.modifiers)
            let keyMatch = event.keyCode == binding.keyCode
            guard modMatch && keyMatch else { continue }

            if event.type == .keyDown && !event.isARepeat {
                binding.onPress()
            } else if event.type == .keyUp {
                binding.onRelease?()
            }
        }
    }

    // MARK: - Shortcut Parsing

    static func parseShortcut(_ shortcut: String) -> (keyCode: UInt16, modifiers: NSEvent.ModifierFlags)? {
        let parts = shortcut.split(separator: "+").map { String($0).trimmingCharacters(in: .whitespaces) }
        guard let keyPart = parts.last else { return nil }

        var modifiers: NSEvent.ModifierFlags = []
        for part in parts.dropLast() {
            switch part.lowercased() {
            case "cmd", "command", "commandorcontrol":
                modifiers.insert(.command)
            case "ctrl", "control":
                modifiers.insert(.control)
            case "alt", "option":
                modifiers.insert(.option)
            case "shift":
                modifiers.insert(.shift)
            default:
                break
            }
        }

        guard let keyCode = keyCodeForString(keyPart) else { return nil }
        return (keyCode, modifiers)
    }

    private static func keyCodeForString(_ key: String) -> UInt16? {
        let map: [String: UInt16] = [
            "a": 0x00, "b": 0x0B, "c": 0x08, "d": 0x02, "e": 0x0E,
            "f": 0x03, "g": 0x05, "h": 0x04, "i": 0x22, "j": 0x26,
            "k": 0x28, "l": 0x25, "m": 0x2E, "n": 0x2D, "o": 0x1F,
            "p": 0x23, "q": 0x0C, "r": 0x0F, "s": 0x01, "t": 0x11,
            "u": 0x20, "v": 0x09, "w": 0x0D, "x": 0x07, "y": 0x10,
            "z": 0x06, "space": 0x31, "return": 0x24, "escape": 0x35,
            "tab": 0x30, "delete": 0x33,
        ]
        return map[key.lowercased()]
    }
}
```

- [ ] **Step 2: Verify build**

```bash
cd Verbo && xcodegen generate && xcodebuild -project Verbo.xcodeproj -scheme Verbo -configuration Debug build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Verbo/Verbo/Core/HotkeyManager.swift
git commit -m "feat: add HotkeyManager with global event monitoring"
```

---

## Task 12: FloatingPanel (NSPanel subclass)

**Files:**
- Create: `Verbo/Verbo/Views/Floating/FloatingPanel.swift`

- [ ] **Step 1: Implement FloatingPanel**

```swift
// Verbo/Views/Floating/FloatingPanel.swift
import AppKit
import SwiftUI

final class FloatingPanel: NSPanel {
    init(contentView: NSView) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 40),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )

        self.level = .floating
        self.isMovableByWindowBackground = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        self.contentView = contentView
        self.isReleasedWhenClosed = false

        // Accept mouse events without activating the app
        self.acceptsMouseMovedEvents = true
        self.hidesOnDeactivate = false
    }

    // Accept first mouse click without requiring app activation
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
```

- [ ] **Step 2: Verify build**

```bash
cd Verbo && xcodegen generate && xcodebuild -project Verbo.xcodeproj -scheme Verbo -configuration Debug build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Verbo/Verbo/Views/Floating/FloatingPanel.swift
git commit -m "feat: add FloatingPanel NSPanel subclass"
```

---

## Task 13: FloatingViewModel

**Files:**
- Create: `Verbo/Verbo/ViewModels/FloatingViewModel.swift`

- [ ] **Step 1: Implement FloatingViewModel**

```swift
// Verbo/ViewModels/FloatingViewModel.swift
import Foundation
import Observation
import SwiftUI

@Observable
@MainActor
final class FloatingViewModel {
    // MARK: - State
    var pipelineState: PipelineState = .idle
    var currentSceneName: String = "Verbo"
    var currentHotkeyHint: String = "Alt+D"
    var recordingDuration: TimeInterval = 0
    var audioLevels: [Float] = Array(repeating: 0, count: 5)
    var isExpanded: Bool = false
    var lastResult: String?
    var lastSource: String?

    // MARK: - Dependencies
    private let pipelineEngine = PipelineEngine()
    private let audioRecorder = AudioRecorder()
    private let textOutputService = TextOutputService()
    var configManager: ConfigManager?
    var historyManager: HistoryManager?

    private var recordingTimer: Timer?
    private var collapseTask: Task<Void, Never>?
    private var pipelineTask: Task<Void, Never>?

    // MARK: - Computed

    var isIdle: Bool { pipelineState.isIdle }
    var isRecording: Bool { pipelineState.isRecording }

    var pillDotColor: Color {
        switch pipelineState {
        case .idle: return DesignTokens.Colors.stoneGray
        case .recording: return DesignTokens.Colors.terracotta
        case .transcribing: return DesignTokens.Colors.coral
        case .processing: return DesignTokens.Colors.coral
        case .done: return Color.green
        case .error: return DesignTokens.Colors.errorCrimson
        }
    }

    var shouldShowBubble: Bool {
        switch pipelineState {
        case .idle, .recording: return isExpanded && lastResult != nil
        case .transcribing, .processing, .done, .error: return true
        }
    }

    // MARK: - Actions

    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    func startRecording() {
        guard isIdle || (pipelineState.isDone) else { return }
        collapseTask?.cancel()
        isExpanded = false
        lastResult = nil
        lastSource = nil
        pipelineState = .recording
        recordingDuration = 0

        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.recordingDuration += 0.1
            }
        }

        Task {
            let audioStream = await audioRecorder.start()
            await runPipeline(audioStream: audioStream)
        }
    }

    func stopRecording() {
        guard isRecording else { return }
        recordingTimer?.invalidate()
        recordingTimer = nil

        Task {
            _ = await audioRecorder.stop()
        }
    }

    private func runPipeline(audioStream: AsyncStream<Data>) async {
        guard let config = configManager?.config else { return }
        guard let scene = configManager?.defaultScene() else { return }

        let sttConfigs = config.providers.stt
        let llmConfigs = config.providers.llm

        let getSTT: @Sendable (String) -> STTAdapter? = { name in
            guard let sttConfig = sttConfigs[name] else { return nil }
            return IFlytekSTTAdapter(
                appId: sttConfig.appId,
                apiKey: sttConfig.apiKey,
                apiSecret: sttConfig.apiSecret
            )
        }

        let getLLM: @Sendable (String) -> LLMAdapter? = { name in
            guard let llmConfig = llmConfigs[name] else { return nil }
            return OpenAILLMAdapter(
                apiKey: llmConfig.apiKey,
                model: llmConfig.model,
                baseUrl: llmConfig.baseUrl
            )
        }

        pipelineTask = Task {
            do {
                for try await state in await pipelineEngine.execute(
                    steps: scene.pipeline,
                    audioStream: audioStream,
                    getSTT: getSTT,
                    getLLM: getLLM
                ) {
                    pipelineState = state

                    if case .done(let result, let source) = state {
                        lastResult = result
                        lastSource = source
                        isExpanded = true

                        // Output text
                        let outputMode = scene.output
                        let status = await textOutputService.output(text: result, mode: outputMode)

                        // Save to history
                        let record = HistoryRecord(
                            sceneId: scene.id,
                            sceneName: scene.name,
                            originalText: source ?? result,
                            finalText: result,
                            outputStatus: status,
                            pipelineSteps: scene.pipeline.map { "\($0.type.rawValue):\($0.provider)" }
                        )
                        historyManager?.add(record)
                        try? historyManager?.save()

                        // Schedule auto-collapse
                        scheduleCollapse()
                    }
                }
            } catch {
                pipelineState = .error(message: error.localizedDescription)
            }
        }
    }

    private func scheduleCollapse() {
        let delay = configManager?.config.general.autoCollapseDelay ?? 1.5
        guard delay > 0 else { return }

        collapseTask = Task {
            try? await Task.sleep(for: .seconds(delay))
            if !Task.isCancelled {
                pipelineState = .idle
                isExpanded = false
            }
        }
    }

    func pillTapped() {
        switch pipelineState {
        case .idle:
            if lastResult != nil {
                isExpanded.toggle()
            } else {
                startRecording()
            }
        case .recording:
            stopRecording()
        case .done:
            collapseTask?.cancel()
            isExpanded.toggle()
        default:
            break
        }
    }

    func retry() {
        pipelineState = .idle
        startRecording()
    }

    // MARK: - Audio Level Polling

    func pollAudioLevels() async {
        audioLevels = await audioRecorder.audioLevels
    }

    // MARK: - Timer Display

    var timerText: String {
        let minutes = Int(recordingDuration) / 60
        let seconds = Int(recordingDuration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
```

- [ ] **Step 2: Verify build**

```bash
cd Verbo && xcodegen generate && xcodebuild -project Verbo.xcodeproj -scheme Verbo -configuration Debug build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Verbo/Verbo/ViewModels/FloatingViewModel.swift
git commit -m "feat: add FloatingViewModel with pipeline orchestration"
```

---

## Task 14: Floating Window Views (Pill, Bubble, Waveform)

**Files:**
- Create: `Verbo/Verbo/Views/Floating/PillView.swift`
- Create: `Verbo/Verbo/Views/Floating/WaveformView.swift`
- Create: `Verbo/Verbo/Views/Floating/BubbleView.swift`
- Create: `Verbo/Verbo/Views/Floating/FloatingPanelView.swift`

- [ ] **Step 1: Implement WaveformView**

```swift
// Verbo/Views/Floating/WaveformView.swift
import SwiftUI

struct WaveformView: View {
    let levels: [Float]
    let barCount: Int = 5
    let isActive: Bool

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(DesignTokens.Colors.terracotta)
                    .frame(width: 3, height: barHeight(for: index))
                    .animation(
                        isActive ? .easeInOut(duration: 0.15) : .default,
                        value: levels
                    )
            }
        }
        .frame(height: 16)
    }

    private func barHeight(for index: Int) -> CGFloat {
        let level = index < levels.count ? CGFloat(levels[index]) : 0
        let minHeight: CGFloat = 4
        let maxHeight: CGFloat = 16
        return minHeight + level * (maxHeight - minHeight)
    }
}
```

- [ ] **Step 2: Implement PillView**

```swift
// Verbo/Views/Floating/PillView.swift
import SwiftUI

struct PillView: View {
    let state: PipelineState
    let sceneName: String
    let hotkeyHint: String
    let timerText: String
    let audioLevels: [Float]
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            // Status dot
            Circle()
                .fill(dotColor)
                .frame(width: DesignTokens.Pill.dotSize, height: DesignTokens.Pill.dotSize)
                .overlay(
                    Circle()
                        .fill(dotColor.opacity(0.4))
                        .frame(width: DesignTokens.Pill.dotSize + 4, height: DesignTokens.Pill.dotSize + 4)
                        .opacity(state.isRecording ? 1 : 0)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: state.isRecording)
                )

            // Content based on state
            switch state {
            case .idle:
                Text(sceneName)
                    .font(DesignTokens.Typography.pillText)
                    .foregroundStyle(DesignTokens.Colors.charcoalWarm)
                Spacer()
                Text(hotkeyHint)
                    .font(DesignTokens.Typography.pillHotkey)
                    .foregroundStyle(DesignTokens.Colors.stoneGray)

            case .recording:
                WaveformView(levels: audioLevels, isActive: true)
                Spacer()
                Text(timerText)
                    .font(DesignTokens.Typography.pillTimer)
                    .foregroundStyle(DesignTokens.Colors.charcoalWarm)

            case .transcribing:
                Text(String(localized: "pill.recognizing"))
                    .font(DesignTokens.Typography.pillText)
                    .foregroundStyle(DesignTokens.Colors.coral)

            case .processing:
                Text(String(localized: "pill.processing"))
                    .font(DesignTokens.Typography.pillText)
                    .foregroundStyle(DesignTokens.Colors.coral)
                shimmerDots

            case .done:
                Text(String(localized: "pill.done"))
                    .font(DesignTokens.Typography.pillText)
                    .foregroundStyle(Color.green.opacity(0.8))

            case .error:
                Text(String(localized: "pill.error"))
                    .font(DesignTokens.Typography.pillText)
                    .foregroundStyle(DesignTokens.Colors.errorCrimson)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .frame(minWidth: DesignTokens.Pill.minWidth, height: DesignTokens.Pill.height)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.pill)
                .fill(DesignTokens.Colors.ivory)
                .shadow(color: DesignTokens.Shadows.ring, radius: 0, x: 0, y: 0)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.pill)
                        .stroke(DesignTokens.Colors.borderCream, lineWidth: 1)
                )
        )
        .onTapGesture(perform: onTap)
        .contentShape(Rectangle())
    }

    private var dotColor: Color {
        switch state {
        case .idle: return DesignTokens.Colors.stoneGray
        case .recording: return DesignTokens.Colors.terracotta
        case .transcribing, .processing: return DesignTokens.Colors.coral
        case .done: return Color.green
        case .error: return DesignTokens.Colors.errorCrimson
        }
    }

    @State private var shimmerPhase = false

    private var shimmerDots: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(DesignTokens.Colors.coral)
                    .frame(width: 4, height: 4)
                    .offset(y: shimmerPhase ? -2 : 2)
                    .animation(
                        .easeInOut(duration: 0.4)
                        .repeatForever()
                        .delay(Double(i) * 0.15),
                        value: shimmerPhase
                    )
            }
        }
        .onAppear { shimmerPhase = true }
    }
}
```

- [ ] **Step 3: Implement BubbleView**

```swift
// Verbo/Views/Floating/BubbleView.swift
import SwiftUI

struct BubbleView: View {
    let state: PipelineState
    let lastResult: String?
    let lastSource: String?
    let onCopy: () -> Void
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            switch state {
            case .transcribing(let partial):
                if !partial.isEmpty {
                    Text(partial)
                        .font(DesignTokens.Typography.bubbleText)
                        .foregroundStyle(DesignTokens.Colors.charcoalWarm)
                        .animation(.easeIn(duration: 0.1), value: partial)
                }

            case .processing(let source, let partial):
                // Source text with strikethrough
                Text(source)
                    .font(DesignTokens.Typography.bubbleText)
                    .foregroundStyle(DesignTokens.Colors.stoneGray)
                    .strikethrough()
                    .opacity(0.6)

                if !partial.isEmpty {
                    Text(partial)
                        .font(DesignTokens.Typography.bubbleText)
                        .foregroundStyle(DesignTokens.Colors.charcoalWarm)
                }

            case .done(let result, _):
                Text(result)
                    .font(DesignTokens.Typography.bubbleText)
                    .foregroundStyle(DesignTokens.Colors.charcoalWarm)
                    .textSelection(.enabled)

                HStack {
                    Text(String(localized: "bubble.inserted"))
                        .font(DesignTokens.Typography.bubbleStatus)
                        .foregroundStyle(Color.green.opacity(0.7))

                    Spacer()

                    Button(action: onCopy) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(DesignTokens.Colors.stoneGray)
                }

            case .error(let message):
                Text(message)
                    .font(DesignTokens.Typography.bubbleText)
                    .foregroundStyle(DesignTokens.Colors.errorCrimson)

                Button(action: onRetry) {
                    Text(String(localized: "bubble.retry"))
                        .font(DesignTokens.Typography.bubbleStatus)
                }
                .buttonStyle(.plain)
                .foregroundStyle(DesignTokens.Colors.terracotta)

            default:
                if let result = lastResult {
                    Text(result)
                        .font(DesignTokens.Typography.bubbleText)
                        .foregroundStyle(DesignTokens.Colors.charcoalWarm)
                        .textSelection(.enabled)
                }
            }
        }
        .padding(DesignTokens.Spacing.md)
        .frame(minWidth: 200, maxWidth: 360, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.bubble)
                .fill(DesignTokens.Colors.ivory)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.bubble)
                        .stroke(DesignTokens.Colors.borderCream, lineWidth: 1)
                )
        )
    }
}
```

- [ ] **Step 4: Implement FloatingPanelView**

```swift
// Verbo/Views/Floating/FloatingPanelView.swift
import SwiftUI

struct FloatingPanelView: View {
    @Bindable var viewModel: FloatingViewModel

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            if viewModel.shouldShowBubble {
                BubbleView(
                    state: viewModel.pipelineState,
                    lastResult: viewModel.lastResult,
                    lastSource: viewModel.lastSource,
                    onCopy: {
                        if let text = viewModel.lastResult {
                            TextOutputService().writeToClipboard(text)
                        }
                    },
                    onRetry: {
                        viewModel.retry()
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            PillView(
                state: viewModel.pipelineState,
                sceneName: viewModel.currentSceneName,
                hotkeyHint: viewModel.currentHotkeyHint,
                timerText: viewModel.timerText,
                audioLevels: viewModel.audioLevels,
                onTap: { viewModel.pillTapped() }
            )
        }
        .padding(DesignTokens.Spacing.sm)
        .animation(DesignTokens.Animation.expand, value: viewModel.shouldShowBubble)
        .animation(DesignTokens.Animation.standard, value: viewModel.pipelineState)
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: PanelSizeKey.self, value: geo.size)
            }
        )
        .onPreferenceChange(PanelSizeKey.self) { size in
            NotificationCenter.default.post(
                name: .floatingPanelSizeChanged,
                object: nil,
                userInfo: ["size": size]
            )
        }
        .task {
            // Poll audio levels while recording
            while !Task.isCancelled {
                if viewModel.isRecording {
                    await viewModel.pollAudioLevels()
                }
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
    }
}

private struct PanelSizeKey: PreferenceKey {
    static let defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

extension Notification.Name {
    static let floatingPanelSizeChanged = Notification.Name("floatingPanelSizeChanged")
}
```

- [ ] **Step 5: Verify build**

```bash
cd Verbo && xcodegen generate && xcodebuild -project Verbo.xcodeproj -scheme Verbo -configuration Debug build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

- [ ] **Step 6: Commit**

```bash
git add Verbo/Verbo/Views/Floating/
git commit -m "feat: add floating window views (Pill, Bubble, Waveform, Panel)"
```

---

## Task 15: Settings Window

**Files:**
- Create: `Verbo/Verbo/Views/Settings/SettingsWindow.swift`
- Create: `Verbo/Verbo/Views/Settings/SettingsView.swift`
- Create: `Verbo/Verbo/Views/Settings/ScenesSettingsView.swift`
- Create: `Verbo/Verbo/Views/Settings/ProvidersSettingsView.swift`
- Create: `Verbo/Verbo/Views/Settings/GeneralSettingsView.swift`
- Create: `Verbo/Verbo/Views/Settings/AboutView.swift`
- Create: `Verbo/Verbo/ViewModels/SettingsViewModel.swift`

- [ ] **Step 1: Implement SettingsViewModel**

```swift
// Verbo/ViewModels/SettingsViewModel.swift
import Foundation
import Observation

@Observable
@MainActor
final class SettingsViewModel {
    var configManager: ConfigManager

    // Editing state
    var editingScene: Scene?
    var isEditingScene = false

    init(configManager: ConfigManager) {
        self.configManager = configManager
    }

    var config: AppConfig { configManager.config }

    // MARK: - Scene Operations

    func selectSceneAsDefault(_ sceneId: String) {
        var newConfig = config
        newConfig.defaultScene = sceneId
        configManager.update(newConfig)
        saveConfig()
    }

    func startEditingScene(_ scene: Scene) {
        editingScene = scene
        isEditingScene = true
    }

    func saveEditingScene() {
        guard let scene = editingScene else { return }
        var newConfig = config
        if let index = newConfig.scenes.firstIndex(where: { $0.id == scene.id }) {
            newConfig.scenes[index] = scene
        }
        configManager.update(newConfig)
        saveConfig()
        isEditingScene = false
        editingScene = nil
    }

    func cancelEditingScene() {
        isEditingScene = false
        editingScene = nil
    }

    func deleteScene(_ sceneId: String) {
        var newConfig = config
        newConfig.scenes.removeAll { $0.id == sceneId }
        if newConfig.defaultScene == sceneId {
            newConfig.defaultScene = newConfig.scenes.first?.id ?? ""
        }
        configManager.update(newConfig)
        saveConfig()
    }

    // MARK: - Provider Operations

    func updateSTTProvider(_ name: String, config: STTProviderConfig) {
        var newConfig = self.config
        newConfig.providers.stt[name] = config
        configManager.update(newConfig)
        saveConfig()
    }

    func updateLLMProvider(_ name: String, config: LLMProviderConfig) {
        var newConfig = self.config
        newConfig.providers.llm[name] = config
        configManager.update(newConfig)
        saveConfig()
    }

    // MARK: - General Operations

    func updateGeneral(_ general: GeneralConfig) {
        var newConfig = config
        newConfig.general = general
        configManager.update(newConfig)
        saveConfig()
    }

    private func saveConfig() {
        try? configManager.save()
    }
}
```

- [ ] **Step 2: Implement SettingsWindow**

```swift
// Verbo/Views/Settings/SettingsWindow.swift
import AppKit
import SwiftUI

final class SettingsWindow {
    private var window: NSWindow?

    func show(viewModel: SettingsViewModel) {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView(viewModel: viewModel)
        let hostingView = NSHostingView(rootView: settingsView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 450),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = String(localized: "settings.title")
        window.contentView = hostingView
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }
}
```

- [ ] **Step 3: Implement SettingsView with tab navigation**

```swift
// Verbo/Views/Settings/SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    enum Tab: String, CaseIterable {
        case scenes, providers, general, about

        var label: String {
            switch self {
            case .scenes: return String(localized: "settings.tab.scenes")
            case .providers: return String(localized: "settings.tab.providers")
            case .general: return String(localized: "settings.tab.general")
            case .about: return String(localized: "settings.tab.about")
            }
        }

        var icon: String {
            switch self {
            case .scenes: return "text.bubble"
            case .providers: return "cloud"
            case .general: return "gear"
            case .about: return "info.circle"
            }
        }
    }

    @State private var selectedTab: Tab = .scenes

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(Tab.allCases, id: \.self) { tab in
                tabContent(for: tab)
                    .tabItem {
                        Label(tab.label, systemImage: tab.icon)
                    }
                    .tag(tab)
            }
        }
        .frame(minWidth: 550, minHeight: 400)
    }

    @ViewBuilder
    private func tabContent(for tab: Tab) -> some View {
        switch tab {
        case .scenes:
            ScenesSettingsView(viewModel: viewModel)
        case .providers:
            ProvidersSettingsView(viewModel: viewModel)
        case .general:
            GeneralSettingsView(viewModel: viewModel)
        case .about:
            AboutView()
        }
    }
}
```

- [ ] **Step 4: Implement ScenesSettingsView**

```swift
// Verbo/Views/Settings/ScenesSettingsView.swift
import SwiftUI

struct ScenesSettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if viewModel.isEditingScene, let scene = viewModel.editingScene {
                sceneEditor(scene: Binding(
                    get: { viewModel.editingScene ?? scene },
                    set: { viewModel.editingScene = $0 }
                ))
            } else {
                sceneList
            }
        }
        .padding()
    }

    private var sceneList: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            ForEach(viewModel.config.scenes) { scene in
                sceneRow(scene)
            }
        }
    }

    private func sceneRow(_ scene: Scene) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(scene.name)
                        .font(DesignTokens.Typography.settingsTitle)
                    if scene.id == viewModel.config.defaultScene {
                        Text(String(localized: "scenes.default"))
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(DesignTokens.Colors.warmSand)
                            .clipShape(Capsule())
                    }
                }
                Text(scene.pipeline.map { $0.type.rawValue.uppercased() }.joined(separator: " → "))
                    .font(DesignTokens.Typography.settingsCaption)
                    .foregroundStyle(DesignTokens.Colors.stoneGray)
            }

            Spacer()

            if let hotkey = scene.hotkey.toggleRecord {
                Text(hotkey)
                    .font(DesignTokens.Typography.settingsCaption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(DesignTokens.Colors.warmSand)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            Button(String(localized: "scenes.edit")) {
                viewModel.startEditingScene(scene)
            }
            .buttonStyle(.plain)
            .foregroundStyle(DesignTokens.Colors.terracotta)
        }
        .padding(DesignTokens.Spacing.md)
        .background(DesignTokens.Colors.ivory)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.medium)
                .stroke(DesignTokens.Colors.borderCream, lineWidth: 1)
        )
    }

    private func sceneEditor(scene: Binding<Scene>) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                TextField(String(localized: "scenes.name"), text: scene.name)
                    .textFieldStyle(.roundedBorder)

                Text(String(localized: "scenes.pipeline"))
                    .font(DesignTokens.Typography.settingsTitle)

                ForEach(Array(scene.wrappedValue.pipeline.enumerated()), id: \.offset) { index, step in
                    stepCard(step: step, index: index, scene: scene)
                }

                // Hotkey bindings
                Text(String(localized: "scenes.hotkeys"))
                    .font(DesignTokens.Typography.settingsTitle)

                HStack {
                    Text(String(localized: "scenes.toggle"))
                    TextField("Alt+D", text: Binding(
                        get: { scene.wrappedValue.hotkey.toggleRecord ?? "" },
                        set: { scene.wrappedValue.hotkey.toggleRecord = $0.isEmpty ? nil : $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 150)
                }

                HStack {
                    Text(String(localized: "scenes.pushToTalk"))
                    TextField("", text: Binding(
                        get: { scene.wrappedValue.hotkey.pushToTalk ?? "" },
                        set: { scene.wrappedValue.hotkey.pushToTalk = $0.isEmpty ? nil : $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 150)
                }

                // Save / Cancel
                HStack {
                    Spacer()
                    Button(String(localized: "common.cancel")) {
                        viewModel.cancelEditingScene()
                    }
                    Button(String(localized: "common.save")) {
                        viewModel.saveEditingScene()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(DesignTokens.Colors.terracotta)
                }
            }
        }
    }

    private func stepCard(step: PipelineStep, index: Int, scene: Binding<Scene>) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack {
                Text("Step \(index + 1): \(step.type.rawValue.uppercased())")
                    .font(DesignTokens.Typography.settingsTitle)
                Spacer()
            }

            if step.type == .llm, let prompt = step.prompt {
                TextEditor(text: Binding(
                    get: { scene.wrappedValue.pipeline[index].prompt ?? "" },
                    set: { scene.wrappedValue.pipeline[index].prompt = $0 }
                ))
                .font(DesignTokens.Typography.settingsBody)
                .frame(height: 80)
                .border(DesignTokens.Colors.borderCream)
            }
        }
        .padding(DesignTokens.Spacing.md)
        .background(DesignTokens.Colors.parchment)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.medium))
    }
}
```

- [ ] **Step 5: Implement ProvidersSettingsView**

```swift
// Verbo/Views/Settings/ProvidersSettingsView.swift
import SwiftUI

struct ProvidersSettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                // STT Providers
                Text(String(localized: "providers.stt"))
                    .font(DesignTokens.Typography.settingsTitle)

                ForEach(Array(viewModel.config.providers.stt.keys.sorted()), id: \.self) { name in
                    sttProviderCard(name: name)
                }

                Divider()

                // LLM Providers
                Text(String(localized: "providers.llm"))
                    .font(DesignTokens.Typography.settingsTitle)

                ForEach(Array(viewModel.config.providers.llm.keys.sorted()), id: \.self) { name in
                    llmProviderCard(name: name)
                }
            }
            .padding()
        }
    }

    private func sttProviderCard(name: String) -> some View {
        let config = viewModel.config.providers.stt[name] ?? STTProviderConfig()
        return VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text(name.capitalized)
                .font(DesignTokens.Typography.settingsTitle)

            LabeledContent("App ID") {
                TextField("", text: binding(for: name, keyPath: \.appId))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 250)
            }
            LabeledContent("API Key") {
                SecureField("", text: binding(for: name, keyPath: \.apiKey))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 250)
            }
            LabeledContent("API Secret") {
                SecureField("", text: binding(for: name, keyPath: \.apiSecret))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 250)
            }
        }
        .padding(DesignTokens.Spacing.md)
        .background(DesignTokens.Colors.ivory)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.medium)
                .stroke(DesignTokens.Colors.borderCream, lineWidth: 1)
        )
    }

    private func binding(for name: String, keyPath: WritableKeyPath<STTProviderConfig, String>) -> Binding<String> {
        Binding(
            get: { viewModel.config.providers.stt[name]?[keyPath: keyPath] ?? "" },
            set: { newValue in
                var config = viewModel.config.providers.stt[name] ?? STTProviderConfig()
                config[keyPath: keyPath] = newValue
                viewModel.updateSTTProvider(name, config: config)
            }
        )
    }

    private func llmProviderCard(name: String) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text(name.capitalized)
                .font(DesignTokens.Typography.settingsTitle)

            LabeledContent("API Key") {
                SecureField("", text: Binding(
                    get: { viewModel.config.providers.llm[name]?.apiKey ?? "" },
                    set: {
                        var config = viewModel.config.providers.llm[name] ?? LLMProviderConfig()
                        config.apiKey = $0
                        viewModel.updateLLMProvider(name, config: config)
                    }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(width: 250)
            }
            LabeledContent("Model") {
                TextField("gpt-4o-mini", text: Binding(
                    get: { viewModel.config.providers.llm[name]?.model ?? "gpt-4o-mini" },
                    set: {
                        var config = viewModel.config.providers.llm[name] ?? LLMProviderConfig()
                        config.model = $0
                        viewModel.updateLLMProvider(name, config: config)
                    }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(width: 250)
            }
            LabeledContent("Base URL") {
                TextField("https://api.openai.com/v1", text: Binding(
                    get: { viewModel.config.providers.llm[name]?.baseUrl ?? "https://api.openai.com/v1" },
                    set: {
                        var config = viewModel.config.providers.llm[name] ?? LLMProviderConfig()
                        config.baseUrl = $0
                        viewModel.updateLLMProvider(name, config: config)
                    }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(width: 250)
            }
        }
        .padding(DesignTokens.Spacing.md)
        .background(DesignTokens.Colors.ivory)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.medium)
                .stroke(DesignTokens.Colors.borderCream, lineWidth: 1)
        )
    }
}
```

- [ ] **Step 6: Implement GeneralSettingsView and AboutView**

```swift
// Verbo/Views/Settings/GeneralSettingsView.swift
import SwiftUI

struct GeneralSettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section(String(localized: "general.hotkeys")) {
                LabeledContent(String(localized: "general.toggleRecord")) {
                    TextField("", text: Binding(
                        get: { viewModel.config.globalHotkey.toggleRecord },
                        set: {
                            var newConfig = viewModel.config
                            newConfig.globalHotkey.toggleRecord = $0
                            viewModel.configManager.update(newConfig)
                        }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
                }
            }

            Section(String(localized: "general.behavior")) {
                Picker(String(localized: "general.outputMode"), selection: Binding(
                    get: { viewModel.config.general.outputMode },
                    set: {
                        var general = viewModel.config.general
                        general.outputMode = $0
                        viewModel.updateGeneral(general)
                    }
                )) {
                    Text(String(localized: "general.simulate")).tag(OutputMode.simulate)
                    Text(String(localized: "general.clipboard")).tag(OutputMode.clipboard)
                }

                Picker(String(localized: "general.autoCollapse"), selection: Binding(
                    get: { viewModel.config.general.autoCollapseDelay },
                    set: {
                        var general = viewModel.config.general
                        general.autoCollapseDelay = $0
                        viewModel.updateGeneral(general)
                    }
                )) {
                    Text("1.5s").tag(1.5)
                    Text("3s").tag(3.0)
                    Text("5s").tag(5.0)
                    Text(String(localized: "general.never")).tag(0.0)
                }
            }

            Section(String(localized: "general.language")) {
                Picker(String(localized: "general.uiLanguage"), selection: Binding(
                    get: { viewModel.config.general.uiLanguage },
                    set: {
                        var general = viewModel.config.general
                        general.uiLanguage = $0
                        viewModel.updateGeneral(general)
                    }
                )) {
                    Text(String(localized: "general.followSystem")).tag(UILanguage.system)
                    Text("中文").tag(UILanguage.zh)
                    Text("English").tag(UILanguage.en)
                }
            }

            Section(String(localized: "general.data")) {
                Picker(String(localized: "general.retention"), selection: Binding(
                    get: { viewModel.config.general.historyRetentionDays ?? 0 },
                    set: {
                        var general = viewModel.config.general
                        general.historyRetentionDays = $0 == 0 ? nil : $0
                        viewModel.updateGeneral(general)
                    }
                )) {
                    Text(String(localized: "general.30days")).tag(30)
                    Text(String(localized: "general.90days")).tag(90)
                    Text(String(localized: "general.forever")).tag(0)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
```

```swift
// Verbo/Views/Settings/AboutView.swift
import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            Spacer()

            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(DesignTokens.Colors.terracotta)

            Text("Verbo")
                .font(.system(size: 28, weight: .medium, design: .serif))

            Text("v0.1.0")
                .font(DesignTokens.Typography.settingsCaption)
                .foregroundStyle(DesignTokens.Colors.stoneGray)

            Text(String(localized: "about.description"))
                .font(DesignTokens.Typography.settingsBody)
                .foregroundStyle(DesignTokens.Colors.oliveGray)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            Spacer()

            Text(String(localized: "about.license"))
                .font(DesignTokens.Typography.settingsCaption)
                .foregroundStyle(DesignTokens.Colors.stoneGray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
```

- [ ] **Step 7: Verify build**

```bash
cd Verbo && xcodegen generate && xcodebuild -project Verbo.xcodeproj -scheme Verbo -configuration Debug build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

- [ ] **Step 8: Commit**

```bash
git add Verbo/Verbo/Views/Settings/ Verbo/Verbo/ViewModels/SettingsViewModel.swift
git commit -m "feat: add settings window with scenes, providers, general, and about"
```

---

## Task 16: History Window

**Files:**
- Create: `Verbo/Verbo/Views/History/HistoryWindow.swift`
- Create: `Verbo/Verbo/Views/History/HistoryView.swift`
- Create: `Verbo/Verbo/ViewModels/HistoryViewModel.swift`

- [ ] **Step 1: Implement HistoryViewModel**

```swift
// Verbo/ViewModels/HistoryViewModel.swift
import Foundation
import Observation

@Observable
@MainActor
final class HistoryViewModel {
    var historyManager: HistoryManager
    var searchQuery = ""
    var selectedSceneFilter: String?

    init(historyManager: HistoryManager) {
        self.historyManager = historyManager
    }

    var filteredRecords: [HistoryRecord] {
        var records = historyManager.records

        if let filter = selectedSceneFilter {
            records = records.filter { $0.sceneId == filter }
        }

        if !searchQuery.isEmpty {
            let query = searchQuery.lowercased()
            records = records.filter {
                $0.finalText.lowercased().contains(query) ||
                $0.originalText.lowercased().contains(query)
            }
        }

        return records
    }

    struct DateGroup: Identifiable {
        let id: String
        let label: String
        let records: [HistoryRecord]
    }

    var groupedRecords: [DateGroup] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        var todayRecords: [HistoryRecord] = []
        var yesterdayRecords: [HistoryRecord] = []
        var earlierRecords: [HistoryRecord] = []

        for record in filteredRecords {
            let recordDay = calendar.startOfDay(for: record.timestamp)
            if recordDay == today {
                todayRecords.append(record)
            } else if recordDay == yesterday {
                yesterdayRecords.append(record)
            } else {
                earlierRecords.append(record)
            }
        }

        var groups: [DateGroup] = []
        if !todayRecords.isEmpty {
            groups.append(DateGroup(id: "today", label: String(localized: "history.today"), records: todayRecords))
        }
        if !yesterdayRecords.isEmpty {
            groups.append(DateGroup(id: "yesterday", label: String(localized: "history.yesterday"), records: yesterdayRecords))
        }
        if !earlierRecords.isEmpty {
            groups.append(DateGroup(id: "earlier", label: String(localized: "history.earlier"), records: earlierRecords))
        }
        return groups
    }

    var availableScenes: [String] {
        Array(Set(historyManager.records.map(\.sceneId))).sorted()
    }

    func clearAll() {
        historyManager.clearAll()
        try? historyManager.save()
    }
}
```

- [ ] **Step 2: Implement HistoryWindow**

```swift
// Verbo/Views/History/HistoryWindow.swift
import AppKit
import SwiftUI

final class HistoryWindow {
    private var window: NSWindow?

    func show(viewModel: HistoryViewModel) {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let historyView = HistoryView(viewModel: viewModel)
        let hostingView = NSHostingView(rootView: historyView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = String(localized: "history.title")
        window.contentView = hostingView
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }
}
```

- [ ] **Step 3: Implement HistoryView**

```swift
// Verbo/Views/History/HistoryView.swift
import SwiftUI

struct HistoryView: View {
    @Bindable var viewModel: HistoryViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(DesignTokens.Colors.stoneGray)
                TextField(String(localized: "history.search"), text: $viewModel.searchQuery)
                    .textFieldStyle(.plain)

                if !viewModel.searchQuery.isEmpty {
                    Button(action: { viewModel.searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(DesignTokens.Colors.stoneGray)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(DesignTokens.Spacing.sm)
            .background(DesignTokens.Colors.ivory)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.medium))
            .padding()

            // Filter bar
            HStack {
                Picker(String(localized: "history.filter"), selection: $viewModel.selectedSceneFilter) {
                    Text(String(localized: "history.allScenes")).tag(String?.none)
                    ForEach(viewModel.availableScenes, id: \.self) { scene in
                        Text(scene).tag(String?.some(scene))
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 150)

                Spacer()

                Button(String(localized: "history.clearAll")) {
                    viewModel.clearAll()
                }
                .foregroundStyle(DesignTokens.Colors.errorCrimson)
            }
            .padding(.horizontal)

            Divider()
                .padding(.vertical, DesignTokens.Spacing.sm)

            // Records list
            if viewModel.filteredRecords.isEmpty {
                Spacer()
                Text(String(localized: "history.empty"))
                    .foregroundStyle(DesignTokens.Colors.stoneGray)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                        ForEach(viewModel.groupedRecords) { group in
                            Section {
                                ForEach(group.records) { record in
                                    historyRow(record)
                                    Divider()
                                }
                            } header: {
                                Text(group.label)
                                    .font(DesignTokens.Typography.settingsCaption)
                                    .foregroundStyle(DesignTokens.Colors.stoneGray)
                                    .padding(.horizontal)
                                    .padding(.vertical, DesignTokens.Spacing.xs)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(DesignTokens.Colors.parchment)
                            }
                        }
                    }
                }
            }
        }
        .background(DesignTokens.Colors.parchment)
    }

    @State private var hoveredRecordId: UUID?

    private func historyRow(_ record: HistoryRecord) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(record.finalText)
                    .font(DesignTokens.Typography.settingsBody)
                    .lineLimit(3)

                if record.hasLLMProcessing {
                    DisclosureGroup(String(localized: "history.viewOriginal")) {
                        Text(record.originalText)
                            .font(DesignTokens.Typography.settingsCaption)
                            .foregroundStyle(DesignTokens.Colors.stoneGray)
                    }
                    .font(DesignTokens.Typography.settingsCaption)
                    .foregroundStyle(DesignTokens.Colors.oliveGray)
                }

                HStack(spacing: DesignTokens.Spacing.sm) {
                    Text(record.sceneName)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(DesignTokens.Colors.warmSand)
                        .clipShape(Capsule())

                    statusBadge(record.outputStatus)

                    Text(record.timestamp, style: .time)
                        .font(DesignTokens.Typography.settingsCaption)
                        .foregroundStyle(DesignTokens.Colors.stoneGray)
                }
            }

            Spacer()

            if hoveredRecordId == record.id {
                Button(action: {
                    TextOutputService().writeToClipboard(record.finalText)
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundStyle(DesignTokens.Colors.stoneGray)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .contentShape(Rectangle())
        .onHover { hovering in
            hoveredRecordId = hovering ? record.id : nil
        }
    }

    private func statusBadge(_ status: HistoryRecord.OutputStatus) -> some View {
        HStack(spacing: 2) {
            Circle()
                .fill(statusColor(status))
                .frame(width: 6, height: 6)
            Text(statusText(status))
                .font(.caption2)
                .foregroundStyle(statusColor(status))
        }
    }

    private func statusColor(_ status: HistoryRecord.OutputStatus) -> Color {
        switch status {
        case .inserted: return .green
        case .copied: return DesignTokens.Colors.stoneGray
        case .failed: return DesignTokens.Colors.errorCrimson
        }
    }

    private func statusText(_ status: HistoryRecord.OutputStatus) -> String {
        switch status {
        case .inserted: return String(localized: "history.status.inserted")
        case .copied: return String(localized: "history.status.copied")
        case .failed: return String(localized: "history.status.failed")
        }
    }
}
```

- [ ] **Step 4: Verify build**

```bash
cd Verbo && xcodegen generate && xcodebuild -project Verbo.xcodeproj -scheme Verbo -configuration Debug build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add Verbo/Verbo/Views/History/ Verbo/Verbo/ViewModels/HistoryViewModel.swift
git commit -m "feat: add history window with search, filter, and date grouping"
```

---

## Task 17: AppDelegate + System Tray + VerboApp Entry Point

**Files:**
- Modify: `Verbo/Verbo/VerboApp.swift`
- Create: `Verbo/Verbo/AppDelegate.swift`

- [ ] **Step 1: Implement AppDelegate**

```swift
// Verbo/AppDelegate.swift
import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    // MARK: - Windows
    private var floatingPanel: FloatingPanel?
    private let settingsWindow = SettingsWindow()
    private let historyWindow = HistoryWindow()

    // MARK: - Managers
    let configManager = ConfigManager()
    let historyManager = HistoryManager()
    let hotkeyManager = HotkeyManager()
    let floatingViewModel = FloatingViewModel()

    // MARK: - Tray
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Load config and history
        configManager.load()
        historyManager.load()

        // Wire up view model
        floatingViewModel.configManager = configManager
        floatingViewModel.historyManager = historyManager
        updateViewModelFromConfig()

        // Create floating panel
        setupFloatingPanel()

        // Setup system tray
        setupStatusItem()

        // Register hotkeys
        registerHotkeys()
    }

    // MARK: - Floating Panel

    private func setupFloatingPanel() {
        let panelView = FloatingPanelView(viewModel: floatingViewModel)
        let hostingView = NSHostingView(rootView: panelView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 200, height: 50)

        let panel = FloatingPanel(contentView: hostingView)
        panel.positionNearBottomRight()
        panel.orderFront(nil)

        // Listen for size changes
        NotificationCenter.default.addObserver(
            forName: .floatingPanelSizeChanged,
            object: nil,
            queue: .main
        ) { [weak panel] notification in
            if let size = notification.userInfo?["size"] as? CGSize {
                panel?.updateSize(to: CGSize(
                    width: max(size.width + 16, 200),
                    height: size.height + 16
                ))
            }
        }

        self.floatingPanel = panel
    }

    // MARK: - System Tray

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Verbo")
        }
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        // Scene items
        for scene in configManager.config.scenes {
            let item = NSMenuItem(title: scene.name, action: #selector(switchScene(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = scene.id
            if scene.id == configManager.config.defaultScene {
                item.state = .on
            }
            if let hotkey = scene.hotkey.toggleRecord {
                item.toolTip = hotkey
            }
            menu.addItem(item)
        }

        menu.addItem(.separator())

        // History
        let historyItem = NSMenuItem(title: String(localized: "menu.history"), action: #selector(showHistory), keyEquivalent: "H")
        historyItem.keyEquivalentModifierMask = .command
        historyItem.target = self
        menu.addItem(historyItem)

        // Settings
        let settingsItem = NSMenuItem(title: String(localized: "menu.settings"), action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.keyEquivalentModifierMask = .command
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        // Version
        let versionItem = NSMenuItem(title: "Verbo v0.1.0", action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        menu.addItem(versionItem)

        // Quit
        let quitItem = NSMenuItem(title: String(localized: "menu.quit"), action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    @objc private func switchScene(_ sender: NSMenuItem) {
        guard let sceneId = sender.representedObject as? String else { return }
        var newConfig = configManager.config
        newConfig.defaultScene = sceneId
        configManager.update(newConfig)
        try? configManager.save()
        updateViewModelFromConfig()
        rebuildMenu()
    }

    @objc private func showHistory() {
        let viewModel = HistoryViewModel(historyManager: historyManager)
        historyWindow.show(viewModel: viewModel)
    }

    @objc private func showSettings() {
        let viewModel = SettingsViewModel(configManager: configManager)
        settingsWindow.show(viewModel: viewModel)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    // MARK: - Hotkeys

    private func registerHotkeys() {
        // Global hotkey
        hotkeyManager.register(
            id: "global-toggle",
            shortcut: configManager.config.globalHotkey.toggleRecord
        ) { [weak self] in
            self?.floatingViewModel.toggleRecording()
        }

        // Scene hotkeys
        for scene in configManager.config.scenes {
            if let toggleKey = scene.hotkey.toggleRecord {
                hotkeyManager.register(
                    id: "scene-\(scene.id)-toggle",
                    shortcut: toggleKey
                ) { [weak self] in
                    guard let self else { return }
                    // Switch to this scene and toggle
                    var newConfig = self.configManager.config
                    newConfig.defaultScene = scene.id
                    self.configManager.update(newConfig)
                    self.updateViewModelFromConfig()
                    self.rebuildMenu()
                    self.floatingViewModel.toggleRecording()
                }
            }

            if let pttKey = scene.hotkey.pushToTalk {
                hotkeyManager.register(
                    id: "scene-\(scene.id)-ptt",
                    shortcut: pttKey,
                    onPress: { [weak self] in
                        guard let self else { return }
                        var newConfig = self.configManager.config
                        newConfig.defaultScene = scene.id
                        self.configManager.update(newConfig)
                        self.updateViewModelFromConfig()
                        self.floatingViewModel.startRecording()
                    },
                    onRelease: { [weak self] in
                        self?.floatingViewModel.stopRecording()
                    }
                )
            }
        }

        hotkeyManager.startListening()
    }

    private func updateViewModelFromConfig() {
        if let scene = configManager.defaultScene() {
            floatingViewModel.currentSceneName = scene.name
            floatingViewModel.currentHotkeyHint = scene.hotkey.toggleRecord ?? ""
        }
    }
}
```

- [ ] **Step 2: Update VerboApp.swift**

```swift
// Verbo/VerboApp.swift
import SwiftUI

@main
struct VerboApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
```

- [ ] **Step 3: Verify build**

```bash
cd Verbo && xcodegen generate && xcodebuild -project Verbo.xcodeproj -scheme Verbo -configuration Debug build 2>&1 | tail -10
```

Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add Verbo/Verbo/VerboApp.swift Verbo/Verbo/AppDelegate.swift
git commit -m "feat: add AppDelegate with system tray, hotkeys, and floating panel"
```

---

## Task 18: i18n — Localizable Strings

**Files:**
- Create: `Verbo/Verbo/Resources/Localizable.xcstrings`
- Create: `Verbo/Verbo/Utilities/Localization.swift`

- [ ] **Step 1: Create Localizable.xcstrings**

```json
{
  "sourceLanguage" : "en",
  "strings" : {
    "pill.recognizing" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Recognizing..." } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "识别中..." } }
      }
    },
    "pill.processing" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Processing" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "处理中" } }
      }
    },
    "pill.done" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Done" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "完成" } }
      }
    },
    "pill.error" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Error" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "错误" } }
      }
    },
    "bubble.inserted" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Inserted" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "已输入" } }
      }
    },
    "bubble.retry" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Retry" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "重试" } }
      }
    },
    "settings.title" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Settings" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "设置" } }
      }
    },
    "settings.tab.scenes" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Scenes" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "场景" } }
      }
    },
    "settings.tab.providers" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Providers" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "服务商" } }
      }
    },
    "settings.tab.general" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "General" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "通用" } }
      }
    },
    "settings.tab.about" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "About" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "关于" } }
      }
    },
    "scenes.default" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Default" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "默认" } }
      }
    },
    "scenes.edit" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Edit" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "编辑" } }
      }
    },
    "scenes.name" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Scene Name" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "场景名称" } }
      }
    },
    "scenes.pipeline" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Pipeline Steps" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "处理步骤" } }
      }
    },
    "scenes.hotkeys" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Hotkeys" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "快捷键" } }
      }
    },
    "scenes.toggle" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Toggle Record" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "切换录音" } }
      }
    },
    "scenes.pushToTalk" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Push to Talk" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "按住说话" } }
      }
    },
    "common.save" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Save" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "保存" } }
      }
    },
    "common.cancel" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Cancel" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "取消" } }
      }
    },
    "providers.stt" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Speech-to-Text Providers" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "语音识别服务商" } }
      }
    },
    "providers.llm" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "LLM Providers" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "语言模型服务商" } }
      }
    },
    "general.hotkeys" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Global Hotkeys" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "全局快捷键" } }
      }
    },
    "general.toggleRecord" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Toggle Record" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "切换录音" } }
      }
    },
    "general.behavior" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Behavior" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "行为" } }
      }
    },
    "general.outputMode" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Output Mode" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "输出方式" } }
      }
    },
    "general.simulate" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Simulate Input" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "模拟输入" } }
      }
    },
    "general.clipboard" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Clipboard" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "剪贴板" } }
      }
    },
    "general.autoCollapse" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Auto-collapse Delay" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "自动折叠延迟" } }
      }
    },
    "general.never" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Never" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "永不" } }
      }
    },
    "general.language" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Language" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "语言" } }
      }
    },
    "general.uiLanguage" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "UI Language" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "界面语言" } }
      }
    },
    "general.followSystem" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Follow System" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "跟随系统" } }
      }
    },
    "general.data" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Data" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "数据" } }
      }
    },
    "general.retention" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "History Retention" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "历史保留" } }
      }
    },
    "general.30days" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "30 Days" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "30 天" } }
      }
    },
    "general.90days" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "90 Days" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "90 天" } }
      }
    },
    "general.forever" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Forever" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "永久" } }
      }
    },
    "about.description" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "An open-source modular voice input tool for macOS." } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "一个开源的模块化语音输入工具。" } }
      }
    },
    "about.license" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "MIT License" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "MIT 协议" } }
      }
    },
    "history.title" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Input History" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "输入历史" } }
      }
    },
    "history.search" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Search..." } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "搜索..." } }
      }
    },
    "history.filter" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Scene" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "场景" } }
      }
    },
    "history.allScenes" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "All Scenes" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "全部场景" } }
      }
    },
    "history.clearAll" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Clear All" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "清空全部" } }
      }
    },
    "history.empty" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "No history records" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "暂无历史记录" } }
      }
    },
    "history.today" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Today" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "今天" } }
      }
    },
    "history.yesterday" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Yesterday" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "昨天" } }
      }
    },
    "history.earlier" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Earlier" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "更早" } }
      }
    },
    "history.viewOriginal" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "View original" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "查看原文" } }
      }
    },
    "history.status.inserted" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Inserted" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "已输入" } }
      }
    },
    "history.status.copied" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Copied" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "已复制" } }
      }
    },
    "history.status.failed" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Failed" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "失败" } }
      }
    },
    "menu.history" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Input History" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "输入历史" } }
      }
    },
    "menu.settings" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Settings" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "设置" } }
      }
    },
    "menu.quit" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Quit" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "退出" } }
      }
    }
  },
  "version" : "1.0"
}
```

- [ ] **Step 2: Verify build**

```bash
cd Verbo && xcodegen generate && xcodebuild -project Verbo.xcodeproj -scheme Verbo -configuration Debug build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Run all tests**

```bash
cd Verbo && xcodebuild test -project Verbo.xcodeproj -scheme VerboTests -configuration Debug 2>&1 | grep -E "(Test Suite|passed|failed|error:)"
```

Expected: All tests PASS

- [ ] **Step 4: Commit**

```bash
git add Verbo/Verbo/Resources/Localizable.xcstrings
git commit -m "feat: add i18n localization strings (zh-Hans, en)"
```

---

## Task 19: Integration Verification — Build & Run

This is the final integration task to verify everything works together.

- [ ] **Step 1: Full clean build**

```bash
cd Verbo && xcodegen generate && xcodebuild -project Verbo.xcodeproj -scheme Verbo -configuration Debug clean build 2>&1 | tail -10
```

Expected: BUILD SUCCEEDED

- [ ] **Step 2: Run all tests**

```bash
cd Verbo && xcodebuild test -project Verbo.xcodeproj -scheme VerboTests -configuration Debug 2>&1 | grep -E "(Test Suite|Test Case|passed|failed)"
```

Expected: All tests PASS

- [ ] **Step 3: Launch app and verify basic UI**

```bash
cd Verbo && open build/Debug/Verbo.app
```

Verify via computer-use screenshot:
- System tray icon appears
- Floating pill appears in bottom-right corner
- Click pill → recording starts (dot turns red)
- Tray menu shows 3 scenes + History/Settings/Quit

- [ ] **Step 4: Verify Settings window**

Click "Settings" in tray menu. Verify:
- 4 tabs: Scenes, Providers, General, About
- Scenes tab shows 3 preset scenes
- Providers tab has iFlytek and OpenAI sections
- About shows version 0.1.0

- [ ] **Step 5: Final commit (if any fixes needed)**

```bash
git add -p  # review changes
git commit -m "fix: integration fixes for v0.1.0"
```

---

## Spec Coverage Checklist

| Spec Requirement | Task |
|---|---|
| NSPanel (nonactivating) floating window | Task 12 |
| CGEvent keyboard simulation + clipboard fallback | Task 8 |
| AVAudioEngine recording (16kHz, mono, 16-bit) | Task 7 |
| iFlytek WebSocket STT with pgs replace mode | Task 5 |
| OpenAI-compatible LLM with SSE streaming | Task 6 |
| Pipeline engine (actor, sequential steps) | Task 10 |
| JSON config (~/Library/Application Support/Verbo/) | Task 4 |
| 3 preset scenes (dictate, polish, translate) | Task 2 (Scene.presets) |
| System tray (NSStatusItem + NSMenu) | Task 17 |
| Global + per-scene hotkeys | Task 11, 17 |
| Toggle + Push-to-Talk recording modes | Task 11, 17 |
| Floating pill (6 states) | Task 14 |
| Bubble view (streaming text, strikethrough, result) | Task 14 |
| Waveform animation | Task 14 |
| Auto-collapse after result | Task 13 |
| Settings window (Scenes, Providers, General, About) | Task 15 |
| Input history (search, filter, date grouping) | Task 16 |
| i18n (zh-Hans, en) | Task 18 |
| Warm parchment design system | Task 3 |
| Data models (AppConfig, Scene, PipelineState, HistoryRecord) | Task 2 |
| LSUIElement (no dock icon) | Task 1 (Info.plist) |
| macOS 14+, Swift 6 | Task 1 (project.yml) |
