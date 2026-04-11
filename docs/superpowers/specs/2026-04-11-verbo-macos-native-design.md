# Verbo macOS — Native Swift Design Spec

> 基于已验证的产品设计规格（2026-04-11-verbo-design.md），用原生 Swift 重新实现 macOS 版本。
> 功能需求、UI 设计、管道架构保持不变，本文档只描述 macOS 原生技术方案。

## 1. 技术决策

| 决策项 | 选择 | 理由 |
|--------|------|------|
| UI 框架 | SwiftUI + AppKit 混合 | SwiftUI 做 UI 渲染简洁高效，AppKit 做窗口管理（NSPanel）获得系统级行为 |
| 项目结构 | Xcode Project + SPM 依赖 | 标准 macOS app 结构，方便签名和分发 |
| 音频录制 | AVAudioEngine | 低延迟，支持实时 PCM 流式输出，直接喂给 STT |
| WebSocket (STT) | URLSessionWebSocketTask | 系统原生，无第三方依赖 |
| HTTP (LLM) | URLSession + async/await | 原生支持 SSE 流式解析 |
| 配置存储 | JSON 文件 (~/Library/Application Support/Verbo/) | 开发者可手动编辑，与原设计一致 |
| 系统托盘 | NSStatusItem + NSMenu | 原生托盘，完美集成 |
| 悬浮窗 | NSPanel (nonactivating) | 不抢焦点、点击不切换 app、始终浮在最上层 |
| 键盘模拟 | CGEvent | 系统级，支持所有字符（含中文），比 osascript 快100倍 |
| 测试 | XCTest + Swift Testing | 单元测试 + 集成测试 |
| 最低版本 | macOS 14 (Sonoma) | SwiftUI 稳定，Observable 宏可用 |
| 语言版本 | Swift 6 | 最新特性，严格并发检查 |

## 2. 架构

```
Verbo.app
├── App Entry (VerboApp.swift)
│   ├── NSStatusItem (系统托盘)
│   └── NSPanel (悬浮窗)
│
├── UI Layer (SwiftUI)
│   ├── FloatingPanelView      — 悬浮窗根视图
│   │   ├── PillView           — 胶囊组件
│   │   ├── BubbleView         — 展开气泡
│   │   └── WaveformView       — 波形动画
│   ├── SettingsView           — 设置窗口
│   │   ├── ScenesSettingsView
│   │   ├── ProvidersSettingsView
│   │   ├── GeneralSettingsView
│   │   └── AboutView
│   └── HistoryView            — 输入历史
│
├── Core Layer
│   ├── PipelineEngine         — 管道执行器
│   ├── AudioRecorder          — AVAudioEngine 录音
│   ├── TextOutputService      — CGEvent 键盘模拟 + 剪贴板
│   ├── HotkeyManager          — 全局快捷键监听
│   └── ConfigManager          — JSON 配置读写
│
├── Adapters
│   ├── STT/
│   │   ├── STTAdapter (protocol)
│   │   └── IFlytekSTTAdapter  — WebSocket 流式 STT
│   └── LLM/
│       ├── LLMAdapter (protocol)
│       └── OpenAILLMAdapter   — HTTP SSE 流式 LLM
│
└── Models
    ├── AppConfig              — 配置模型
    ├── Scene                  — 场景定义
    ├── PipelineState          — 管道状态机
    └── HistoryRecord          — 历史记录
```

## 3. 悬浮窗 — NSPanel

```swift
// 关键：继承 NSPanel 而非 NSWindow
class FloatingPanel: NSPanel {
    // nonactivating: 点击不抢焦点
    // .floating 级别: 始终浮在普通窗口之上
    // 无标题栏、透明背景
}
```

**行为：**
- `styleMask: [.nonactivatingPanel, .borderless]`
- `level: .floating`
- `isMovableByWindowBackground = true` → 拖拽移动
- `collectionBehavior: [.canJoinAllSpaces, .fullScreenAuxiliary]` → 所有桌面可见
- `backgroundColor = .clear` + `isOpaque = false` → 透明背景
- `hasShadow = false` → 无系统阴影（UI 自己画）

