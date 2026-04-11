# Verbo — Modular Voice Input Tool Design Spec

> Flexible voice input for macOS and Windows. Use any speech or LLM API, and build the workflow that fits you best.

## 1. Overview

Verbo is an open-source, modular desktop voice input tool. Users can combine any cloud-based STT (Speech-to-Text) engine with any LLM service to build custom voice input workflows called **Scenes**.

### Target Audience

Developer-first, accessible to general users. Power users configure via JSON files; casual users manage everything through the GUI.

### Tech Stack

- **Desktop Framework**: Tauri 2 (Rust backend + WebView frontend)
- **Frontend**: React
- **Configuration**: JSON files + GUI settings (bidirectional sync)
- **Platforms**: macOS, Windows

### Core Principles

- **Modular**: STT and LLM providers are pluggable via adapter interfaces
- **Configurable**: Scenes define composable pipelines through JSON configuration
- **Minimal**: Compact floating UI that stays out of the way
- **i18n**: UI follows system language (Chinese / English)

## 2. Architecture

```
┌──────────────────────────────────────────────────────┐
│                     Tauri Shell                       │
│  ┌────────────────────────────────────────────────┐   │
│  │               Rust Backend                     │   │
│  │  ┌──────────┐ ┌───────────┐ ┌──────────────┐  │   │
│  │  │ Hotkey   │ │ Config    │ │ Text Output  │  │   │
│  │  │ Manager  │ │ Manager   │ │ (Simulate /  │  │   │
│  │  │          │ │ (R/W JSON)│ │  Clipboard)  │  │   │
│  │  └──────────┘ └───────────┘ └──────────────┘  │   │
│  └────────────────────────────────────────────────┘   │
│                       ↕ Tauri IPC                     │
│  ┌────────────────────────────────────────────────┐   │
│  │               React Frontend                   │   │
│  │  ┌───────────┐ ┌───────────┐ ┌─────────────┐  │   │
│  │  │ Floating  │ │ Settings  │ │ History     │  │   │
│  │  │ Window    │ │ Window    │ │ Window      │  │   │
│  │  └───────────┘ └───────────┘ └─────────────┘  │   │
│  │                      ↕                         │   │
│  │  ┌──────────────────────────────────────────┐  │   │
│  │  │           Pipeline Engine                │  │   │
│  │  │  Executes scene steps sequentially       │  │   │
│  │  └──────────────────────────────────────────┘  │   │
│  │                      ↕                         │   │
│  │  ┌──────────────────────────────────────────┐  │   │
│  │  │           Adapter Layer                  │  │   │
│  │  │  ┌──────────────┐  ┌─────────────────┐  │  │   │
│  │  │  │ STT Adapters │  │ LLM Adapters    │  │  │   │
│  │  │  │ (iFlytek...) │  │ (OpenAI/Claude) │  │  │   │
│  │  │  └──────────────┘  └─────────────────┘  │  │   │
│  │  └──────────────────────────────────────────┘  │   │
│  └────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────┘
```

### Responsibility Split

| Layer | Responsibility |
|-------|---------------|
| **Rust Backend** | Global hotkey listening, config file I/O, simulated keyboard input, clipboard operations, system tray |
| **React Frontend** | Floating window rendering, settings UI, history UI, pipeline engine execution, cloud API calls |
| **Adapter Layer** | Unified interfaces for STT and LLM providers; each vendor implements its own adapter |

Pipeline engine runs in the frontend because cloud API calls (STT, LLM) are HTTP/WebSocket requests — natural for the web layer, and enables streaming UI updates (e.g., LLM output appearing character by character in the floating window).

## 3. Pipeline & Scenes

### Configuration-Driven Sequential Pipeline

Each Scene defines an ordered list of pipeline steps in JSON. The runtime executes steps sequentially — each step's output becomes the next step's `{{input}}`.

