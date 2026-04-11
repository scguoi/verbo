# Verbo Headless Testing Framework Design

> 为 Verbo macOS 原生 Swift 项目设计分层自动化测试框架 + 结构化日志系统。
> 目标：每次代码变更后快速验证，最大限度减少需要人工体验才能发现的问题。

## 1. 测试分层

### 第一层：Unit Tests（目标 < 5 秒）

纯逻辑验证，不依赖系统资源（无网络、无音频设备、无 GUI）。

**覆盖范围：**

- **Models 边界值 + 兼容性**
  - 所有数值类型的极端值（Int16.min/max、Double.nan、空字符串、空数组）
  - JSON 解码容错：缺字段用默认值、多余字段忽略、类型错误不崩溃
  - JSON 编解码 round-trip 对所有 Codable 类型
- **ViewModel 状态机**
  - FloatingViewModel：枚举所有 `(currentState, action)` 组合，验证转换结果
  - 关键转换：idle→recording、recording→transcribing、transcribing→done、done→idle
  - 关键动作：pillTapped、toggleRecording、stopRecording、retry 在每个状态下的行为
  - 验证 shouldShowBubble、isActive、pillDotColor 等计算属性
- **Adapter 数据处理**
  - iFlytek：response frame 解析、accumulator append/replace 模式、auth URL 格式
  - OpenAI：SSE line 解析、request body 构建
  - 边界：空响应、畸形 JSON、超长文本、Unicode/emoji
- **PipelineEngine**
  - 模板替换 `{{input}}`
  - 单步/多步 pipeline（mock adapter）
  - provider 找不到时的错误处理
- **工具函数**
  - WaveformView 的 barHeight 计算
  - HotkeyManager 的 shortcut 解析和 displayString 格式化
  - Color hex 初始化

### 第二层：Integration Tests（目标 < 15 秒）

跨模块交互验证，使用 mock 替代外部依赖。

**覆盖范围：**

- **Pipeline 完整流程**
  - mock STT → mock LLM → 验证最终输出和状态序列
  - STT-only pipeline（听写场景）
  - STT + LLM pipeline（润色/翻译场景）
  - pipeline 中途错误恢复
- **ConfigManager 生命周期**
  - 首次启动（无文件）→ 生成默认 → 保存 → 重新加载
  - 旧版 config（缺新字段）→ 加载不崩 → 新字段用默认值
  - 并发读写不冲突
- **HistoryManager 生命周期**
  - 添加 → 搜索 → 过滤 → 持久化 → 重新加载
  - pruneOlderThan 清理过期记录
- **AudioRecorder 生命周期**（不需要真实音频设备）
  - start → stop → start 循环不崩溃
  - stop 后 isRecording == false
  - stop 后 stream 正确 finish
- **WebSocket 生命周期**（mock server）
  - 正常流程：connect → send frames → receive responses → close
  - 异常：连接后立即关闭、发送中断开、status=2 后不继续 receive
  - 快速重连：第一个连接关闭后立即建立第二个

### 第三层：View Smoke Tests（目标 < 10 秒）

验证 SwiftUI View 在各种状态下能渲染不崩溃，不做像素对比。

**覆盖范围：**

- PillView：idle、recording、transcribing、processing、done、error 六种状态
- BubbleView：transcribing（空/有文字）、processing、done、error
- WaveformView：空 levels、正常 levels、全满 levels
- FloatingPanelView：有/无 bubble 的组合
- SettingsView、HistoryView：基本渲染

**实现方式：**
构造 View 实例并调用 `body` 求值。如果 body 能成功计算（不 crash），则通过。不依赖窗口系统。

## 2. 日志系统

### 日志等级

| 等级 | 用途 | Debug 构建 | Release 构建 |
|------|------|-----------|-------------|
| `debug` | 详细数据：每帧音频大小、WebSocket 帧内容、状态变化细节 | ✅ 输出 | ❌ 编译排除 |
| `info` | 关键节点：连接建立/关闭、识别完成、场景切换、配置加载 | ✅ 输出 | ✅ 输出 |
| `error` | 所有错误：API 失败、解析异常、权限缺失 | ✅ 输出 | ✅ 输出 |