**窗口尺寸动态调整：**
- Idle 态: 紧贴 pill 尺寸（~150x36）
- 展开态: 自动扩展到包含 bubble 的尺寸
- 使用 SwiftUI 的 `GeometryReader` 测量内容大小，通过 `NSPanel.setContentSize` 同步

## 4. 键盘模拟 — CGEvent

```swift
func simulateInput(text: String) {
    // 对每个字符创建 CGEvent key down/up
    // 中文/Unicode: 通过 CGEvent(keyboardEventSource:...) + UniChar
    // 优势: 系统级，不需要辅助功能权限（与 AX API 不同）
    // 注意: 需要 Input Monitoring 权限
}
```

**回退策略（同原设计）：**
- 优先 CGEvent 模拟输入
- 失败则写入剪贴板 + 模拟 Cmd+V

## 5. 音频录制 — AVAudioEngine

```swift
class AudioRecorder {
    private let engine = AVAudioEngine()

    func start() -> AsyncStream<Data> {
        // 安装 tap: 16kHz, 单声道, PCM
        // 通过 AsyncStream 实时推送音频块给 STT
        // 延迟 < 50ms
    }

    func stop() -> Data {
        // 停止录音，返回完整音频
    }
}
```

**关键参数：**
- 采样率: 16000 Hz
- 位深: 16-bit (Int16)
- 声道: 单声道
- 缓冲区: 1280 bytes (40ms) per chunk

## 6. STT 适配器 — Protocol

```swift
protocol STTAdapter {
    var name: String { get }
    var supportsStreaming: Bool { get }

    // 批量模式
    func transcribe(audio: Data, lang: String) async throws -> String

    // 流式模式
    func transcribeStream(
        audioStream: AsyncStream<Data>,
        lang: String
    ) -> AsyncThrowingStream<String, Error>
}
```

### iFlytek 实现

- URLSessionWebSocketTask 连接
- HMAC-SHA256 鉴权（CryptoKit）
- 流式发送 40ms 音频块
- 解析 `ws[].cw[].w` 响应格式
- accumulator 处理 `pgs: rpl` 替换模式（已验证）

## 7. LLM 适配器 — Protocol

```swift
protocol LLMAdapter {
    var name: String { get }

    func complete(prompt: String) async throws -> String

    func completeStream(prompt: String) -> AsyncThrowingStream<String, Error>
}
```

### OpenAI 实现

- URLSession POST /v1/chat/completions
- SSE 流式解析 `data: {...}` 行
- 支持 `baseUrl` 配置（兼容任何 OpenAI 兼容 API）

## 8. 管道引擎

```swift
actor PipelineEngine {
    func execute(
        steps: [PipelineStep],
        audioStream: AsyncStream<Data>,
        audio: Data,
        getSTT: (String) -> STTAdapter?,
        getLLM: (String) -> LLMAdapter?
    ) -> AsyncThrowingStream<PipelineState, Error>
}
```

- 顺序执行步骤，上一步输出作为下一步 `{{input}}`
- 通过 `AsyncThrowingStream` 推送状态变化（transcribing → processing → done）
- Swift actor 保证并发安全

## 9. 配置模型

```swift
struct AppConfig: Codable {
    var version: Int = 1
    var defaultScene: String = "dictate"
    var globalHotkey: GlobalHotkey
    var scenes: [Scene]
    var providers: ProvidersConfig
    var general: GeneralConfig
}
```

- JSON 文件路径: `~/Library/Application Support/Verbo/config.json`
- 首次启动生成默认配置（3 个预设场景）
- `@Observable` 类封装，UI 自动响应变化

## 10. 全局快捷键

使用 `CGEvent.tapCreate` 或 `NSEvent.addGlobalMonitorForEvents` 监听全局快捷键。

- Toggle 模式: 按一次开始，再按一次停止
- Push-to-Talk 模式: 按住说话，松开停止
- 场景级快捷键: 每个场景可绑定独立快捷键

需要 **辅助功能权限**（Accessibility），首次启动引导用户授权。

## 11. 系统托盘