```json
{
  "version": 1,
  "defaultScene": "dictate",
  "globalHotkey": {
    "toggleRecord": "CommandOrControl+Shift+H",
    "pushToTalk": "CommandOrControl+Shift+G"
  },
  "scenes": [
    {
      "id": "dictate",
      "name": "语音输入",
      "hotkey": {
        "toggleRecord": "Alt+D",
        "pushToTalk": null
      },
      "pipeline": [
        { "type": "stt", "provider": "iflytek", "lang": "zh" }
      ],
      "output": "simulate"
    },
    {
      "id": "polish",
      "name": "润色输入",
      "hotkey": {
        "toggleRecord": "Alt+J",
        "pushToTalk": null
      },
      "pipeline": [
        { "type": "stt", "provider": "iflytek", "lang": "zh" },
        { "type": "llm", "provider": "openai", "prompt": "请润色以下口语化文字，使其更书面化，保持原意，直接输出结果：\n{{input}}" }
      ],
      "output": "simulate"
    },
    {
      "id": "translate",
      "name": "中译英",
      "hotkey": {
        "toggleRecord": "Alt+T",
        "pushToTalk": null
      },
      "pipeline": [
        { "type": "stt", "provider": "iflytek", "lang": "zh" },
        { "type": "llm", "provider": "openai", "prompt": "将以下中文翻译为英文，直接输出翻译结果：\n{{input}}" }
      ],
      "output": "simulate"
    }
  ],
  "providers": {
    "stt": {
      "iflytek": {
        "appId": "",
        "apiKey": "",
        "apiSecret": "",
        "enabledLangs": ["zh", "en"]
      }
    },
    "llm": {
      "openai": {
        "apiKey": "",
        "model": "gpt-4o-mini",
        "baseUrl": "https://api.openai.com/v1"
      }
    }
  }
}
```

### Key Design Decisions

- **Global hotkey vs scene hotkey**: Global hotkeys trigger the default scene. Each scene can independently bind `toggleRecord` (press once to start, press again to stop) and/or `pushToTalk` (hold to record, release to stop).
- **`{{input}}` template variable**: Each step's output replaces `{{input}}` in the next step's prompt.
- **`output` field**: `"simulate"` (default) or `"clipboard"` — per-scene override of the global default.
- **`providers` centralized**: API keys and config in one place; scenes reference by provider name.
- **Language at provider level**: Each STT provider declares its supported languages. Scenes select from enabled languages.

## 4. STT Adapter Interface

STT adapters support two modes: batch and streaming. The pipeline engine selects the best mode based on adapter capabilities.

```typescript
interface STTOptions {
  lang: string
}

interface STTAdapter {
  readonly name: string

  capabilities: {
    streaming: boolean
  }

  // Batch mode — all adapters must implement
  transcribe(audio: ArrayBuffer, options: STTOptions): Promise<string>

  // Streaming mode — optional
  transcribeStream?(
    audioStream: ReadableStream<ArrayBuffer>,
    options: STTOptions,
    onPartial: (text: string) => void
  ): Promise<string>
}
```

### Pipeline Engine Logic for STT

1. Check if the current STT adapter supports `streaming`
2. If yes → start streaming connection when recording begins; push audio chunks in real-time; display partial results in floating window
3. If no → wait for recording to finish, submit complete audio, show "Recognizing..." in floating window
4. Either mode produces a final string, passed to the next pipeline step

### MVP: iFlytek Adapter

- WebSocket-based real-time streaming
- Supports Chinese (zh) and English (en)
- Streaming mode enabled

## 5. LLM Adapter Interface

LLM steps execute simple prompt completion — no agent loops, no tool use.

```typescript
interface LLMOptions {
  prompt: string   // with {{input}} already resolved
  model?: string
}

interface LLMAdapter {
  readonly name: string

  complete(options: LLMOptions): Promise<string>

  // Streaming for real-time display in floating window
  completeStream?(
    options: LLMOptions,
    onChunk: (text: string) => void
  ): Promise<string>
}
```

## 6. Voice Input Trigger

### Two Recording Modes