### 实现

```swift
import os.log

enum Log {
    private static let subsystem = "com.verbo.app"

    static let stt = Logger(subsystem: subsystem, category: "STT")
    static let llm = Logger(subsystem: subsystem, category: "LLM")
    static let audio = Logger(subsystem: subsystem, category: "Audio")
    static let pipeline = Logger(subsystem: subsystem, category: "Pipeline")
    static let config = Logger(subsystem: subsystem, category: "Config")
    static let hotkey = Logger(subsystem: subsystem, category: "Hotkey")
    static let ui = Logger(subsystem: subsystem, category: "UI")
}
```

- 使用 Apple 原生 `os.log`（`Logger`），零开销 debug 级别在 Release 自动排除
- 按模块分 category，可单独过滤
- 文件日志：Debug 构建同时写入 `~/.verbo/debug.log`（方便 CLI 查看）
- Release 构建不写文件，只走系统 log

### 替换现有日志

当前代码中散落的 `print()` 和 `ilog()` 全部替换为 `Log.xxx.debug/info/error`。

## 3. 可测试性重构

### 问题

现有 ViewModel 直接实例化依赖，无法注入 mock：

```swift
// 当前：FloatingViewModel 内部创建，测试无法替换
private let pipelineEngine = PipelineEngine()
private let audioRecorder = AudioRecorder()
private let textOutputService = TextOutputService()
```

### 方案

为需要 mock 的组件定义协议，通过 init 注入：

```swift
protocol AudioRecording: Sendable {
    var isRecording: Bool { get async }
    var audioLevels: [Float] { get async }
    func start() async -> AsyncStream<Data>
    func stop() async -> Data
}

protocol TextOutputting: Sendable {
    func output(text: String, mode: OutputMode) async -> HistoryRecord.OutputStatus
    func writeToClipboard(_ text: String)
}

// FloatingViewModel 改为接受协议
@Observable @MainActor
final class FloatingViewModel {
    private let audioRecorder: any AudioRecording
    private let textOutputService: any TextOutputting
    private let pipelineEngine: PipelineEngine

    init(
        audioRecorder: any AudioRecording = AudioRecorder(),
        textOutputService: any TextOutputting = TextOutputService(),
        pipelineEngine: PipelineEngine = PipelineEngine()
    ) { ... }
}
```

现有的 `AudioRecorder` 和 `TextOutputService` 直接 conform 协议，生产代码零改动。测试代码注入 mock。

### 需要新增的协议

| 协议 | 现有实现 | Mock 用途 |
|------|---------|----------|
| `AudioRecording` | `AudioRecorder` | 模拟音频流、控制 isRecording 状态 |
| `TextOutputting` | `TextOutputService` | 验证输出文本、跳过 CGEvent |

`PipelineEngine` 是 actor，已经通过闭包注入 adapter，不需要额外协议。
`ConfigManager` 和 `HistoryManager` 已经支持 directory 注入，测试用临时目录即可。

## 4. Mock 工具库

### 文件：`VerboTests/TestHelpers/`

```
VerboTests/
├── TestHelpers/
│   ├── MockSTTAdapter.swift       — 可配置结果的 STT mock
│   ├── MockLLMAdapter.swift       — 可配置结果的 LLM mock
│   ├── MockAudioRecorder.swift    — 模拟音频流
│   ├── MockTextOutputService.swift — 记录输出调用
│   └── TestFixtures.swift         — 常用测试数据工厂
```

从 PipelineEngineTests.swift 中提取现有 mock，补充新的。

### TestFixtures 示例

```swift
enum TestFixtures {
    static func config(withSTT: Bool = true, withLLM: Bool = true) -> AppConfig { ... }
    static func scene(steps: [PipelineStep.StepType] = [.stt]) -> Scene { ... }
    static func historyRecord(status: HistoryRecord.OutputStatus = .inserted) -> HistoryRecord { ... }
    static let sampleAudioChunk = Data(repeating: 0, count: 1280)
    static let iflytekResponseJSON = "..."
}
```