```swift
let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
// 菜单:
// ✓ 语音输入    Alt+D
//   润色输入     Alt+J
//   中译英       Alt+T
// ─────────────
//   输入历史     ⌘H
//   设置         ⌘,
// ─────────────
//   Verbo v0.1.0
//   退出
```

## 12. 文件结构

```
Verbo/
├── Verbo.xcodeproj
├── Verbo/
│   ├── VerboApp.swift                 — @main 入口
│   ├── AppDelegate.swift              — NSPanel + NSStatusItem 管理
│   │
│   ├── Models/
│   │   ├── AppConfig.swift            — 配置模型 (Codable)
│   │   ├── Scene.swift                — 场景定义
│   │   ├── PipelineState.swift        — 管道状态枚举
│   │   └── HistoryRecord.swift        — 历史记录
│   │
│   ├── Core/
│   │   ├── PipelineEngine.swift       — 管道执行器 (actor)
│   │   ├── AudioRecorder.swift        — AVAudioEngine 录音
│   │   ├── TextOutputService.swift    — CGEvent 输入 + 剪贴板
│   │   ├── HotkeyManager.swift        — 全局快捷键
│   │   └── ConfigManager.swift        — JSON 配置读写
│   │
│   ├── Adapters/
│   │   ├── STTAdapter.swift           — protocol
│   │   ├── IFlytekSTTAdapter.swift    — 讯飞 WebSocket
│   │   ├── LLMAdapter.swift           — protocol
│   │   └── OpenAILLMAdapter.swift     — OpenAI HTTP
│   │
│   ├── Views/
│   │   ├── Floating/
│   │   │   ├── FloatingPanelView.swift
│   │   │   ├── PillView.swift
│   │   │   ├── BubbleView.swift
│   │   │   └── WaveformView.swift
│   │   ├── Settings/
│   │   │   ├── SettingsView.swift
│   │   │   ├── ScenesSettingsView.swift
│   │   │   ├── ProvidersSettingsView.swift
│   │   │   ├── GeneralSettingsView.swift
│   │   │   └── AboutView.swift
│   │   └── History/
│   │       └── HistoryView.swift
│   │
│   ├── ViewModels/
│   │   ├── FloatingViewModel.swift    — 悬浮窗状态管理 (@Observable)
│   │   ├── SettingsViewModel.swift
│   │   └── HistoryViewModel.swift
│   │
│   ├── Resources/
│   │   ├── Assets.xcassets
│   │   └── Localizable.xcstrings      — i18n (zh-Hans, en)
│   │
│   └── Utilities/
│       └── DesignTokens.swift         — 颜色、字体、圆角常量
│
└── VerboTests/
    ├── PipelineEngineTests.swift
    ├── IFlytekSTTAdapterTests.swift
    ├── OpenAILLMAdapterTests.swift
    ├── AudioRecorderTests.swift
    ├── ConfigManagerTests.swift
    └── TextOutputServiceTests.swift
```

## 13. 与原设计的差异

| 原设计 (Tauri) | macOS 原生 | 改进 |
|----------------|-----------|------|
| WebView 透明窗口 + hack | NSPanel (nonactivating) | 无需点击切换 app，原生透明 |
| osascript keystroke | CGEvent | 原生支持中文，延迟更低 |
| Web Audio API | AVAudioEngine | 延迟更低，直接 PCM 输出 |
| React 渲染 | SwiftUI | 更轻量，原生动画 |
| Zustand 状态管理 | @Observable | 编译时类型安全，自动 UI 更新 |
| i18next | Localizable.xcstrings | Xcode 原生 i18n 支持 |
| npm + cargo 构建 | Xcode build | 单一构建系统 |

## 14. MVP 范围

与原设计一致：
- iFlytek 流式 STT（中文 + 英文）
- OpenAI 兼容 LLM 适配器
- 3 个预设场景（听写、润色、翻译）
- 悬浮窗（pill + bubble，6 种状态）
- 设置窗口（场景、服务商、通用、关于）
- 输入历史
- 系统托盘
- i18n（中文、英文）
- 全局快捷键（toggle + push-to-talk）