| Mode | Behavior | Use Case |
|------|----------|----------|
| **Toggle** | Press hotkey to start → press again to stop | Longer dictation |
| **Push-to-Talk** | Hold hotkey → release to stop | Quick phrases |

Both modes are available per-scene. Users can bind one or both.

### Recording Flow

1. User presses hotkey (or holds for push-to-talk)
2. Rust backend detects hotkey → notifies frontend via IPC
3. Frontend starts audio recording (WebAudio API or Tauri audio plugin)
4. Pipeline engine begins STT step (streaming if supported)
5. User stops recording (releases key or presses toggle again)
6. STT finalizes → pipeline continues to next step (if any)

## 7. Text Output

### One-Shot Output

Text is **always output in one shot** after the entire pipeline completes. No intermediate text is inserted into the focus window.

**Rationale**: Inserting STT partial results into the focus window and then replacing them when LLM finishes would require simulating backspace/delete — unreliable across applications and risks deleting user's own text if they type during processing.

### Output Modes

| Mode | Behavior | Reliability |
|------|----------|-------------|
| **Simulate Input** (default) | Emulate keyboard events into the focused window | Cannot verify receipt; falls back to clipboard if no focus detected |
| **Clipboard** | Write to clipboard | Can verify by reading back |

### Failure Safety

All pipeline results are **automatically saved to input history** (local storage) before attempting output. If output fails (no focus, app frozen, permission denied), the text is never lost — user can retrieve it from the history page.

### macOS Permissions

Simulated keyboard input requires **Accessibility permission**. The app should detect if permission is missing and guide the user to grant it.

## 8. Floating Window UI

### Design System

Follows the warm parchment palette defined in DESIGN.md:

- **Surface**: Ivory (#faf9f5) on Parchment (#f5f4ed) background
- **Accent**: Terracotta (#c96442) for recording state
- **Shadows**: Ring shadow (0px 0px 0px 1px) per design system
- **All grays warm-toned** — no cool blue-grays
- **Dark theme**: Dark Surface (#30302e) with warm borders

### Widget Form Factor

**Compact pill** that stays on screen with minimal footprint:

- **Idle**: `[● Verbo  Alt+D]` — gray dot, app name, hotkey hint
- **Recording**: `[● ||||| 0:03]` — red pulsing dot, waveform bars, timer
- **Processing**: `[● Polishing ...]` — coral dot, shimmer text, bouncing dots

**Expands to bubble** when text content needs display:

- **Streaming STT**: Bubble appears below pill with partial text updating in real-time
- **LLM Processing**: Source text with strikethrough (fading) + target text typing character-by-character with blinking cursor
- **Result**: Final text + status ("Inserted") + Copy/Retry buttons

### State Flow

```
Idle → Recording (pill) → Streaming STT (bubble expands)
  → LLM Processing (source struck, target typing) → Result (final text)
  → Auto Collapse (1.5s configurable) → Idle
```

For pure dictation (no LLM step):

```
Idle → Recording → Streaming STT → Result → Auto Collapse → Idle
```

### Auto-Collapse Behavior

- Result displays for a configurable duration (default 1.5s), then pill auto-collapses to idle
- No click required to dismiss — ready for the next recording immediately
- Click the pill to re-expand and view the last result (for Copy)
- Auto-collapse delay is configurable in General settings (1.5s / 3s / 5s / never)

### Error States

- **API Error**: Red dot, error message with actionable guidance ("Check iFlytek credentials in Settings"), Retry + Settings buttons
- **Network Error**: Red dot, "Cannot reach API server", Retry button

## 9. Settings Window

Independent window (not floating), accessed from system tray menu.

### Navigation

```
场景 | 服务商 | 通用 | 关于
```

No separate "Hotkeys" page — hotkeys are bound to scenes and edited inline in the scene editor.

### Scenes Page

- **Scene list** with inline display: scene name, pipeline summary, hotkey badge, default indicator
- Click a scene → **scene editor** with:
  - Scene name
  - Pipeline steps (visual step cards: STT config, LLM config + prompt textarea)
  - Add/remove pipeline steps
  - Output mode selector (Simulate Input / Clipboard)
  - Hotkey binding for toggle mode and push-to-talk mode (click to record new hotkey)
  - Save / Cancel

### Providers Page

- **STT section**: Provider cards with API credentials + **language chips** (select which languages to enable for this engine; scenes can only use enabled languages)
- **LLM section**: Provider cards with API key, model selector, base URL
- Add provider buttons for both sections

### General Page

- **Global hotkeys**: Default scene toggle and push-to-talk bindings
- **Behavior**: Default output mode, auto-collapse delay, launch at startup
- **Language**: UI language (Follow System / Chinese / English)
- **Data**: History retention period (30 days / 90 days / Forever), config file path display

### About Page

- App version, open-source links, licenses

## 10. System Tray

Right-click menu:

```
✓ 语音输入          Alt+D
  润色输入           Alt+J
  中译英             Alt+T
─────────────────────────
  输入历史           ⌘H
  设置               ⌘,
─────────────────────────
  Verbo v0.1.0
  退出
```

- Scene list with checkmark on default scene — click to switch default
- Quick access to History and Settings
- Version display + Quit

## 11. Input History

Standalone window, accessible from tray menu (⌘H).

### Features

- **Auto-save**: Every pipeline result is saved locally with timestamp, scene name, final text, original STT text (if LLM was applied), and output status
- **Date grouping**: Records grouped by day (Today / Yesterday / Earlier)
- **Search**: Full-text search across all records
- **Scene filter**: Dropdown to filter by scene
- **Per-record actions**: Copy button (hover to reveal)
- **"View original"**: For records with LLM processing, expandable link to see the raw STT output
- **Status indicators**: Inserted (green) / Copied (gray) / Insert failed (red)
- **Clear All**: Bulk delete with confirmation
- **Retention**: Configurable in General settings (30d / 90d / Forever)

### Storage

Records stored in local app data directory as JSON. Schema:

```typescript
interface HistoryRecord {
  id: string
  timestamp: number
  sceneId: string
  sceneName: string
  originalText: string      // raw STT output
  finalText: string         // after LLM processing (same as original if no LLM)
  outputStatus: 'inserted' | 'copied' | 'failed'
  pipelineSteps: string[]   // e.g. ['stt:iflytek', 'llm:openai']
}
```

## 12. i18n

- UI language follows system locale by default
- Supported: Chinese (zh-CN), English (en)
- User can override in General settings
- All UI strings extracted to locale files
- Scene names and prompt content are user-defined and not translated

## 13. MVP Scope

### In Scope (v0.1.0)

- Tauri 2 + React project setup
- iFlytek streaming STT adapter (zh + en)
- One LLM adapter (OpenAI-compatible, covering OpenAI / any OpenAI-compatible API)
- Scene system with JSON config + GUI editor
- Floating window (pill + bubble) with all states and transitions
- Simulated keyboard input + clipboard fallback
- Global and per-scene hotkeys (toggle + push-to-talk)
- Settings window (Scenes, Providers, General, About)
- Input history with search and filter
- System tray menu
- i18n (zh-CN, en)
- macOS support

### Out of Scope (Future)

- Windows support (architecture supports it, implementation deferred)
- Local STT models (Whisper.cpp)
- Additional cloud STT providers (Google, Azure, etc.)
- Plugin system / community extensions
- Dark theme for floating window (design ready, implementation deferred)
- Conditional pipeline steps
- Audio playback in history
- Export/import configuration
- Auto-update mechanism

## 14. Visual Reference

Interactive UI mockups are available at `.superpowers/brainstorm/` in the project directory, covering:

1. Floating window — all states with interactive transition animation
2. System tray menu (zh/en)
3. Settings — Scene list, Scene editor, Providers, General
4. Input history (zh/en)

All mockups follow the DESIGN.md warm parchment design system.