## 5. 测试入口

### Makefile

```makefile
.PHONY: test test-unit test-integration build

test: build                          ## 跑全部测试
	cd Verbo && xcodebuild test -project Verbo.xcodeproj -scheme VerboTests \
		-configuration Debug -resultBundlePath ../test-results \
		2>&1 | xcpretty

test-unit: build                     ## 只跑 unit tests（最快）
	cd Verbo && xcodebuild test -project Verbo.xcodeproj -scheme VerboTests \
		-configuration Debug \
		-only-testing:VerboTests/Models \
		-only-testing:VerboTests/Core \
		-only-testing:VerboTests/Adapters \
		-only-testing:VerboTests/ViewModels \
		2>&1 | xcpretty

test-integration: build              ## unit + integration
	cd Verbo && xcodebuild test -project Verbo.xcodeproj -scheme VerboTests \
		-configuration Debug \
		-skip-testing:VerboTests/ViewSmoke \
		2>&1 | xcpretty

build:                               ## 生成项目 + 编译
	cd Verbo && xcodegen generate && xcodebuild -project Verbo.xcodeproj \
		-scheme Verbo -configuration Debug build

deploy:                              ## 编译并部署到 /Applications
	$(MAKE) build
	pkill -f "Verbo.app/Contents/MacOS/Verbo" 2>/dev/null || true
	rm -rf /Applications/Verbo.app
	cp -R $$(find ~/Library/Developer/Xcode/DerivedData -name "Verbo.app" -path "*/Debug/*" | head -1) /Applications/Verbo.app
	open /Applications/Verbo.app
```

### xcpretty

可选依赖，美化测试输出。没安装则 fallback 到原始输出。

## 6. 关键测试用例清单

### 边界值类（防止溢出/崩溃）

- [ ] AudioRecorder.updateAudioLevels 处理包含 Int16.min 的数据
- [ ] AudioRecorder.updateAudioLevels 处理空 Data
- [ ] WaveformView.barHeight 处理 level > 1.0 和 < 0
- [ ] Color(hex:) 处理边界值 0x000000 和 0xFFFFFF

### JSON 兼容性类（防止配置解析失败）

- [ ] AppConfig 解码缺少 copyOnDismiss 字段的 JSON
- [ ] AppConfig 解码缺少 general 整个 section 的 JSON
- [ ] AppConfig 解码多出未知字段的 JSON
- [ ] GeneralConfig 所有字段都缺失时用默认值
- [ ] Scene 缺少 hotkey 字段时不崩溃

### 状态机类（防止操作无响应）

- [ ] FloatingViewModel：每个 state × pillTapped 的结果
- [ ] FloatingViewModel：每个 state × toggleRecording 的结果
- [ ] FloatingViewModel：每个 state × stopRecording 的结果
- [ ] FloatingViewModel：recording 后 isActive == true
- [ ] FloatingViewModel：transcribing 后 isActive == true
- [ ] FloatingViewModel：done 后 isActive == false

### 资源生命周期类（防止泄漏/崩溃）

- [ ] AudioRecorder：start → stop → start 不崩溃
- [ ] AudioRecorder：stop 后 isRecording == false
- [ ] AudioRecorder：连续调 stop 两次不崩溃
- [ ] Pipeline：error 后 audioRecorder 被 stop
- [ ] Pipeline：cancel 旧 task 后立即 start 新 task 不冲突

### WebSocket 生命周期类

- [ ] iFlytek：正常 connect → send → receive(status=2) → close
- [ ] iFlytek：receive 到 status=2 后不再调 receive
- [ ] iFlytek：连接失败返回明确错误信息
- [ ] iFlytek：API 返回非 0 code 时的错误处理

### View Smoke 类

- [ ] PillView 六种状态都能渲染
- [ ] BubbleView 五种状态都能渲染
- [ ] WaveformView 各种 levels 输入能渲染
