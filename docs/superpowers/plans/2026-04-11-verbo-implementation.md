# Verbo Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build Verbo v0.1.0 — a modular voice input desktop app for macOS with iFlytek STT, OpenAI-compatible LLM, configurable scenes, and a compact floating window UI.

**Architecture:** Tauri 2 app with Rust backend (hotkeys, simulated input, clipboard, tray) and React frontend (floating window, settings, history, pipeline engine, cloud API calls). Configuration-driven sequential pipeline where each Scene defines ordered steps (STT → optional LLM → output). Adapters provide pluggable provider interfaces.

**Tech Stack:** Tauri 2, React 18, TypeScript, Vite, Zustand (state), Vitest (test), i18next (i18n), Rust (tauri, rdev, arboard)

**Design spec:** `docs/superpowers/specs/2026-04-11-verbo-design.md`
**Visual design system:** `DESIGN.md`

---

## File Structure

```
verbo/
├── .gitignore
├── index.html
├── package.json
├── tsconfig.json
├── tsconfig.node.json
├── vite.config.ts
├── vitest.config.ts
│
├── src/
│   ├── main.tsx                          # React entry point
│   ├── App.tsx                           # Root component, window router
│   │
│   ├── types/
│   │   ├── config.ts                     # Config schema types
│   │   ├── pipeline.ts                   # Pipeline & scene types
│   │   └── history.ts                    # History record types
│   │
│   ├── config/
│   │   ├── defaults.ts                   # Default config values
│   │   └── store.ts                      # Zustand config store + Tauri IPC
│   │
│   ├── i18n/
│   │   ├── index.ts                      # i18next setup
│   │   ├── zh-CN.ts                      # Chinese translations
│   │   └── en.ts                         # English translations
│   │
│   ├── adapters/
│   │   ├── stt/
│   │   │   ├── types.ts                  # STTAdapter interface
│   │   │   ├── iflytek.ts                # iFlytek WebSocket streaming adapter
│   │   │   └── registry.ts              # STT adapter registry
│   │   └── llm/
│   │       ├── types.ts                  # LLMAdapter interface
│   │       ├── openai.ts                 # OpenAI-compatible adapter
│   │       └── registry.ts              # LLM adapter registry
│   │
│   ├── engine/
│   │   └── pipeline.ts                   # Pipeline executor
│   │
│   ├── audio/
│   │   └── recorder.ts                   # Browser audio recording
│   │
│   ├── stores/
│   │   ├── app.ts                        # App-level state (current scene, window focus)
│   │   ├── recording.ts                  # Recording state machine
│   │   └── history.ts                    # History persistence store
│   │
│   ├── hooks/
│   │   ├── useHotkey.ts                  # Hotkey event listener from Rust
│   │   └── usePipeline.ts               # Pipeline execution orchestrator hook
│   │
│   ├── windows/
│   │   ├── floating/
│   │   │   ├── FloatingWindow.tsx        # Floating window root
│   │   │   ├── Pill.tsx                  # Compact pill widget
│   │   │   ├── Bubble.tsx                # Expanded result bubble
│   │   │   └── Waveform.tsx              # Mini waveform animation
│   │   ├── settings/
│   │   │   ├── SettingsWindow.tsx        # Settings window root + sidebar
│   │   │   ├── ScenesPage.tsx            # Scene list
│   │   │   ├── SceneEditor.tsx           # Scene detail editor
│   │   │   ├── ProvidersPage.tsx         # Provider config (STT + LLM)
│   │   │   ├── GeneralPage.tsx           # Global hotkeys, behavior, data
│   │   │   └── AboutPage.tsx             # Version, links
│   │   └── history/
│   │       ├── HistoryWindow.tsx          # History window root
│   │       └── HistoryItem.tsx            # Single history record row
│   │
│   └── styles/
│       ├── tokens.css                    # Design system CSS variables
│       └── global.css                    # Base styles
│
├── src-tauri/
│   ├── Cargo.toml
│   ├── build.rs
│   ├── tauri.conf.json
│   ├── capabilities/
│   │   └── default.json
│   └── src/
│       ├── main.rs                       # Tauri entry
│       ├── lib.rs                        # Plugin/command registration
│       ├── config.rs                     # Config file R/W commands
│       ├── hotkey.rs                     # Global hotkey listener
│       ├── output.rs                     # Simulated input + clipboard
│       └── tray.rs                       # System tray menu
│
└── tests/
    ├── config.test.ts                    # Config store tests
    ├── pipeline.test.ts                  # Pipeline engine tests
    ├── adapters/
    │   ├── stt-registry.test.ts          # STT registry tests
    │   └── llm-registry.test.ts          # LLM registry tests
    ├── stores/
    │   ├── recording.test.ts             # Recording state machine tests
    │   └── history.test.ts               # History store tests
    └── i18n/
        └── i18n.test.ts                  # i18n completeness tests
```

---

## Task 1: Project Scaffolding

**Files:**
- Create: `package.json`, `tsconfig.json`, `tsconfig.node.json`, `vite.config.ts`, `vitest.config.ts`, `index.html`, `.gitignore`, `src/main.tsx`, `src/App.tsx`, `src/styles/tokens.css`, `src/styles/global.css`
- Create: `src-tauri/Cargo.toml`, `src-tauri/tauri.conf.json`, `src-tauri/build.rs`, `src-tauri/capabilities/default.json`, `src-tauri/src/main.rs`, `src-tauri/src/lib.rs`

- [ ] **Step 1: Initialize Tauri 2 + React + TypeScript project**

```bash
npm create tauri-app@latest . -- --template react-ts --manager npm
```

If prompted about existing files, choose to continue (only DESIGN.md and docs/ exist). This creates the standard Tauri 2 scaffold.

- [ ] **Step 2: Install additional frontend dependencies**

```bash
npm install zustand i18next react-i18next
npm install -D vitest @testing-library/react @testing-library/jest-dom jsdom
```

- [ ] **Step 3: Create `.gitignore`**

```gitignore
# Dependencies
node_modules/

# Build
dist/
src-tauri/target/

# IDE
.vscode/
.idea/

# OS
.DS_Store
Thumbs.db

# Tauri
src-tauri/gen/

# Superpowers brainstorm artifacts
.superpowers/

# Playwright MCP artifacts
.playwright-mcp/
```

- [ ] **Step 4: Create `vitest.config.ts`**

```typescript
import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    globals: true,
    environment: 'jsdom',
    setupFiles: [],
    include: ['tests/**/*.test.ts', 'tests/**/*.test.tsx'],
  },
})
```

- [ ] **Step 5: Create `src/styles/tokens.css`**

Extract design tokens from DESIGN.md into CSS custom properties:

```css
:root {
  /* Primary */
  --color-near-black: #141413;
  --color-terracotta: #c96442;
  --color-coral: #d97757;

  /* Surface */
  --color-parchment: #f5f4ed;
  --color-ivory: #faf9f5;
  --color-white: #ffffff;
  --color-warm-sand: #e8e6dc;
  --color-dark-surface: #30302e;

  /* Text */
  --color-charcoal-warm: #4d4c48;
  --color-olive-gray: #5e5d59;
  --color-stone-gray: #87867f;
  --color-dark-warm: #3d3d3a;
  --color-warm-silver: #b0aea5;

  /* Border */
  --color-border-cream: #f0eee6;
  --color-border-warm: #e8e6dc;
  --color-border-dark: #30302e;

  /* Ring / Shadow */
  --color-ring-warm: #d1cfc5;
  --color-ring-deep: #c2c0b6;

  /* Semantic */
  --color-success: #4a9e6e;
  --color-error: #b53333;
  --color-focus-blue: #3898ec;

  /* Typography */
  --font-serif: Georgia, 'Times New Roman', serif;
  --font-sans: -apple-system, 'Segoe UI', system-ui, sans-serif;
  --font-mono: 'SF Mono', 'Fira Code', 'Cascadia Code', monospace;

  /* Radius */
  --radius-sm: 6px;
  --radius-md: 8px;
  --radius-lg: 12px;
  --radius-xl: 16px;
  --radius-pill: 999px;

  /* Shadow */
  --shadow-ring: 0px 0px 0px 1px;
  --shadow-whisper: 0px 4px 24px rgba(0, 0, 0, 0.05);
}
```

- [ ] **Step 6: Create `src/styles/global.css`**

```css
@import './tokens.css';

* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

body {
  font-family: var(--font-sans);
  color: var(--color-near-black);
  background: transparent;
  -webkit-font-smoothing: antialiased;
}

/* Prevent text selection in the floating window */
.floating-window {
  user-select: none;
  -webkit-user-select: none;
}

/* Allow text selection in settings and history */
.settings-window,
.history-window {
  user-select: text;
}
```

- [ ] **Step 7: Update `src/main.tsx`**

Replace the generated main.tsx:

```tsx
import React from 'react'
import ReactDOM from 'react-dom/client'
import { App } from './App'
import './styles/global.css'

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
)
```

- [ ] **Step 8: Create `src/App.tsx`**

```tsx
export function App() {
  // Window type is determined by the Tauri window label
  // For now, render a placeholder
  return <div>Verbo</div>
}
```

- [ ] **Step 9: Update Tauri config for multi-window**

Edit `src-tauri/tauri.conf.json` — set the main window as the floating window (small, frameless, always-on-top) and register additional windows for settings and history:

```json
{
  "$schema": "https://raw.githubusercontent.com/nicehash/tauri-v2-schema/main/tauri.conf.json",
  "productName": "Verbo",
  "version": "0.1.0",
  "identifier": "com.verbo.app",
  "build": {
    "frontendDist": "../dist",
    "devUrl": "http://localhost:1420",
    "beforeDevCommand": "npm run dev",
    "beforeBuildCommand": "npm run build"
  },
  "app": {
    "withGlobalTauri": true,
    "windows": [
      {
        "label": "floating",
        "title": "Verbo",
        "width": 340,
        "height": 200,
        "decorations": false,
        "transparent": true,
        "alwaysOnTop": true,
        "resizable": false,
        "skipTaskbar": true,
        "visible": true,
        "x": 100,
        "y": 100
      }
    ]
  }
}
```

- [ ] **Step 10: Add Rust dependencies to `src-tauri/Cargo.toml`**

Append to `[dependencies]`:

```toml
serde = { version = "1", features = ["derive"] }
serde_json = "1"
tauri = { version = "2", features = ["tray-icon"] }
tauri-plugin-global-shortcut = "2"
tauri-plugin-clipboard-manager = "2"
arboard = "3"
dirs = "6"
```

- [ ] **Step 11: Verify build**

```bash
npm run tauri dev
```

Expected: Tauri window opens with "Verbo" text. Close it after confirming.

- [ ] **Step 12: Run test infrastructure check**

Add to `package.json` scripts:

```json
{
  "scripts": {
    "test": "vitest run",
    "test:watch": "vitest"
  }
}
```

Create a smoke test `tests/smoke.test.ts`:

```typescript
import { describe, it, expect } from 'vitest'

describe('smoke', () => {
  it('test infrastructure works', () => {
    expect(1 + 1).toBe(2)
  })
})
```

Run: `npm test`
Expected: 1 test passes.

- [ ] **Step 13: Commit**

```bash
git add package.json tsconfig.json tsconfig.node.json vite.config.ts vitest.config.ts index.html .gitignore src/ src-tauri/ tests/smoke.test.ts
git commit -m "chore: scaffold Tauri 2 + React + TypeScript project"
```

---

## Task 2: Core Types

**Files:**
- Create: `src/types/config.ts`, `src/types/pipeline.ts`, `src/types/history.ts`

- [ ] **Step 1: Create pipeline types**

```typescript
// src/types/pipeline.ts

export interface STTStep {
  readonly type: 'stt'
  readonly provider: string
  readonly lang: string
}

export interface LLMStep {
  readonly type: 'llm'
  readonly provider: string
  readonly prompt: string
}

export type PipelineStep = STTStep | LLMStep

export interface SceneHotkey {
  readonly toggleRecord: string | null
  readonly pushToTalk: string | null
}

export type OutputMode = 'simulate' | 'clipboard'

export interface Scene {
  readonly id: string
  readonly name: string
  readonly hotkey: SceneHotkey
  readonly pipeline: readonly PipelineStep[]
  readonly output: OutputMode
}

export type PipelineState =
  | { readonly status: 'idle' }
  | { readonly status: 'recording'; readonly startedAt: number }
  | { readonly status: 'transcribing'; readonly partialText: string }
  | { readonly status: 'processing'; readonly sourceText: string; readonly partialResult: string }
  | { readonly status: 'done'; readonly sourceText: string; readonly finalText: string }
  | { readonly status: 'error'; readonly message: string }
```

- [ ] **Step 2: Create config types**

```typescript
// src/types/config.ts

import type { Scene, OutputMode } from './pipeline'

export interface GlobalHotkey {
  readonly toggleRecord: string
  readonly pushToTalk: string
}

export interface STTProviderConfig {
  readonly [key: string]: unknown
  readonly enabledLangs: readonly string[]
}

export interface LLMProviderConfig {
  readonly apiKey: string
  readonly model: string
  readonly baseUrl: string
}

export interface ProvidersConfig {
  readonly stt: Readonly<Record<string, STTProviderConfig>>
  readonly llm: Readonly<Record<string, LLMProviderConfig>>
}

export interface GeneralConfig {
  readonly defaultOutput: OutputMode
  readonly autoCollapseDelay: number
  readonly launchAtStartup: boolean
  readonly language: 'system' | 'zh-CN' | 'en'
  readonly historyRetentionDays: number
}

export interface AppConfig {
  readonly version: number
  readonly defaultScene: string
  readonly globalHotkey: GlobalHotkey
  readonly scenes: readonly Scene[]
  readonly providers: ProvidersConfig
  readonly general: GeneralConfig
}
```

- [ ] **Step 3: Create history types**

```typescript
// src/types/history.ts

export type OutputStatus = 'inserted' | 'copied' | 'failed'

export interface HistoryRecord {
  readonly id: string
  readonly timestamp: number
  readonly sceneId: string
  readonly sceneName: string
  readonly originalText: string
  readonly finalText: string
  readonly outputStatus: OutputStatus
  readonly pipelineSteps: readonly string[]
}
```

- [ ] **Step 4: Commit**

```bash
git add src/types/
git commit -m "feat: add core type definitions for config, pipeline, and history"
```

---

## Task 3: Config System

**Files:**
- Create: `src/config/defaults.ts`, `src/config/store.ts`, `tests/config.test.ts`

- [ ] **Step 1: Write failing tests for config defaults and store**

```typescript
// tests/config.test.ts
import { describe, it, expect } from 'vitest'
import { DEFAULT_CONFIG } from '../src/config/defaults'
import type { AppConfig } from '../src/types/config'

describe('DEFAULT_CONFIG', () => {
  it('has version 1', () => {
    expect(DEFAULT_CONFIG.version).toBe(1)
  })

  it('has a default scene pointing to dictate', () => {
    expect(DEFAULT_CONFIG.defaultScene).toBe('dictate')
  })

  it('includes a dictate scene with stt-only pipeline', () => {
    const dictate = DEFAULT_CONFIG.scenes.find(s => s.id === 'dictate')
    expect(dictate).toBeDefined()
    expect(dictate!.pipeline).toHaveLength(1)
    expect(dictate!.pipeline[0].type).toBe('stt')
  })

  it('includes a polish scene with stt + llm pipeline', () => {
    const polish = DEFAULT_CONFIG.scenes.find(s => s.id === 'polish')
    expect(polish).toBeDefined()
    expect(polish!.pipeline).toHaveLength(2)
    expect(polish!.pipeline[0].type).toBe('stt')
    expect(polish!.pipeline[1].type).toBe('llm')
  })

  it('has iflytek STT provider with zh and en enabled', () => {
    const iflytek = DEFAULT_CONFIG.providers.stt['iflytek']
    expect(iflytek).toBeDefined()
    expect(iflytek.enabledLangs).toContain('zh')
    expect(iflytek.enabledLangs).toContain('en')
  })

  it('has openai LLM provider', () => {
    const openai = DEFAULT_CONFIG.providers.llm['openai']
    expect(openai).toBeDefined()
    expect(openai.baseUrl).toBe('https://api.openai.com/v1')
  })

  it('has general config with sensible defaults', () => {
    expect(DEFAULT_CONFIG.general.defaultOutput).toBe('simulate')
    expect(DEFAULT_CONFIG.general.autoCollapseDelay).toBe(1500)
    expect(DEFAULT_CONFIG.general.language).toBe('system')
  })
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm test -- tests/config.test.ts`
Expected: FAIL — `DEFAULT_CONFIG` not found

- [ ] **Step 3: Implement config defaults**

```typescript
// src/config/defaults.ts
import type { AppConfig } from '../types/config'

export const DEFAULT_CONFIG: AppConfig = {
  version: 1,
  defaultScene: 'dictate',
  globalHotkey: {
    toggleRecord: 'CommandOrControl+Shift+H',
    pushToTalk: 'CommandOrControl+Shift+G',
  },
  scenes: [
    {
      id: 'dictate',
      name: '语音输入',
      hotkey: { toggleRecord: 'Alt+D', pushToTalk: null },
      pipeline: [{ type: 'stt', provider: 'iflytek', lang: 'zh' }],
      output: 'simulate',
    },
    {
      id: 'polish',
      name: '润色输入',
      hotkey: { toggleRecord: 'Alt+J', pushToTalk: null },
      pipeline: [
        { type: 'stt', provider: 'iflytek', lang: 'zh' },
        {
          type: 'llm',
          provider: 'openai',
          prompt: '请润色以下口语化文字，使其更书面化，保持原意，直接输出结果：\n{{input}}',
        },
      ],
      output: 'simulate',
    },
    {
      id: 'translate',
      name: '中译英',
      hotkey: { toggleRecord: 'Alt+T', pushToTalk: null },
      pipeline: [
        { type: 'stt', provider: 'iflytek', lang: 'zh' },
        {
          type: 'llm',
          provider: 'openai',
          prompt: '将以下中文翻译为英文，直接输出翻译结果：\n{{input}}',
        },
      ],
      output: 'simulate',
    },
  ],
  providers: {
    stt: {
      iflytek: {
        appId: '',
        apiKey: '',
        apiSecret: '',
        enabledLangs: ['zh', 'en'],
      },
    },
    llm: {
      openai: {
        apiKey: '',
        model: 'gpt-4o-mini',
        baseUrl: 'https://api.openai.com/v1',
      },
    },
  },
  general: {
    defaultOutput: 'simulate',
    autoCollapseDelay: 1500,
    launchAtStartup: false,
    language: 'system',
    historyRetentionDays: 30,
  },
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm test -- tests/config.test.ts`
Expected: All tests PASS

- [ ] **Step 5: Create Zustand config store**

```typescript
// src/config/store.ts
import { create } from 'zustand'
import type { AppConfig } from '../types/config'
import type { Scene } from '../types/pipeline'
import { DEFAULT_CONFIG } from './defaults'

interface ConfigState {
  readonly config: AppConfig
  readonly setConfig: (config: AppConfig) => void
  readonly updateScene: (sceneId: string, updates: Partial<Scene>) => void
  readonly getScene: (sceneId: string) => Scene | undefined
  readonly getDefaultScene: () => Scene | undefined
}

export const useConfigStore = create<ConfigState>((set, get) => ({
  config: DEFAULT_CONFIG,

  setConfig: (config) => set({ config }),

  updateScene: (sceneId, updates) => {
    const { config } = get()
    const scenes = config.scenes.map((s) =>
      s.id === sceneId ? { ...s, ...updates } : s
    )
    set({ config: { ...config, scenes } })
  },

  getScene: (sceneId) => {
    return get().config.scenes.find((s) => s.id === sceneId)
  },

  getDefaultScene: () => {
    const { config } = get()
    return config.scenes.find((s) => s.id === config.defaultScene)
  },
}))
```

- [ ] **Step 6: Commit**

```bash
git add src/config/ tests/config.test.ts
git commit -m "feat: add config defaults and Zustand config store"
```

---

## Task 4: i18n Setup

**Files:**
- Create: `src/i18n/index.ts`, `src/i18n/zh-CN.ts`, `src/i18n/en.ts`, `tests/i18n/i18n.test.ts`

- [ ] **Step 1: Write failing test for i18n key completeness**

```typescript
// tests/i18n/i18n.test.ts
import { describe, it, expect } from 'vitest'
import { zhCN } from '../../src/i18n/zh-CN'
import { en } from '../../src/i18n/en'

function flattenKeys(obj: Record<string, unknown>, prefix = ''): string[] {
  return Object.entries(obj).flatMap(([key, value]) => {
    const fullKey = prefix ? `${prefix}.${key}` : key
    if (typeof value === 'object' && value !== null) {
      return flattenKeys(value as Record<string, unknown>, fullKey)
    }
    return [fullKey]
  })
}

describe('i18n', () => {
  it('zh-CN and en have the same keys', () => {
    const zhKeys = flattenKeys(zhCN).sort()
    const enKeys = flattenKeys(en).sort()
    expect(zhKeys).toEqual(enKeys)
  })

  it('has floating window keys', () => {
    const keys = flattenKeys(en)
    expect(keys).toContain('floating.ready')
    expect(keys).toContain('floating.listening')
    expect(keys).toContain('floating.done')
    expect(keys).toContain('floating.error')
    expect(keys).toContain('floating.copy')
    expect(keys).toContain('floating.retry')
    expect(keys).toContain('floating.inserted')
    expect(keys).toContain('floating.copied')
  })

  it('has settings keys', () => {
    const keys = flattenKeys(en)
    expect(keys).toContain('settings.title')
    expect(keys).toContain('settings.scenes')
    expect(keys).toContain('settings.providers')
    expect(keys).toContain('settings.general')
    expect(keys).toContain('settings.about')
  })

  it('has history keys', () => {
    const keys = flattenKeys(en)
    expect(keys).toContain('history.title')
    expect(keys).toContain('history.search')
    expect(keys).toContain('history.allScenes')
    expect(keys).toContain('history.clearAll')
  })
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm test -- tests/i18n/i18n.test.ts`
Expected: FAIL — modules not found

- [ ] **Step 3: Create zh-CN translations**

```typescript
// src/i18n/zh-CN.ts
export const zhCN = {
  floating: {
    ready: '就绪',
    listening: '聆听中...',
    processing: '处理中',
    polishing: '润色中',
    translating: '翻译中',
    done: '完成',
    error: '错误',
    offline: '离线',
    copy: '复制',
    retry: '重试',
    settings: '设置',
    inserted: '已输入',
    copied: '已复制',
    failed: '输入失败',
  },
  settings: {
    title: '设置',
    scenes: '场景',
    providers: '服务商',
    general: '通用',
    about: '关于',
    scenesDesc: '管理语音输入工作流和快捷键',
    newScene: '新建场景',
    defaultBadge: '默认',
    sceneName: '场景名称',
    pipelineSteps: '管道步骤',
    addStep: '添加管道步骤',
    outputMode: '输出方式',
    simulateInput: '模拟输入',
    clipboard: '剪贴板',
    hotkeyToggle: '快捷键（切换模式）',
    hotkeyPush: '快捷键（按住说话）',
    clickToRecord: '点击录制...',
    save: '保存',
    cancel: '取消',
    providersDesc: '管理语音识别和大模型的 API 配置',
    sttSection: '语音识别 (STT)',
    llmSection: '大语言模型 (LLM)',
    connected: '已连接',
    supportedLangs: '支持的语种',
    supportedLangsHint: '选择此引擎启用的语种，场景中可使用已启用的语种',
    addSttProvider: '添加语音识别引擎',
    addLlmProvider: '添加大模型服务商',
    generalDesc: '全局行为和偏好配置',
    globalHotkeys: '全局快捷键',
    globalHotkeysHint: '触发默认场景的全局快捷键，场景级快捷键在「场景」中配置',
    behavior: '行为',
    defaultOutputMode: '默认输出方式',
    autoCollapseDelay: '结果自动收回延时',
    launchAtStartup: '开机自启动',
    uiLanguage: '界面语言',
    followSystem: '跟随系统',
    data: '数据',
    historyRetention: '历史记录保留天数',
    configPath: '配置文件路径',
    forever: '永久',
    enabled: '开启',
    disabled: '关闭',
    aboutVersion: '版本',
  },
  history: {
    title: '输入历史',
    search: '搜索内容...',
    allScenes: '全部场景',
    today: '今天',
    yesterday: '昨天',
    copy: '复制',
    viewOriginal: '查看原文',
    clearAll: '清空历史',
    records: '条记录',
    inserted: '已输入',
    copied: '已复制',
    failed: '输入失败',
  },
  tray: {
    history: '输入历史',
    settings: '设置',
    quit: '退出',
  },
  stt: {
    speechToText: '语音识别',
  },
  llm: {
    llmTransform: 'LLM 处理',
    promptHint: '使用 {{input}} 引用上一步输出',
  },
  common: {
    engine: '引擎',
    language: '语种',
    provider: '服务商',
    model: '模型',
  },
} as const
```

- [ ] **Step 4: Create en translations**

```typescript
// src/i18n/en.ts
export const en = {
  floating: {
    ready: 'Ready',
    listening: 'Listening...',
    processing: 'Processing',
    polishing: 'Polishing',
    translating: 'Translating',
    done: 'Done',
    error: 'Error',
    offline: 'Offline',
    copy: 'Copy',
    retry: 'Retry',
    settings: 'Settings',
    inserted: 'Inserted',
    copied: 'Copied',
    failed: 'Insert failed',
  },
  settings: {
    title: 'Settings',
    scenes: 'Scenes',
    providers: 'Providers',
    general: 'General',
    about: 'About',
    scenesDesc: 'Manage voice input workflows and hotkeys',
    newScene: 'New Scene',
    defaultBadge: 'Default',
    sceneName: 'Scene Name',
    pipelineSteps: 'Pipeline Steps',
    addStep: 'Add Pipeline Step',
    outputMode: 'Output Mode',
    simulateInput: 'Simulate Input',
    clipboard: 'Clipboard',
    hotkeyToggle: 'Hotkey (Toggle)',
    hotkeyPush: 'Hotkey (Push-to-Talk)',
    clickToRecord: 'Click to record...',
    save: 'Save',
    cancel: 'Cancel',
    providersDesc: 'Manage API credentials for speech recognition and LLM services',
    sttSection: 'Speech to Text (STT)',
    llmSection: 'Large Language Model (LLM)',
    connected: 'Connected',
    supportedLangs: 'Supported Languages',
    supportedLangsHint: 'Select languages enabled for this engine. Scenes can use any enabled language.',
    addSttProvider: 'Add STT Provider',
    addLlmProvider: 'Add LLM Provider',
    generalDesc: 'Global behavior and preferences',
    globalHotkeys: 'Global Hotkeys',
    globalHotkeysHint: 'Global hotkeys trigger the default scene. Scene-level hotkeys are configured in Scenes.',
    behavior: 'Behavior',
    defaultOutputMode: 'Default Output Mode',
    autoCollapseDelay: 'Auto-collapse Delay',
    launchAtStartup: 'Launch at Startup',
    uiLanguage: 'UI Language',
    followSystem: 'Follow System',
    data: 'Data',
    historyRetention: 'History Retention',
    configPath: 'Config File Path',
    forever: 'Forever',
    enabled: 'Enabled',
    disabled: 'Disabled',
    aboutVersion: 'Version',
  },
  history: {
    title: 'Input History',
    search: 'Search...',
    allScenes: 'All Scenes',
    today: 'Today',
    yesterday: 'Yesterday',
    copy: 'Copy',
    viewOriginal: 'View original',
    clearAll: 'Clear All',
    records: 'records',
    inserted: 'Inserted',
    copied: 'Copied',
    failed: 'Insert failed',
  },
  tray: {
    history: 'History',
    settings: 'Settings',
    quit: 'Quit',
  },
  stt: {
    speechToText: 'Speech to Text',
  },
  llm: {
    llmTransform: 'LLM Transform',
    promptHint: 'Use {{input}} for previous step output',
  },
  common: {
    engine: 'Engine',
    language: 'Language',
    provider: 'Provider',
    model: 'Model',
  },
} as const
```

- [ ] **Step 5: Create i18n initializer**

```typescript
// src/i18n/index.ts
import i18n from 'i18next'
import { initReactI18next } from 'react-i18next'
import { zhCN } from './zh-CN'
import { en } from './en'

export function initI18n(language: 'system' | 'zh-CN' | 'en') {
  const lng =
    language === 'system'
      ? navigator.language.startsWith('zh') ? 'zh-CN' : 'en'
      : language

  return i18n.use(initReactI18next).init({
    resources: {
      'zh-CN': { translation: zhCN },
      en: { translation: en },
    },
    lng,
    fallbackLng: 'en',
    interpolation: { escapeValue: false },
  })
}
```

- [ ] **Step 6: Run test to verify it passes**

Run: `npm test -- tests/i18n/i18n.test.ts`
Expected: All tests PASS

- [ ] **Step 7: Commit**

```bash
git add src/i18n/ tests/i18n/
git commit -m "feat: add i18n with zh-CN and en translations"
```

---

## Task 5: STT Adapter Interface + iFlytek Implementation

**Files:**
- Create: `src/adapters/stt/types.ts`, `src/adapters/stt/registry.ts`, `src/adapters/stt/iflytek.ts`, `tests/adapters/stt-registry.test.ts`

- [ ] **Step 1: Write failing tests for STT registry**

```typescript
// tests/adapters/stt-registry.test.ts
import { describe, it, expect } from 'vitest'
import { createSTTRegistry } from '../../src/adapters/stt/registry'
import type { STTAdapter } from '../../src/adapters/stt/types'

function createMockAdapter(name: string, streaming = false): STTAdapter {
  return {
    name,
    capabilities: { streaming },
    transcribe: async () => 'mock result',
  }
}

describe('STT Registry', () => {
  it('registers and retrieves an adapter', () => {
    const registry = createSTTRegistry()
    const adapter = createMockAdapter('test-stt')
    registry.register(adapter)
    expect(registry.get('test-stt')).toBe(adapter)
  })

  it('returns undefined for unknown adapter', () => {
    const registry = createSTTRegistry()
    expect(registry.get('nonexistent')).toBeUndefined()
  })

  it('lists registered adapter names', () => {
    const registry = createSTTRegistry()
    registry.register(createMockAdapter('a'))
    registry.register(createMockAdapter('b'))
    expect(registry.list()).toEqual(['a', 'b'])
  })
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm test -- tests/adapters/stt-registry.test.ts`
Expected: FAIL — modules not found

- [ ] **Step 3: Create STT adapter interface**

```typescript
// src/adapters/stt/types.ts
export interface STTOptions {
  readonly lang: string
}

export interface STTAdapter {
  readonly name: string
  readonly capabilities: {
    readonly streaming: boolean
  }
  transcribe(audio: ArrayBuffer, options: STTOptions): Promise<string>
  transcribeStream?(
    audioStream: ReadableStream<ArrayBuffer>,
    options: STTOptions,
    onPartial: (text: string) => void,
  ): Promise<string>
}
```

- [ ] **Step 4: Create STT registry**

```typescript
// src/adapters/stt/registry.ts
import type { STTAdapter } from './types'

export interface STTRegistry {
  register(adapter: STTAdapter): void
  get(name: string): STTAdapter | undefined
  list(): string[]
}

export function createSTTRegistry(): STTRegistry {
  const adapters = new Map<string, STTAdapter>()

  return {
    register(adapter) {
      adapters.set(adapter.name, adapter)
    },
    get(name) {
      return adapters.get(name)
    },
    list() {
      return Array.from(adapters.keys())
    },
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `npm test -- tests/adapters/stt-registry.test.ts`
Expected: All tests PASS

- [ ] **Step 6: Create iFlytek streaming adapter**

```typescript
// src/adapters/stt/iflytek.ts
import type { STTAdapter, STTOptions } from './types'

interface IFlytekConfig {
  readonly appId: string
  readonly apiKey: string
  readonly apiSecret: string
}

function buildAuthUrl(config: IFlytekConfig): string {
  const host = 'iat-api.xfyun.cn'
  const path = '/v2/iat'
  const date = new Date().toUTCString()

  // HMAC-SHA256 signature for iFlytek WebSocket auth
  // In browser, use SubtleCrypto API
  const signatureOrigin = `host: ${host}\ndate: ${date}\nGET ${path} HTTP/1.1`

  // This will be implemented with Web Crypto API
  // For now, return the base URL structure
  return `wss://${host}${path}?authorization=AUTH&date=${encodeURIComponent(date)}&host=${host}`
}

async function hmacSha256Base64(key: string, message: string): Promise<string> {
  const encoder = new TextEncoder()
  const cryptoKey = await crypto.subtle.importKey(
    'raw',
    encoder.encode(key),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  )
  const signature = await crypto.subtle.sign('HMAC', cryptoKey, encoder.encode(message))
  return btoa(String.fromCharCode(...new Uint8Array(signature)))
}

async function buildIFlytekAuthUrl(config: IFlytekConfig): Promise<string> {
  const host = 'iat-api.xfyun.cn'
  const path = '/v2/iat'
  const date = new Date().toUTCString()
  const signatureOrigin = `host: ${host}\ndate: ${date}\nGET ${path} HTTP/1.1`

  const signature = await hmacSha256Base64(config.apiSecret, signatureOrigin)
  const authorizationOrigin = `api_key="${config.apiKey}", algorithm="hmac-sha256", headers="host date request-line", signature="${signature}"`
  const authorization = btoa(authorizationOrigin)

  return `wss://${host}${path}?authorization=${authorization}&date=${encodeURIComponent(date)}&host=${host}`
}

const LANG_MAP: Record<string, string> = {
  zh: 'cn_mandarin',
  en: 'en_us',
}

export function createIFlytekAdapter(config: IFlytekConfig): STTAdapter {
  return {
    name: 'iflytek',
    capabilities: { streaming: true },

    async transcribe(audio: ArrayBuffer, options: STTOptions): Promise<string> {
      // Batch mode: open WebSocket, send all audio, collect result
      return new Promise(async (resolve, reject) => {
        const url = await buildIFlytekAuthUrl(config)
        const ws = new WebSocket(url)
        let result = ''

        ws.onopen = () => {
          const frameSize = 1280
          const audioData = new Uint8Array(audio)
          const language = LANG_MAP[options.lang] ?? 'cn_mandarin'

          // Send first frame with params
          const firstFrame = {
            common: { app_id: config.appId },
            business: { language, domain: 'iat', accent: language === 'cn_mandarin' ? 'mandarin' : '', vad_eos: 3000 },
            data: { status: 0, format: 'audio/L16;rate=16000', encoding: 'raw', audio: arrayBufferToBase64(audioData.slice(0, frameSize)) },
          }
          ws.send(JSON.stringify(firstFrame))

          // Send middle frames
          let offset = frameSize
          while (offset < audioData.length - frameSize) {
            const chunk = audioData.slice(offset, offset + frameSize)
            ws.send(JSON.stringify({ data: { status: 1, format: 'audio/L16;rate=16000', encoding: 'raw', audio: arrayBufferToBase64(chunk) } }))
            offset += frameSize
          }

          // Send last frame
          const lastChunk = audioData.slice(offset)
          ws.send(JSON.stringify({ data: { status: 2, format: 'audio/L16;rate=16000', encoding: 'raw', audio: arrayBufferToBase64(lastChunk) } }))
        }

        ws.onmessage = (event) => {
          const response = JSON.parse(event.data)
          if (response.code !== 0) {
            reject(new Error(`iFlytek error: ${response.message}`))
            ws.close()
            return
          }
          const words = response.data?.result?.ws ?? []
          for (const w of words) {
            for (const cw of w.cw) {
              result += cw.w
            }
          }
          if (response.data?.status === 2) {
            ws.close()
            resolve(result)
          }
        }

        ws.onerror = (err) => reject(new Error(`WebSocket error: ${err}`))
      })
    },

    async transcribeStream(
      audioStream: ReadableStream<ArrayBuffer>,
      options: STTOptions,
      onPartial: (text: string) => void,
    ): Promise<string> {
      return new Promise(async (resolve, reject) => {
        const url = await buildIFlytekAuthUrl(config)
        const ws = new WebSocket(url)
        let fullResult = ''
        let isFirstFrame = true
        const language = LANG_MAP[options.lang] ?? 'cn_mandarin'

        ws.onopen = async () => {
          const reader = audioStream.getReader()

          try {
            while (true) {
              const { done, value } = await reader.read()
              if (done) {
                // Send last frame marker
                ws.send(JSON.stringify({ data: { status: 2, format: 'audio/L16;rate=16000', encoding: 'raw', audio: '' } }))
                break
              }

              const audio = arrayBufferToBase64(new Uint8Array(value))

              if (isFirstFrame) {
                ws.send(JSON.stringify({
                  common: { app_id: config.appId },
                  business: { language, domain: 'iat', accent: language === 'cn_mandarin' ? 'mandarin' : '', vad_eos: 3000 },
                  data: { status: 0, format: 'audio/L16;rate=16000', encoding: 'raw', audio },
                }))
                isFirstFrame = false
              } else {
                ws.send(JSON.stringify({ data: { status: 1, format: 'audio/L16;rate=16000', encoding: 'raw', audio } }))
              }
            }
          } catch (err) {
            reject(err)
          }
        }

        ws.onmessage = (event) => {
          const response = JSON.parse(event.data)
          if (response.code !== 0) {
            reject(new Error(`iFlytek error: ${response.message}`))
            ws.close()
            return
          }
          const words = response.data?.result?.ws ?? []
          for (const w of words) {
            for (const cw of w.cw) {
              fullResult += cw.w
            }
          }
          onPartial(fullResult)

          if (response.data?.status === 2) {
            ws.close()
            resolve(fullResult)
          }
        }

        ws.onerror = (err) => reject(new Error(`WebSocket error: ${err}`))
      })
    },
  }
}

function arrayBufferToBase64(bytes: Uint8Array): string {
  let binary = ''
  for (let i = 0; i < bytes.byteLength; i++) {
    binary += String.fromCharCode(bytes[i])
  }
  return btoa(binary)
}
```

- [ ] **Step 7: Commit**

```bash
git add src/adapters/stt/ tests/adapters/stt-registry.test.ts
git commit -m "feat: add STT adapter interface, registry, and iFlytek streaming adapter"
```

---

## Task 6: LLM Adapter Interface + OpenAI Implementation

**Files:**
- Create: `src/adapters/llm/types.ts`, `src/adapters/llm/registry.ts`, `src/adapters/llm/openai.ts`, `tests/adapters/llm-registry.test.ts`

- [ ] **Step 1: Write failing tests for LLM registry**

```typescript
// tests/adapters/llm-registry.test.ts
import { describe, it, expect } from 'vitest'
import { createLLMRegistry } from '../../src/adapters/llm/registry'
import type { LLMAdapter } from '../../src/adapters/llm/types'

function createMockAdapter(name: string): LLMAdapter {
  return {
    name,
    complete: async () => 'mock result',
  }
}

describe('LLM Registry', () => {
  it('registers and retrieves an adapter', () => {
    const registry = createLLMRegistry()
    const adapter = createMockAdapter('test-llm')
    registry.register(adapter)
    expect(registry.get('test-llm')).toBe(adapter)
  })

  it('returns undefined for unknown adapter', () => {
    const registry = createLLMRegistry()
    expect(registry.get('nonexistent')).toBeUndefined()
  })

  it('lists registered adapter names', () => {
    const registry = createLLMRegistry()
    registry.register(createMockAdapter('a'))
    registry.register(createMockAdapter('b'))
    expect(registry.list()).toEqual(['a', 'b'])
  })
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm test -- tests/adapters/llm-registry.test.ts`
Expected: FAIL — modules not found

- [ ] **Step 3: Create LLM adapter interface and registry**

```typescript
// src/adapters/llm/types.ts
export interface LLMOptions {
  readonly prompt: string
  readonly model?: string
}

export interface LLMAdapter {
  readonly name: string
  complete(options: LLMOptions): Promise<string>
  completeStream?(
    options: LLMOptions,
    onChunk: (text: string) => void,
  ): Promise<string>
}
```

```typescript
// src/adapters/llm/registry.ts
import type { LLMAdapter } from './types'

export interface LLMRegistry {
  register(adapter: LLMAdapter): void
  get(name: string): LLMAdapter | undefined
  list(): string[]
}

export function createLLMRegistry(): LLMRegistry {
  const adapters = new Map<string, LLMAdapter>()

  return {
    register(adapter) {
      adapters.set(adapter.name, adapter)
    },
    get(name) {
      return adapters.get(name)
    },
    list() {
      return Array.from(adapters.keys())
    },
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm test -- tests/adapters/llm-registry.test.ts`
Expected: All tests PASS

- [ ] **Step 5: Create OpenAI-compatible adapter**

```typescript
// src/adapters/llm/openai.ts
import type { LLMAdapter, LLMOptions } from './types'

interface OpenAIConfig {
  readonly apiKey: string
  readonly model: string
  readonly baseUrl: string
}

export function createOpenAIAdapter(config: OpenAIConfig): LLMAdapter {
  const headers = () => ({
    'Content-Type': 'application/json',
    Authorization: `Bearer ${config.apiKey}`,
  })

  return {
    name: 'openai',

    async complete(options: LLMOptions): Promise<string> {
      const response = await fetch(`${config.baseUrl}/chat/completions`, {
        method: 'POST',
        headers: headers(),
        body: JSON.stringify({
          model: options.model ?? config.model,
          messages: [{ role: 'user', content: options.prompt }],
          stream: false,
        }),
      })

      if (!response.ok) {
        const body = await response.text()
        throw new Error(`OpenAI API error (${response.status}): ${body}`)
      }

      const data = await response.json()
      return data.choices[0]?.message?.content ?? ''
    },

    async completeStream(
      options: LLMOptions,
      onChunk: (text: string) => void,
    ): Promise<string> {
      const response = await fetch(`${config.baseUrl}/chat/completions`, {
        method: 'POST',
        headers: headers(),
        body: JSON.stringify({
          model: options.model ?? config.model,
          messages: [{ role: 'user', content: options.prompt }],
          stream: true,
        }),
      })

      if (!response.ok) {
        const body = await response.text()
        throw new Error(`OpenAI API error (${response.status}): ${body}`)
      }

      const reader = response.body!.getReader()
      const decoder = new TextDecoder()
      let fullText = ''
      let buffer = ''

      while (true) {
        const { done, value } = await reader.read()
        if (done) break

        buffer += decoder.decode(value, { stream: true })
        const lines = buffer.split('\n')
        buffer = lines.pop() ?? ''

        for (const line of lines) {
          const trimmed = line.trim()
          if (!trimmed.startsWith('data: ')) continue
          const data = trimmed.slice(6)
          if (data === '[DONE]') continue

          try {
            const parsed = JSON.parse(data)
            const delta = parsed.choices[0]?.delta?.content
            if (delta) {
              fullText += delta
              onChunk(fullText)
            }
          } catch {
            // Skip malformed lines
          }
        }
      }

      return fullText
    },
  }
}
```

- [ ] **Step 6: Commit**

```bash
git add src/adapters/llm/ tests/adapters/llm-registry.test.ts
git commit -m "feat: add LLM adapter interface, registry, and OpenAI-compatible adapter"
```

---

## Task 7: Pipeline Engine

**Files:**
- Create: `src/engine/pipeline.ts`, `tests/pipeline.test.ts`

- [ ] **Step 1: Write failing tests for pipeline engine**

```typescript
// tests/pipeline.test.ts
import { describe, it, expect, vi } from 'vitest'
import { executePipeline } from '../src/engine/pipeline'
import type { STTAdapter } from '../src/adapters/stt/types'
import type { LLMAdapter } from '../src/adapters/llm/types'
import type { PipelineStep } from '../src/types/pipeline'

function mockSTTAdapter(result: string): STTAdapter {
  return {
    name: 'mock-stt',
    capabilities: { streaming: false },
    transcribe: vi.fn().mockResolvedValue(result),
  }
}

function mockLLMAdapter(result: string): LLMAdapter {
  return {
    name: 'mock-llm',
    complete: vi.fn().mockResolvedValue(result),
  }
}

describe('Pipeline Engine', () => {
  it('executes a single STT step', async () => {
    const stt = mockSTTAdapter('hello world')
    const steps: PipelineStep[] = [{ type: 'stt', provider: 'mock-stt', lang: 'en' }]

    const result = await executePipeline(steps, {
      audio: new ArrayBuffer(0),
      getSTT: () => stt,
      getLLM: () => undefined,
      onStateChange: vi.fn(),
    })

    expect(result).toBe('hello world')
    expect(stt.transcribe).toHaveBeenCalled()
  })

  it('executes STT then LLM, passing {{input}}', async () => {
    const stt = mockSTTAdapter('raw text')
    const llm = mockLLMAdapter('polished text')
    const steps: PipelineStep[] = [
      { type: 'stt', provider: 'mock-stt', lang: 'zh' },
      { type: 'llm', provider: 'mock-llm', prompt: 'polish: {{input}}' },
    ]

    const result = await executePipeline(steps, {
      audio: new ArrayBuffer(0),
      getSTT: () => stt,
      getLLM: () => llm,
      onStateChange: vi.fn(),
    })

    expect(result).toBe('polished text')
    expect(llm.complete).toHaveBeenCalledWith(
      expect.objectContaining({ prompt: 'polish: raw text' }),
    )
  })

  it('calls onStateChange for each phase', async () => {
    const stt = mockSTTAdapter('text')
    const onStateChange = vi.fn()
    const steps: PipelineStep[] = [{ type: 'stt', provider: 'mock-stt', lang: 'en' }]

    await executePipeline(steps, {
      audio: new ArrayBuffer(0),
      getSTT: () => stt,
      getLLM: () => undefined,
      onStateChange,
    })

    expect(onStateChange).toHaveBeenCalledWith(expect.objectContaining({ status: 'transcribing' }))
    expect(onStateChange).toHaveBeenCalledWith(expect.objectContaining({ status: 'done' }))
  })

  it('transitions to error state on adapter failure', async () => {
    const stt: STTAdapter = {
      name: 'fail-stt',
      capabilities: { streaming: false },
      transcribe: vi.fn().mockRejectedValue(new Error('API down')),
    }
    const onStateChange = vi.fn()
    const steps: PipelineStep[] = [{ type: 'stt', provider: 'fail-stt', lang: 'en' }]

    await expect(
      executePipeline(steps, {
        audio: new ArrayBuffer(0),
        getSTT: () => stt,
        getLLM: () => undefined,
        onStateChange,
      }),
    ).rejects.toThrow('API down')

    expect(onStateChange).toHaveBeenCalledWith(
      expect.objectContaining({ status: 'error', message: 'API down' }),
    )
  })

  it('throws if STT adapter not found', async () => {
    const steps: PipelineStep[] = [{ type: 'stt', provider: 'nonexistent', lang: 'en' }]

    await expect(
      executePipeline(steps, {
        audio: new ArrayBuffer(0),
        getSTT: () => undefined,
        getLLM: () => undefined,
        onStateChange: vi.fn(),
      }),
    ).rejects.toThrow('STT adapter not found: nonexistent')
  })
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm test -- tests/pipeline.test.ts`
Expected: FAIL — `executePipeline` not found

- [ ] **Step 3: Implement pipeline engine**

```typescript
// src/engine/pipeline.ts
import type { PipelineStep, PipelineState } from '../types/pipeline'
import type { STTAdapter } from '../adapters/stt/types'
import type { LLMAdapter } from '../adapters/llm/types'

export interface PipelineContext {
  readonly audio: ArrayBuffer
  readonly audioStream?: ReadableStream<ArrayBuffer>
  readonly getSTT: (name: string) => STTAdapter | undefined
  readonly getLLM: (name: string) => LLMAdapter | undefined
  readonly onStateChange: (state: PipelineState) => void
}

export async function executePipeline(
  steps: readonly PipelineStep[],
  ctx: PipelineContext,
): Promise<string> {
  let currentOutput = ''

  for (const step of steps) {
    try {
      if (step.type === 'stt') {
        currentOutput = await executeSTTStep(step, ctx)
      } else if (step.type === 'llm') {
        currentOutput = await executeLLMStep(step, currentOutput, ctx)
      }
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err)
      ctx.onStateChange({ status: 'error', message })
      throw err
    }
  }

  ctx.onStateChange({
    status: 'done',
    sourceText: currentOutput,
    finalText: currentOutput,
  })

  return currentOutput
}

async function executeSTTStep(
  step: Extract<PipelineStep, { type: 'stt' }>,
  ctx: PipelineContext,
): Promise<string> {
  const adapter = ctx.getSTT(step.provider)
  if (!adapter) {
    throw new Error(`STT adapter not found: ${step.provider}`)
  }

  ctx.onStateChange({ status: 'transcribing', partialText: '' })

  if (adapter.capabilities.streaming && adapter.transcribeStream && ctx.audioStream) {
    return adapter.transcribeStream(ctx.audioStream, { lang: step.lang }, (partial) => {
      ctx.onStateChange({ status: 'transcribing', partialText: partial })
    })
  }

  return adapter.transcribe(ctx.audio, { lang: step.lang })
}

async function executeLLMStep(
  step: Extract<PipelineStep, { type: 'llm' }>,
  input: string,
  ctx: PipelineContext,
): Promise<string> {
  const adapter = ctx.getLLM(step.provider)
  if (!adapter) {
    throw new Error(`LLM adapter not found: ${step.provider}`)
  }

  const resolvedPrompt = step.prompt.replace(/\{\{input\}\}/g, input)

  ctx.onStateChange({ status: 'processing', sourceText: input, partialResult: '' })

  if (adapter.completeStream) {
    return adapter.completeStream({ prompt: resolvedPrompt }, (partial) => {
      ctx.onStateChange({ status: 'processing', sourceText: input, partialResult: partial })
    })
  }

  return adapter.complete({ prompt: resolvedPrompt })
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm test -- tests/pipeline.test.ts`
Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add src/engine/ tests/pipeline.test.ts
git commit -m "feat: add pipeline engine with sequential step execution"
```

---

## Task 8: Audio Recorder

**Files:**
- Create: `src/audio/recorder.ts`

- [ ] **Step 1: Create audio recorder using Web Audio API**

```typescript
// src/audio/recorder.ts

export interface AudioRecorderResult {
  readonly audio: ArrayBuffer
  readonly stream: ReadableStream<ArrayBuffer>
}

export interface AudioRecorder {
  start(): Promise<ReadableStream<ArrayBuffer>>
  stop(): Promise<ArrayBuffer>
  isRecording(): boolean
}

export function createAudioRecorder(): AudioRecorder {
  let mediaStream: MediaStream | null = null
  let mediaRecorder: MediaRecorder | null = null
  let chunks: Blob[] = []
  let streamController: ReadableStreamDefaultController<ArrayBuffer> | null = null
  let recording = false

  return {
    async start(): Promise<ReadableStream<ArrayBuffer>> {
      mediaStream = await navigator.mediaDevices.getUserMedia({
        audio: {
          sampleRate: 16000,
          channelCount: 1,
          echoCancellation: true,
          noiseSuppression: true,
        },
      })

      chunks = []
      recording = true

      const stream = new ReadableStream<ArrayBuffer>({
        start(controller) {
          streamController = controller
        },
        cancel() {
          recording = false
        },
      })

      mediaRecorder = new MediaRecorder(mediaStream, {
        mimeType: 'audio/webm;codecs=opus',
      })

      mediaRecorder.ondataavailable = async (event) => {
        if (event.data.size > 0) {
          chunks.push(event.data)
          const buffer = await event.data.arrayBuffer()
          streamController?.enqueue(buffer)
        }
      }

      mediaRecorder.onstop = () => {
        streamController?.close()
        streamController = null
      }

      // Request data every 100ms for streaming
      mediaRecorder.start(100)

      return stream
    },

    async stop(): Promise<ArrayBuffer> {
      recording = false

      return new Promise((resolve) => {
        if (!mediaRecorder || mediaRecorder.state === 'inactive') {
          resolve(new ArrayBuffer(0))
          return
        }

        mediaRecorder.onstop = async () => {
          streamController?.close()
          streamController = null

          const blob = new Blob(chunks, { type: 'audio/webm' })
          const buffer = await blob.arrayBuffer()

          // Clean up media stream tracks
          mediaStream?.getTracks().forEach((track) => track.stop())
          mediaStream = null
          mediaRecorder = null

          resolve(buffer)
        }

        mediaRecorder.stop()
      })
    },

    isRecording() {
      return recording
    },
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add src/audio/
git commit -m "feat: add audio recorder with WebAudio API streaming"
```

---

## Task 9: Recording State Machine + History Store

**Files:**
- Create: `src/stores/recording.ts`, `src/stores/history.ts`, `src/stores/app.ts`, `tests/stores/recording.test.ts`, `tests/stores/history.test.ts`

- [ ] **Step 1: Write failing tests for recording state machine**

```typescript
// tests/stores/recording.test.ts
import { describe, it, expect, beforeEach } from 'vitest'
import { useRecordingStore } from '../../src/stores/recording'

describe('Recording Store', () => {
  beforeEach(() => {
    useRecordingStore.setState({
      state: { status: 'idle' },
      lastResult: null,
    })
  })

  it('starts in idle state', () => {
    const { state } = useRecordingStore.getState()
    expect(state.status).toBe('idle')
  })

  it('transitions to recording', () => {
    useRecordingStore.getState().startRecording()
    expect(useRecordingStore.getState().state.status).toBe('recording')
  })

  it('transitions to transcribing with partial text', () => {
    useRecordingStore.getState().startRecording()
    useRecordingStore.getState().updateState({ status: 'transcribing', partialText: 'hello' })
    const state = useRecordingStore.getState().state
    expect(state.status).toBe('transcribing')
    if (state.status === 'transcribing') {
      expect(state.partialText).toBe('hello')
    }
  })

  it('transitions to done and stores lastResult', () => {
    useRecordingStore.getState().updateState({
      status: 'done',
      sourceText: 'raw',
      finalText: 'polished',
    })
    expect(useRecordingStore.getState().state.status).toBe('done')
    expect(useRecordingStore.getState().lastResult).toEqual({
      sourceText: 'raw',
      finalText: 'polished',
    })
  })

  it('resets to idle', () => {
    useRecordingStore.getState().startRecording()
    useRecordingStore.getState().reset()
    expect(useRecordingStore.getState().state.status).toBe('idle')
  })
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm test -- tests/stores/recording.test.ts`
Expected: FAIL — module not found

- [ ] **Step 3: Implement recording store**

```typescript
// src/stores/recording.ts
import { create } from 'zustand'
import type { PipelineState } from '../types/pipeline'

interface LastResult {
  readonly sourceText: string
  readonly finalText: string
}

interface RecordingState {
  readonly state: PipelineState
  readonly lastResult: LastResult | null
  readonly startRecording: () => void
  readonly updateState: (state: PipelineState) => void
  readonly reset: () => void
}

export const useRecordingStore = create<RecordingState>((set) => ({
  state: { status: 'idle' },
  lastResult: null,

  startRecording: () =>
    set({ state: { status: 'recording', startedAt: Date.now() } }),

  updateState: (state) => {
    if (state.status === 'done') {
      set({
        state,
        lastResult: {
          sourceText: state.sourceText,
          finalText: state.finalText,
        },
      })
    } else {
      set({ state })
    }
  },

  reset: () => set({ state: { status: 'idle' } }),
}))
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm test -- tests/stores/recording.test.ts`
Expected: All tests PASS

- [ ] **Step 5: Write failing tests for history store**

```typescript
// tests/stores/history.test.ts
import { describe, it, expect, beforeEach } from 'vitest'
import { useHistoryStore } from '../../src/stores/history'

describe('History Store', () => {
  beforeEach(() => {
    useHistoryStore.setState({ records: [] })
  })

  it('starts with empty records', () => {
    expect(useHistoryStore.getState().records).toEqual([])
  })

  it('adds a record', () => {
    useHistoryStore.getState().addRecord({
      sceneId: 'dictate',
      sceneName: '语音输入',
      originalText: 'hello',
      finalText: 'hello',
      outputStatus: 'inserted',
      pipelineSteps: ['stt:iflytek'],
    })
    const records = useHistoryStore.getState().records
    expect(records).toHaveLength(1)
    expect(records[0].sceneId).toBe('dictate')
    expect(records[0].id).toBeDefined()
    expect(records[0].timestamp).toBeGreaterThan(0)
  })

  it('prepends new records (newest first)', () => {
    const store = useHistoryStore.getState()
    store.addRecord({ sceneId: 'a', sceneName: 'A', originalText: 'first', finalText: 'first', outputStatus: 'inserted', pipelineSteps: [] })
    store.addRecord({ sceneId: 'b', sceneName: 'B', originalText: 'second', finalText: 'second', outputStatus: 'inserted', pipelineSteps: [] })

    const records = useHistoryStore.getState().records
    expect(records[0].sceneId).toBe('b')
    expect(records[1].sceneId).toBe('a')
  })

  it('clears all records', () => {
    useHistoryStore.getState().addRecord({ sceneId: 'a', sceneName: 'A', originalText: 'x', finalText: 'x', outputStatus: 'inserted', pipelineSteps: [] })
    useHistoryStore.getState().clearAll()
    expect(useHistoryStore.getState().records).toEqual([])
  })

  it('searches records by text', () => {
    const store = useHistoryStore.getState()
    store.addRecord({ sceneId: 'a', sceneName: 'A', originalText: 'hello world', finalText: 'hello world', outputStatus: 'inserted', pipelineSteps: [] })
    store.addRecord({ sceneId: 'b', sceneName: 'B', originalText: 'goodbye', finalText: 'goodbye', outputStatus: 'inserted', pipelineSteps: [] })

    const results = useHistoryStore.getState().search('hello')
    expect(results).toHaveLength(1)
    expect(results[0].sceneId).toBe('a')
  })
})
```

- [ ] **Step 6: Run test to verify it fails**

Run: `npm test -- tests/stores/history.test.ts`
Expected: FAIL

- [ ] **Step 7: Implement history store**

```typescript
// src/stores/history.ts
import { create } from 'zustand'
import type { HistoryRecord, OutputStatus } from '../types/history'

interface NewRecord {
  readonly sceneId: string
  readonly sceneName: string
  readonly originalText: string
  readonly finalText: string
  readonly outputStatus: OutputStatus
  readonly pipelineSteps: readonly string[]
}

interface HistoryState {
  readonly records: readonly HistoryRecord[]
  readonly addRecord: (record: NewRecord) => void
  readonly clearAll: () => void
  readonly search: (query: string) => readonly HistoryRecord[]
  readonly filterByScene: (sceneId: string) => readonly HistoryRecord[]
}

function generateId(): string {
  return `${Date.now()}-${Math.random().toString(36).slice(2, 9)}`
}

export const useHistoryStore = create<HistoryState>((set, get) => ({
  records: [],

  addRecord: (newRecord) => {
    const record: HistoryRecord = {
      id: generateId(),
      timestamp: Date.now(),
      ...newRecord,
    }
    set({ records: [record, ...get().records] })
  },

  clearAll: () => set({ records: [] }),

  search: (query) => {
    const lower = query.toLowerCase()
    return get().records.filter(
      (r) =>
        r.finalText.toLowerCase().includes(lower) ||
        r.originalText.toLowerCase().includes(lower),
    )
  },

  filterByScene: (sceneId) => {
    return get().records.filter((r) => r.sceneId === sceneId)
  },
}))
```

- [ ] **Step 8: Run test to verify it passes**

Run: `npm test -- tests/stores/history.test.ts`
Expected: All tests PASS

- [ ] **Step 9: Create app store**

```typescript
// src/stores/app.ts
import { create } from 'zustand'

interface AppState {
  readonly currentSceneId: string
  readonly activeWindow: 'floating' | 'settings' | 'history'
  readonly setCurrentScene: (sceneId: string) => void
  readonly setActiveWindow: (window: 'floating' | 'settings' | 'history') => void
}

export const useAppStore = create<AppState>((set) => ({
  currentSceneId: 'dictate',
  activeWindow: 'floating',

  setCurrentScene: (sceneId) => set({ currentSceneId: sceneId }),
  setActiveWindow: (activeWindow) => set({ activeWindow }),
}))
```

- [ ] **Step 10: Commit**

```bash
git add src/stores/ tests/stores/
git commit -m "feat: add recording state machine, history store, and app store"
```

---

## Task 10: Rust Backend — Config Manager

**Files:**
- Modify: `src-tauri/src/lib.rs`
- Create: `src-tauri/src/config.rs`

- [ ] **Step 1: Create config manager with read/write IPC commands**

```rust
// src-tauri/src/config.rs
use serde_json::Value;
use std::fs;
use std::path::PathBuf;

fn config_dir() -> PathBuf {
    let base = dirs::config_dir().unwrap_or_else(|| PathBuf::from("."));
    base.join("verbo")
}

fn config_path() -> PathBuf {
    config_dir().join("config.json")
}

#[tauri::command]
pub fn read_config() -> Result<Value, String> {
    let path = config_path();
    if !path.exists() {
        return Ok(Value::Null);
    }
    let content = fs::read_to_string(&path).map_err(|e| e.to_string())?;
    let value: Value = serde_json::from_str(&content).map_err(|e| e.to_string())?;
    Ok(value)
}

#[tauri::command]
pub fn write_config(config: Value) -> Result<(), String> {
    let dir = config_dir();
    fs::create_dir_all(&dir).map_err(|e| e.to_string())?;
    let content = serde_json::to_string_pretty(&config).map_err(|e| e.to_string())?;
    fs::write(config_path(), content).map_err(|e| e.to_string())?;
    Ok(())
}

#[tauri::command]
pub fn get_config_path() -> String {
    config_path().to_string_lossy().to_string()
}
```

- [ ] **Step 2: Register commands in lib.rs**

```rust
// src-tauri/src/lib.rs
mod config;

pub fn run() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![
            config::read_config,
            config::write_config,
            config::get_config_path,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
```

- [ ] **Step 3: Verify Rust compiles**

Run: `cd src-tauri && cargo check`
Expected: compiles without errors

- [ ] **Step 4: Commit**

```bash
git add src-tauri/src/config.rs src-tauri/src/lib.rs
git commit -m "feat: add Rust config manager with read/write IPC commands"
```

---

## Task 11: Rust Backend — Hotkey Manager

**Files:**
- Create: `src-tauri/src/hotkey.rs`
- Modify: `src-tauri/src/lib.rs`

- [ ] **Step 1: Create hotkey manager using tauri-plugin-global-shortcut**

```rust
// src-tauri/src/hotkey.rs
use tauri::{AppHandle, Manager};
use tauri_plugin_global_shortcut::{GlobalShortcutExt, Shortcut, ShortcutState};

#[derive(Clone, serde::Serialize)]
struct HotkeyEvent {
    id: String,
    action: String, // "toggle_start", "toggle_stop", "push_start", "push_stop"
}

pub fn setup_hotkeys(app: &AppHandle, shortcuts: Vec<(String, String)>) -> Result<(), String> {
    let global_shortcut = app.global_shortcut();

    // Unregister all existing shortcuts
    global_shortcut.unregister_all().map_err(|e| e.to_string())?;

    for (id, accelerator) in shortcuts {
        let shortcut: Shortcut = accelerator.parse().map_err(|e: tauri_plugin_global_shortcut::Error| e.to_string())?;
        let app_handle = app.clone();
        let shortcut_id = id.clone();

        global_shortcut
            .on_shortcut(shortcut, move |_app, _shortcut, event| {
                let action = match event.state {
                    ShortcutState::Pressed => "pressed",
                    ShortcutState::Released => "released",
                };

                let _ = app_handle.emit("hotkey", HotkeyEvent {
                    id: shortcut_id.clone(),
                    action: action.to_string(),
                });
            })
            .map_err(|e| e.to_string())?;
    }

    Ok(())
}

#[tauri::command]
pub fn register_hotkeys(app: AppHandle, shortcuts: Vec<(String, String)>) -> Result<(), String> {
    setup_hotkeys(&app, shortcuts)
}

#[tauri::command]
pub fn unregister_all_hotkeys(app: AppHandle) -> Result<(), String> {
    app.global_shortcut()
        .unregister_all()
        .map_err(|e| e.to_string())
}
```

- [ ] **Step 2: Register hotkey commands in lib.rs**

Add to existing `invoke_handler`:

```rust
// src-tauri/src/lib.rs
mod config;
mod hotkey;

pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_global_shortcut::Builder::new().build())
        .invoke_handler(tauri::generate_handler![
            config::read_config,
            config::write_config,
            config::get_config_path,
            hotkey::register_hotkeys,
            hotkey::unregister_all_hotkeys,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
```

- [ ] **Step 3: Verify Rust compiles**

Run: `cd src-tauri && cargo check`
Expected: compiles without errors

- [ ] **Step 4: Commit**

```bash
git add src-tauri/src/hotkey.rs src-tauri/src/lib.rs
git commit -m "feat: add global hotkey manager with press/release events"
```

---

## Task 12: Rust Backend — Text Output + System Tray

**Files:**
- Create: `src-tauri/src/output.rs`, `src-tauri/src/tray.rs`
- Modify: `src-tauri/src/lib.rs`

- [ ] **Step 1: Create text output module**

```rust
// src-tauri/src/output.rs
use tauri::AppHandle;
use tauri_plugin_clipboard_manager::ClipboardExt;

#[tauri::command]
pub fn simulate_input(text: String) -> Result<(), String> {
    // Use AppleScript on macOS to simulate keyboard input
    // This avoids needing to handle individual keystrokes for unicode text
    #[cfg(target_os = "macos")]
    {
        let escaped = text
            .replace('\\', "\\\\")
            .replace('"', "\\\"");

        let script = format!(
            r#"tell application "System Events" to keystroke "{}""#,
            escaped
        );

        std::process::Command::new("osascript")
            .arg("-e")
            .arg(&script)
            .output()
            .map_err(|e| format!("Failed to simulate input: {}", e))?;
    }

    Ok(())
}

#[tauri::command]
pub fn copy_to_clipboard(app: AppHandle, text: String) -> Result<(), String> {
    app.clipboard()
        .write_text(&text)
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub fn check_accessibility_permission() -> bool {
    #[cfg(target_os = "macos")]
    {
        // Check if accessibility permission is granted
        let output = std::process::Command::new("osascript")
            .arg("-e")
            .arg(r#"tell application "System Events" to keystroke """#)
            .output();

        output.is_ok()
    }
    #[cfg(not(target_os = "macos"))]
    {
        true
    }
}
```

- [ ] **Step 2: Create system tray module**

```rust
// src-tauri/src/tray.rs
use tauri::{
    AppHandle, Manager,
    menu::{MenuBuilder, MenuItemBuilder, PredefinedMenuItem},
    tray::TrayIconBuilder,
};

pub fn create_tray(app: &AppHandle) -> Result<(), String> {
    let quit = MenuItemBuilder::with_id("quit", "Quit")
        .build(app)
        .map_err(|e| e.to_string())?;

    let settings = MenuItemBuilder::with_id("settings", "Settings")
        .accelerator("CmdOrCtrl+,")
        .build(app)
        .map_err(|e| e.to_string())?;

    let history = MenuItemBuilder::with_id("history", "History")
        .accelerator("CmdOrCtrl+H")
        .build(app)
        .map_err(|e| e.to_string())?;

    let separator = PredefinedMenuItem::separator(app)
        .map_err(|e| e.to_string())?;

    let separator2 = PredefinedMenuItem::separator(app)
        .map_err(|e| e.to_string())?;

    let menu = MenuBuilder::new(app)
        .item(&history)
        .item(&settings)
        .item(&separator)
        .item(&quit)
        .build()
        .map_err(|e| e.to_string())?;

    let _tray = TrayIconBuilder::new()
        .menu(&menu)
        .tooltip("Verbo")
        .on_menu_event(move |app, event| {
            match event.id().as_ref() {
                "quit" => {
                    app.exit(0);
                }
                "settings" => {
                    let _ = app.emit("tray-action", "settings");
                }
                "history" => {
                    let _ = app.emit("tray-action", "history");
                }
                _ => {}
            }
        })
        .build(app)
        .map_err(|e| e.to_string())?;

    Ok(())
}

#[tauri::command]
pub fn update_tray_scenes(app: AppHandle, scenes: Vec<(String, String, bool)>) -> Result<(), String> {
    // scenes: Vec<(id, name, is_default)>
    // This will be called from frontend when scenes change
    // For MVP, tray is rebuilt with scene items
    // Full implementation deferred — tray created at startup with static menu
    Ok(())
}
```

- [ ] **Step 3: Wire everything into lib.rs**

```rust
// src-tauri/src/lib.rs
mod config;
mod hotkey;
mod output;
mod tray;

pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_global_shortcut::Builder::new().build())
        .plugin(tauri_plugin_clipboard_manager::init())
        .setup(|app| {
            tray::create_tray(app.handle()).map_err(|e| e.into())?;
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            config::read_config,
            config::write_config,
            config::get_config_path,
            hotkey::register_hotkeys,
            hotkey::unregister_all_hotkeys,
            output::simulate_input,
            output::copy_to_clipboard,
            output::check_accessibility_permission,
            tray::update_tray_scenes,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
```

- [ ] **Step 4: Verify Rust compiles**

Run: `cd src-tauri && cargo check`
Expected: compiles without errors

- [ ] **Step 5: Commit**

```bash
git add src-tauri/src/output.rs src-tauri/src/tray.rs src-tauri/src/lib.rs
git commit -m "feat: add text output (simulate + clipboard) and system tray"
```

---

## Task 13: Floating Window UI

**Files:**
- Create: `src/windows/floating/FloatingWindow.tsx`, `src/windows/floating/Pill.tsx`, `src/windows/floating/Bubble.tsx`, `src/windows/floating/Waveform.tsx`

- [ ] **Step 1: Create Waveform component**

```tsx
// src/windows/floating/Waveform.tsx
import { type CSSProperties } from 'react'

interface WaveformProps {
  readonly active: boolean
  readonly barCount?: number
  readonly color?: string
}

export function Waveform({ active, barCount = 5, color = 'var(--color-terracotta)' }: WaveformProps) {
  const bars = Array.from({ length: barCount }, (_, i) => i)
  const heights = [6, 12, 16, 10, 14]

  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 2, height: 16 }}>
      {bars.map((i) => (
        <div
          key={i}
          style={{
            width: 2.5,
            height: heights[i % heights.length],
            background: color,
            borderRadius: 1.5,
            animation: active ? `wave 0.7s ease-in-out infinite` : 'none',
            animationDelay: `${i * 0.08}s`,
            transform: active ? undefined : 'scaleY(0.3)',
          } as CSSProperties}
        />
      ))}
    </div>
  )
}
```

- [ ] **Step 2: Create Pill component**

```tsx
// src/windows/floating/Pill.tsx
import { useTranslation } from 'react-i18next'
import { Waveform } from './Waveform'
import type { PipelineState } from '../../types/pipeline'

interface PillProps {
  readonly state: PipelineState
  readonly hotkeyHint?: string
  readonly elapsed?: number
  readonly onClick?: () => void
}

function getDotStyle(status: PipelineState['status']): React.CSSProperties {
  const base: React.CSSProperties = { width: 8, height: 8, borderRadius: '50%', flexShrink: 0 }
  switch (status) {
    case 'idle': return { ...base, background: 'var(--color-ring-deep)' }
    case 'recording': return { ...base, background: 'var(--color-terracotta)', boxShadow: '0 0 6px rgba(201,100,66,0.5)', animation: 'pulse 1.5s ease-in-out infinite' }
    case 'transcribing': return { ...base, background: 'var(--color-terracotta)', boxShadow: '0 0 6px rgba(201,100,66,0.5)', animation: 'pulse 1.5s ease-in-out infinite' }
    case 'processing': return { ...base, background: 'var(--color-coral)', animation: 'pulse 1s ease-in-out infinite' }
    case 'done': return { ...base, background: 'var(--color-success)' }
    case 'error': return { ...base, background: 'var(--color-error)' }
  }
}

function formatTime(ms: number): string {
  const secs = Math.floor(ms / 1000)
  const mins = Math.floor(secs / 60)
  const s = secs % 60
  return `${mins}:${s.toString().padStart(2, '0')}`
}

export function Pill({ state, hotkeyHint, elapsed, onClick }: PillProps) {
  const { t } = useTranslation()
  const isRecording = state.status === 'recording' || state.status === 'transcribing'
  const isProcessing = state.status === 'processing'

  return (
    <div
      onClick={onClick}
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        gap: 8,
        background: 'var(--color-ivory)',
        borderRadius: 'var(--radius-pill)',
        padding: '8px 14px',
        boxShadow: 'var(--color-ivory) 0 0 0 0, var(--color-ring-warm) 0 0 0 1px',
        cursor: onClick ? 'pointer' : 'default',
        whiteSpace: 'nowrap',
      }}
    >
      <div style={getDotStyle(state.status)} />

      {isRecording && (
        <>
          <Waveform active />
          {elapsed !== undefined && (
            <span style={{ fontSize: 12, fontWeight: 500, color: 'var(--color-terracotta)' }}>
              {formatTime(elapsed)}
            </span>
          )}
        </>
      )}

      {isProcessing && (
        <span style={{ fontSize: 13, fontWeight: 500, color: 'var(--color-coral)' }}>
          {t('floating.processing')}
        </span>
      )}

      {(state.status === 'idle' || state.status === 'done') && (
        <span style={{ fontSize: 13, color: 'var(--color-stone-gray)' }}>Verbo</span>
      )}

      {state.status === 'idle' && hotkeyHint && (
        <span style={{ fontSize: 11, color: 'var(--color-warm-silver)', fontFamily: 'var(--font-mono)', letterSpacing: -0.32 }}>
          {hotkeyHint}
        </span>
      )}

      {state.status === 'error' && (
        <span style={{ fontSize: 13, fontWeight: 500, color: 'var(--color-error)' }}>
          {t('floating.error')}
        </span>
      )}
    </div>
  )
}
```

- [ ] **Step 3: Create Bubble component**

```tsx
// src/windows/floating/Bubble.tsx
import { useTranslation } from 'react-i18next'
import { Waveform } from './Waveform'
import type { PipelineState } from '../../types/pipeline'

interface BubbleProps {
  readonly state: PipelineState
  readonly sceneName: string
  readonly onCopy?: () => void
  readonly onRetry?: () => void
}

export function Bubble({ state, sceneName, onCopy, onRetry }: BubbleProps) {
  const { t } = useTranslation()
  const expanded = state.status !== 'idle' && state.status !== 'recording'

  if (!expanded) return null

  return (
    <div
      style={{
        background: 'var(--color-ivory)',
        borderRadius: 'var(--radius-xl)',
        boxShadow: 'rgba(0,0,0,0.05) 0 4px 24px, var(--color-ring-warm) 0 0 0 1px',
        width: 300,
        overflow: 'hidden',
        marginTop: 8,
        animation: 'bubbleExpand 0.35s cubic-bezier(0.4,0,0.2,1)',
      }}
    >
      {/* Top bar */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '8px 14px' }}>
        {state.status === 'transcribing' && (
          <>
            <Waveform active barCount={3} />
            <span style={{ fontSize: 12, color: 'var(--color-terracotta)' }}>
              {t('floating.listening')}
            </span>
          </>
        )}
        {state.status === 'processing' && (
          <span style={{ fontSize: 12, color: 'var(--color-coral)' }}>
            {t('floating.processing')}
          </span>
        )}
        {state.status === 'done' && (
          <span style={{ fontSize: 12, color: 'var(--color-success)' }}>
            {t('floating.done')}
          </span>
        )}
        {state.status === 'error' && (
          <span style={{ fontSize: 12, color: 'var(--color-error)' }}>
            {t('floating.error')}
          </span>
        )}
        <span style={{
          fontSize: 11, color: 'var(--color-olive-gray)',
          background: 'var(--color-parchment)', padding: '2px 8px',
          borderRadius: 6, marginLeft: 'auto',
        }}>
          {sceneName}
        </span>
      </div>

      {/* Body */}
      <div style={{ padding: '0 14px 10px', fontSize: 13, lineHeight: 1.6 }}>
        {state.status === 'transcribing' && (
          <span style={{ color: 'var(--color-olive-gray)' }}>{state.partialText}</span>
        )}
        {state.status === 'processing' && (
          <>
            <div style={{
              fontSize: 12, color: 'var(--color-stone-gray)',
              textDecoration: 'line-through', textDecorationColor: 'var(--color-ring-warm)',
              opacity: 0.6, lineHeight: 1.5,
            }}>
              {state.sourceText}
            </div>
            <div style={{ color: 'var(--color-near-black)', marginTop: 6 }}>
              {state.partialResult}
              <span style={{
                display: 'inline-block', width: 2, height: 14,
                background: 'var(--color-terracotta)', animation: 'blink 0.6s step-end infinite',
                verticalAlign: 'text-bottom', marginLeft: 1,
              }} />
            </div>
          </>
        )}
        {state.status === 'done' && (
          <span style={{ color: 'var(--color-near-black)' }}>{state.finalText}</span>
        )}
        {state.status === 'error' && (
          <span style={{ color: 'var(--color-error)', fontSize: 12 }}>{state.message}</span>
        )}
      </div>

      {/* Footer (done/error only) */}
      {(state.status === 'done' || state.status === 'error') && (
        <div style={{
          display: 'flex', alignItems: 'center', justifyContent: 'space-between',
          padding: '6px 14px', borderTop: '1px solid var(--color-border-cream)',
        }}>
          <span style={{ fontSize: 11, color: state.status === 'done' ? 'var(--color-success)' : 'var(--color-error)' }}>
            {state.status === 'done' ? t('floating.inserted') : t('floating.failed')}
          </span>
          <div style={{ display: 'flex', gap: 4 }}>
            <button onClick={onCopy} style={miniButtonStyle}>{t('floating.copy')}</button>
            <button onClick={onRetry} style={miniButtonStyle}>{t('floating.retry')}</button>
          </div>
        </div>
      )}
    </div>
  )
}

const miniButtonStyle: React.CSSProperties = {
  fontSize: 11, fontWeight: 500,
  color: 'var(--color-charcoal-warm)',
  background: 'var(--color-warm-sand)',
  border: 'none', padding: '3px 8px',
  borderRadius: 6, cursor: 'pointer',
  boxShadow: 'var(--color-warm-sand) 0 0 0 0, var(--color-ring-warm) 0 0 0 1px',
}
```

- [ ] **Step 4: Create FloatingWindow root component**

```tsx
// src/windows/floating/FloatingWindow.tsx
import { useEffect, useRef } from 'react'
import { useTranslation } from 'react-i18next'
import { Pill } from './Pill'
import { Bubble } from './Bubble'
import { useRecordingStore } from '../../stores/recording'
import { useConfigStore } from '../../config/store'
import { useAppStore } from '../../stores/app'

export function FloatingWindow() {
  const { t } = useTranslation()
  const state = useRecordingStore((s) => s.state)
  const lastResult = useRecordingStore((s) => s.lastResult)
  const reset = useRecordingStore((s) => s.reset)
  const config = useConfigStore((s) => s.config)
  const currentSceneId = useAppStore((s) => s.currentSceneId)

  const currentScene = config.scenes.find((s) => s.id === currentSceneId)
  const sceneName = currentScene?.name ?? ''
  const hotkeyHint = currentScene?.hotkey.toggleRecord ?? undefined

  const autoCollapseTimer = useRef<ReturnType<typeof setTimeout> | null>(null)

  // Auto-collapse after result
  useEffect(() => {
    if (state.status === 'done') {
      autoCollapseTimer.current = setTimeout(() => {
        reset()
      }, config.general.autoCollapseDelay)
    }
    return () => {
      if (autoCollapseTimer.current) clearTimeout(autoCollapseTimer.current)
    }
  }, [state.status, config.general.autoCollapseDelay, reset])

  // Elapsed time tracker
  const [elapsed, setElapsed] = useState(0)
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null)

  useEffect(() => {
    if (state.status === 'recording') {
      setElapsed(0)
      timerRef.current = setInterval(() => setElapsed((e) => e + 1000), 1000)
    } else {
      if (timerRef.current) clearInterval(timerRef.current)
    }
    return () => { if (timerRef.current) clearInterval(timerRef.current) }
  }, [state.status])

  const handlePillClick = () => {
    if (state.status === 'idle' && lastResult) {
      // Re-expand last result
      useRecordingStore.getState().updateState({
        status: 'done',
        sourceText: lastResult.sourceText,
        finalText: lastResult.finalText,
      })
    }
  }

  const handleCopy = async () => {
    if (state.status === 'done') {
      const { invoke } = await import('@tauri-apps/api/core')
      await invoke('copy_to_clipboard', { text: state.finalText })
    }
  }

  return (
    <div className="floating-window" style={{
      display: 'flex', flexDirection: 'column', alignItems: 'center',
      padding: 8,
    }}>
      <Pill
        state={state}
        hotkeyHint={hotkeyHint ?? undefined}
        elapsed={state.status === 'recording' ? elapsed : undefined}
        onClick={handlePillClick}
      />
      <Bubble
        state={state}
        sceneName={sceneName}
        onCopy={handleCopy}
      />
    </div>
  )
}

import { useState } from 'react'
```

- [ ] **Step 5: Add CSS animations to global.css**

Append to `src/styles/global.css`:

```css
@keyframes pulse {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.4; }
}

@keyframes wave {
  0%, 100% { transform: scaleY(0.3); }
  50% { transform: scaleY(1); }
}

@keyframes blink {
  0%, 100% { opacity: 1; }
  50% { opacity: 0; }
}

@keyframes bubbleExpand {
  from {
    max-height: 0;
    opacity: 0;
    transform: scaleY(0.8) translateY(-8px);
  }
  to {
    max-height: 400px;
    opacity: 1;
    transform: scaleY(1) translateY(0);
  }
}

@keyframes shimmer {
  0% { background-position: 200% 0; }
  100% { background-position: -200% 0; }
}
```

- [ ] **Step 6: Commit**

```bash
git add src/windows/floating/ src/styles/global.css
git commit -m "feat: add floating window UI with Pill, Bubble, and Waveform"
```

---

## Task 14: Settings Window

**Files:**
- Create: `src/windows/settings/SettingsWindow.tsx`, `src/windows/settings/ScenesPage.tsx`, `src/windows/settings/SceneEditor.tsx`, `src/windows/settings/ProvidersPage.tsx`, `src/windows/settings/GeneralPage.tsx`, `src/windows/settings/AboutPage.tsx`

This task creates the complete settings window with all 4 tabs. Each component follows the visual design from the mockups. Due to the visual nature of these components, implementation will reference DESIGN.md tokens and follow the layouts validated in the interactive mockups at `.superpowers/brainstorm/`.

- [ ] **Step 1: Create SettingsWindow with sidebar navigation**

```tsx
// src/windows/settings/SettingsWindow.tsx
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { ScenesPage } from './ScenesPage'
import { ProvidersPage } from './ProvidersPage'
import { GeneralPage } from './GeneralPage'
import { AboutPage } from './AboutPage'

type SettingsTab = 'scenes' | 'providers' | 'general' | 'about'

export function SettingsWindow() {
  const { t } = useTranslation()
  const [tab, setTab] = useState<SettingsTab>('scenes')

  const tabs: { key: SettingsTab; label: string }[] = [
    { key: 'scenes', label: t('settings.scenes') },
    { key: 'providers', label: t('settings.providers') },
    { key: 'general', label: t('settings.general') },
    { key: 'about', label: t('settings.about') },
  ]

  return (
    <div className="settings-window" style={{ display: 'flex', height: '100vh', background: 'var(--color-ivory)' }}>
      {/* Sidebar */}
      <div style={{
        width: 180, background: 'var(--color-parchment)',
        borderRight: '1px solid var(--color-border-cream)', padding: '20px 0',
      }}>
        <div style={{
          padding: '0 16px 16px', fontFamily: 'var(--font-serif)',
          fontSize: 16, fontWeight: 500, color: 'var(--color-near-black)',
        }}>
          {t('settings.title')}
        </div>
        {tabs.map(({ key, label }) => (
          <div
            key={key}
            onClick={() => setTab(key)}
            style={{
              padding: '8px 16px', fontSize: 13, cursor: 'pointer',
              color: tab === key ? 'var(--color-near-black)' : 'var(--color-olive-gray)',
              fontWeight: tab === key ? 500 : 400,
              background: tab === key ? 'var(--color-ivory)' : 'transparent',
              borderRight: tab === key ? '2px solid var(--color-terracotta)' : '2px solid transparent',
            }}
          >
            {label}
          </div>
        ))}
      </div>

      {/* Content */}
      <div style={{ flex: 1, padding: 24, overflowY: 'auto' }}>
        {tab === 'scenes' && <ScenesPage />}
        {tab === 'providers' && <ProvidersPage />}
        {tab === 'general' && <GeneralPage />}
        {tab === 'about' && <AboutPage />}
      </div>
    </div>
  )
}
```

- [ ] **Step 2: Create ScenesPage with scene list**

```tsx
// src/windows/settings/ScenesPage.tsx
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useConfigStore } from '../../config/store'
import { SceneEditor } from './SceneEditor'

export function ScenesPage() {
  const { t } = useTranslation()
  const config = useConfigStore((s) => s.config)
  const [editingId, setEditingId] = useState<string | null>(null)

  if (editingId) {
    const scene = config.scenes.find((s) => s.id === editingId)
    if (scene) {
      return <SceneEditor scene={scene} onBack={() => setEditingId(null)} />
    }
  }

  return (
    <div>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 20 }}>
        <div>
          <div style={{ fontFamily: 'var(--font-serif)', fontSize: 18, fontWeight: 500, color: 'var(--color-near-black)' }}>
            {t('settings.scenes')}
          </div>
          <div style={{ fontSize: 13, color: 'var(--color-stone-gray)', marginTop: 2 }}>
            {t('settings.scenesDesc')}
          </div>
        </div>
        <button style={{
          fontSize: 13, fontWeight: 500, color: 'var(--color-ivory)',
          background: 'var(--color-terracotta)', border: 'none',
          padding: '7px 16px', borderRadius: 'var(--radius-md)', cursor: 'pointer',
        }}>
          + {t('settings.newScene')}
        </button>
      </div>

      <div style={{
        display: 'flex', flexDirection: 'column', gap: 1,
        background: 'var(--color-border-cream)', borderRadius: 'var(--radius-lg)',
        overflow: 'hidden', boxShadow: 'var(--color-ivory) 0 0 0 0, var(--color-ring-warm) 0 0 0 1px',
      }}>
        {config.scenes.map((scene) => (
          <div
            key={scene.id}
            onClick={() => setEditingId(scene.id)}
            style={{
              background: 'var(--color-white)', padding: '14px 16px',
              display: 'flex', alignItems: 'center', gap: 12, cursor: 'pointer',
            }}
          >
            <div style={{ width: 6, height: 6, borderRadius: '50%', background: 'var(--color-terracotta)' }} />
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 14, fontWeight: 500, color: 'var(--color-near-black)' }}>{scene.name}</div>
              <div style={{ fontSize: 12, color: 'var(--color-stone-gray)', marginTop: 2 }}>
                {scene.pipeline.map((s) => s.type.toUpperCase()).join(' → ')}
              </div>
            </div>
            {scene.hotkey.toggleRecord && (
              <div style={{
                fontSize: 11, fontFamily: 'var(--font-mono)', color: 'var(--color-olive-gray)',
                background: 'var(--color-parchment)', padding: '3px 8px', borderRadius: 4,
                border: '1px solid var(--color-border-cream)',
              }}>
                {scene.hotkey.toggleRecord}
              </div>
            )}
            {scene.id === config.defaultScene && (
              <div style={{
                fontSize: 11, color: 'var(--color-warm-silver)',
                background: 'var(--color-parchment)', padding: '3px 6px', borderRadius: 4,
                border: '1px solid var(--color-border-cream)',
              }}>
                {t('settings.defaultBadge')}
              </div>
            )}
            <span style={{ fontSize: 14, color: 'var(--color-ring-deep)' }}>▸</span>
          </div>
        ))}
      </div>
    </div>
  )
}
```

- [ ] **Step 3: Create SceneEditor**

```tsx
// src/windows/settings/SceneEditor.tsx
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useConfigStore } from '../../config/store'
import type { Scene, PipelineStep } from '../../types/pipeline'

interface SceneEditorProps {
  readonly scene: Scene
  readonly onBack: () => void
}

export function SceneEditor({ scene, onBack }: SceneEditorProps) {
  const { t } = useTranslation()
  const updateScene = useConfigStore((s) => s.updateScene)
  const [name, setName] = useState(scene.name)
  const [pipeline, setPipeline] = useState<PipelineStep[]>([...scene.pipeline])
  const [output, setOutput] = useState(scene.output)

  const handleSave = () => {
    updateScene(scene.id, { name, pipeline, output })
    onBack()
  }

  const updateStep = (index: number, updates: Partial<PipelineStep>) => {
    setPipeline(pipeline.map((step, i) =>
      i === index ? { ...step, ...updates } as PipelineStep : step
    ))
  }

  return (
    <div>
      <div style={{ fontSize: 12, color: 'var(--color-stone-gray)', marginBottom: 16 }}>
        <span onClick={onBack} style={{ cursor: 'pointer', color: 'var(--color-olive-gray)' }}>
          {t('settings.scenes')}
        </span>
        <span style={{ margin: '0 6px' }}>›</span>
        <span>{scene.name}</span>
      </div>

      {/* Scene Name */}
      <div style={{ marginBottom: 20 }}>
        <label style={{ fontSize: 12, fontWeight: 500, color: 'var(--color-olive-gray)', display: 'block', marginBottom: 6 }}>
          {t('settings.sceneName')}
        </label>
        <input
          value={name}
          onChange={(e) => setName(e.target.value)}
          style={{
            width: '100%', padding: '8px 12px', borderRadius: 'var(--radius-md)',
            border: '1px solid var(--color-border-warm)', background: 'var(--color-white)',
            fontSize: 14, color: 'var(--color-near-black)', outline: 'none',
          }}
        />
      </div>

      {/* Pipeline Steps */}
      <div style={{ marginBottom: 20 }}>
        <label style={{ fontSize: 12, fontWeight: 500, color: 'var(--color-olive-gray)', display: 'block', marginBottom: 8 }}>
          {t('settings.pipelineSteps')}
        </label>
        {pipeline.map((step, i) => (
          <div key={i} style={{
            background: 'var(--color-white)', borderRadius: 10, padding: '12px 14px', marginBottom: 8,
            boxShadow: 'var(--color-white) 0 0 0 0, var(--color-ring-warm) 0 0 0 1px',
          }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 8 }}>
              <span style={{
                fontSize: 11, fontWeight: 600, color: 'var(--color-white)', background: 'var(--color-olive-gray)',
                width: 20, height: 20, borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center',
              }}>{i + 1}</span>
              <span style={{ fontSize: 13, fontWeight: 500, color: 'var(--color-near-black)' }}>
                {step.type === 'stt' ? t('stt.speechToText') : t('llm.llmTransform')}
              </span>
              <span style={{ fontSize: 11, color: 'var(--color-stone-gray)', marginLeft: 'auto' }}>
                {step.type.toUpperCase()}
              </span>
            </div>
            {step.type === 'llm' && (
              <div>
                <label style={{ fontSize: 11, color: 'var(--color-stone-gray)', display: 'block', marginBottom: 3 }}>
                  Prompt <span style={{ color: 'var(--color-warm-silver)' }}>· {t('llm.promptHint')}</span>
                </label>
                <textarea
                  value={step.prompt}
                  onChange={(e) => updateStep(i, { prompt: e.target.value })}
                  style={{
                    width: '100%', height: 64, padding: '8px 10px', borderRadius: 6,
                    border: '1px solid var(--color-border-warm)', background: 'var(--color-white)',
                    fontSize: 12, color: 'var(--color-near-black)', lineHeight: 1.5, resize: 'vertical',
                    fontFamily: 'inherit',
                  }}
                />
              </div>
            )}
          </div>
        ))}
        <button style={{
          width: '100%', padding: 8, border: '1px dashed var(--color-ring-warm)',
          borderRadius: 'var(--radius-md)', background: 'transparent',
          color: 'var(--color-stone-gray)', fontSize: 12, cursor: 'pointer',
        }}>
          + {t('settings.addStep')}
        </button>
      </div>

      {/* Output + Hotkey */}
      <div style={{ display: 'flex', gap: 16, marginBottom: 20 }}>
        <div style={{ flex: 1 }}>
          <label style={{ fontSize: 12, fontWeight: 500, color: 'var(--color-olive-gray)', display: 'block', marginBottom: 6 }}>
            {t('settings.outputMode')}
          </label>
          <select
            value={output}
            onChange={(e) => setOutput(e.target.value as 'simulate' | 'clipboard')}
            style={{
              width: '100%', padding: '8px 12px', borderRadius: 'var(--radius-md)',
              border: '1px solid var(--color-border-warm)', background: 'var(--color-white)',
              fontSize: 13, color: 'var(--color-near-black)',
            }}
          >
            <option value="simulate">{t('settings.simulateInput')}</option>
            <option value="clipboard">{t('settings.clipboard')}</option>
          </select>
        </div>
        <div style={{ flex: 1 }}>
          <label style={{ fontSize: 12, fontWeight: 500, color: 'var(--color-olive-gray)', display: 'block', marginBottom: 6 }}>
            {t('settings.hotkeyToggle')}
          </label>
          <div style={{
            padding: '8px 12px', borderRadius: 'var(--radius-md)',
            border: '1px solid var(--color-border-warm)', background: 'var(--color-parchment)',
            fontSize: 13, color: 'var(--color-near-black)', fontFamily: 'var(--font-mono)',
          }}>
            {scene.hotkey.toggleRecord ?? t('settings.clickToRecord')}
          </div>
        </div>
      </div>

      {/* Actions */}
      <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 8 }}>
        <button onClick={onBack} style={{
          fontSize: 13, color: 'var(--color-charcoal-warm)', background: 'var(--color-warm-sand)',
          border: 'none', padding: '8px 16px', borderRadius: 'var(--radius-md)', cursor: 'pointer',
        }}>
          {t('settings.cancel')}
        </button>
        <button onClick={handleSave} style={{
          fontSize: 13, fontWeight: 500, color: 'var(--color-ivory)',
          background: 'var(--color-terracotta)', border: 'none',
          padding: '8px 16px', borderRadius: 'var(--radius-md)', cursor: 'pointer',
        }}>
          {t('settings.save')}
        </button>
      </div>
    </div>
  )
}
```

- [ ] **Step 4: Create ProvidersPage**

Create `src/windows/settings/ProvidersPage.tsx` implementing the providers config page with STT and LLM sections, API credential inputs, and language chips for STT providers. Follow the layout from the interactive mockup. Uses `useConfigStore` for state. Key elements:
- STT provider cards with App ID, API Key, API Secret fields
- Language chips (clickable to toggle enabled languages)
- LLM provider cards with API Key, Model select, Base URL
- "Add provider" buttons

- [ ] **Step 5: Create GeneralPage**

Create `src/windows/settings/GeneralPage.tsx` implementing global hotkeys, behavior settings (default output, auto-collapse delay, launch at startup), UI language, and data settings (history retention, config path). Uses `useConfigStore`.

- [ ] **Step 6: Create AboutPage**

```tsx
// src/windows/settings/AboutPage.tsx
import { useTranslation } from 'react-i18next'

export function AboutPage() {
  const { t } = useTranslation()

  return (
    <div>
      <div style={{ fontFamily: 'var(--font-serif)', fontSize: 18, fontWeight: 500, color: 'var(--color-near-black)', marginBottom: 20 }}>
        {t('settings.about')}
      </div>
      <div style={{ fontSize: 14, color: 'var(--color-olive-gray)', lineHeight: 1.8 }}>
        <p><strong>Verbo</strong> — {t('settings.aboutVersion')} 0.1.0</p>
        <p style={{ marginTop: 8 }}>Flexible voice input for macOS and Windows.</p>
        <p>Use any speech or LLM API, and build the workflow that fits you best.</p>
        <p style={{ marginTop: 16, fontSize: 13, color: 'var(--color-stone-gray)' }}>
          Open source · MIT License
        </p>
      </div>
    </div>
  )
}
```

- [ ] **Step 7: Commit**

```bash
git add src/windows/settings/
git commit -m "feat: add settings window with scenes, providers, general, and about pages"
```

---

## Task 15: History Window

**Files:**
- Create: `src/windows/history/HistoryWindow.tsx`, `src/windows/history/HistoryItem.tsx`

- [ ] **Step 1: Create HistoryItem component**

```tsx
// src/windows/history/HistoryItem.tsx
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import type { HistoryRecord } from '../../types/history'

interface HistoryItemProps {
  readonly record: HistoryRecord
  readonly onCopy: (text: string) => void
}

export function HistoryItem({ record, onCopy }: HistoryItemProps) {
  const { t } = useTranslation()
  const [showOriginal, setShowOriginal] = useState(false)

  const time = new Date(record.timestamp)
  const timeStr = `${time.getHours()}:${time.getMinutes().toString().padStart(2, '0')}`
  const hasLLM = record.originalText !== record.finalText

  const statusColor =
    record.outputStatus === 'inserted' ? 'var(--color-success)' :
    record.outputStatus === 'failed' ? 'var(--color-error)' :
    'var(--color-olive-gray)'

  const statusBg =
    record.outputStatus === 'inserted' ? 'rgba(74,158,110,0.1)' :
    record.outputStatus === 'failed' ? 'rgba(181,51,51,0.1)' :
    'var(--color-parchment)'

  return (
    <div style={{
      display: 'flex', gap: 12, padding: '14px 20px',
      borderBottom: '1px solid var(--color-border-cream)', cursor: 'default',
    }}>
      <div style={{ flexShrink: 0, width: 50, textAlign: 'right' }}>
        <div style={{ fontSize: 13, fontWeight: 500, color: 'var(--color-near-black)' }}>{timeStr}</div>
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: 'inline-flex', alignItems: 'center', gap: 4, marginBottom: 4 }}>
          <span style={{ width: 6, height: 6, borderRadius: '50%', background: 'var(--color-terracotta)' }} />
          <span style={{ fontSize: 11, color: 'var(--color-olive-gray)', fontWeight: 500 }}>
            {record.sceneName}
          </span>
        </div>
        <div style={{
          fontSize: 13, color: 'var(--color-near-black)', lineHeight: 1.5,
          display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical', overflow: 'hidden',
        }}>
          {showOriginal ? record.originalText : record.finalText}
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 4 }}>
          <span style={{ fontSize: 10, padding: '1px 6px', borderRadius: 4, color: statusColor, background: statusBg }}>
            {t(`history.${record.outputStatus}`)}
          </span>
          {hasLLM && (
            <span
              onClick={() => setShowOriginal(!showOriginal)}
              style={{ fontSize: 11, color: 'var(--color-stone-gray)', cursor: 'pointer' }}
            >
              {showOriginal ? '▾ ' : ''}{t('history.viewOriginal')} {showOriginal ? '' : '▸'}
            </span>
          )}
        </div>
      </div>
      <div style={{ flexShrink: 0 }}>
        <button
          onClick={() => onCopy(record.finalText)}
          style={{
            fontSize: 11, fontWeight: 500, color: 'var(--color-charcoal-warm)',
            background: 'var(--color-warm-sand)', border: 'none', padding: '3px 10px',
            borderRadius: 6, cursor: 'pointer',
            boxShadow: 'var(--color-warm-sand) 0 0 0 0, var(--color-ring-warm) 0 0 0 1px',
          }}
        >
          {t('history.copy')}
        </button>
      </div>
    </div>
  )
}
```

- [ ] **Step 2: Create HistoryWindow**

```tsx
// src/windows/history/HistoryWindow.tsx
import { useState, useMemo } from 'react'
import { useTranslation } from 'react-i18next'
import { useHistoryStore } from '../../stores/history'
import { useConfigStore } from '../../config/store'
import { HistoryItem } from './HistoryItem'

function groupByDate(records: readonly { timestamp: number }[]): Map<string, typeof records> {
  const groups = new Map<string, typeof records>()
  const today = new Date()
  const yesterday = new Date(today)
  yesterday.setDate(yesterday.getDate() - 1)

  for (const record of records) {
    const date = new Date(record.timestamp)
    let key: string
    if (date.toDateString() === today.toDateString()) key = 'today'
    else if (date.toDateString() === yesterday.toDateString()) key = 'yesterday'
    else key = date.toLocaleDateString()

    const existing = groups.get(key) ?? []
    groups.set(key, [...existing, record])
  }
  return groups
}

export function HistoryWindow() {
  const { t } = useTranslation()
  const records = useHistoryStore((s) => s.records)
  const search = useHistoryStore((s) => s.search)
  const clearAll = useHistoryStore((s) => s.clearAll)
  const scenes = useConfigStore((s) => s.config.scenes)

  const [query, setQuery] = useState('')
  const [sceneFilter, setSceneFilter] = useState<string>('all')

  const filtered = useMemo(() => {
    let result = query ? search(query) : records
    if (sceneFilter !== 'all') {
      result = result.filter((r) => r.sceneId === sceneFilter)
    }
    return result
  }, [records, query, sceneFilter, search])

  const grouped = groupByDate(filtered)

  const handleCopy = async (text: string) => {
    const { invoke } = await import('@tauri-apps/api/core')
    await invoke('copy_to_clipboard', { text })
  }

  return (
    <div className="history-window" style={{ background: 'var(--color-ivory)', height: '100vh', display: 'flex', flexDirection: 'column' }}>
      {/* Toolbar */}
      <div style={{
        display: 'flex', alignItems: 'center', gap: 12,
        padding: '16px 20px', borderBottom: '1px solid var(--color-border-cream)',
      }}>
        <div style={{ fontFamily: 'var(--font-serif)', fontSize: 18, fontWeight: 500, color: 'var(--color-near-black)' }}>
          {t('history.title')}
        </div>
        <input
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder={t('history.search')}
          style={{
            flex: 1, marginLeft: 12, padding: '6px 12px', borderRadius: 'var(--radius-md)',
            border: '1px solid var(--color-border-warm)', background: 'var(--color-white)',
            fontSize: 13, color: 'var(--color-near-black)', outline: 'none',
          }}
        />
        <select
          value={sceneFilter}
          onChange={(e) => setSceneFilter(e.target.value)}
          style={{
            fontSize: 12, padding: '5px 10px', borderRadius: 6,
            border: '1px solid var(--color-border-warm)', background: 'var(--color-white)',
            color: 'var(--color-near-black)',
          }}
        >
          <option value="all">{t('history.allScenes')}</option>
          {scenes.map((s) => (
            <option key={s.id} value={s.id}>{s.name}</option>
          ))}
        </select>
      </div>

      {/* List */}
      <div style={{ flex: 1, overflowY: 'auto' }}>
        {Array.from(grouped.entries()).map(([dateKey, items]) => (
          <div key={dateKey}>
            <div style={{
              fontSize: 11, fontWeight: 600, color: 'var(--color-olive-gray)',
              textTransform: 'uppercase', letterSpacing: 0.5,
              padding: '10px 20px 6px', background: 'var(--color-parchment)',
              borderBottom: '1px solid var(--color-border-cream)',
            }}>
              {dateKey === 'today' ? t('history.today') : dateKey === 'yesterday' ? t('history.yesterday') : dateKey}
            </div>
            {items.map((record: any) => (
              <HistoryItem key={record.id} record={record} onCopy={handleCopy} />
            ))}
          </div>
        ))}
      </div>

      {/* Footer */}
      <div style={{
        padding: '10px 20px', borderTop: '1px solid var(--color-border-cream)',
        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      }}>
        <span style={{ fontSize: 12, color: 'var(--color-stone-gray)' }}>
          {filtered.length} {t('history.records')}
        </span>
        <button
          onClick={clearAll}
          style={{ fontSize: 12, color: 'var(--color-error)', background: 'none', border: 'none', cursor: 'pointer', opacity: 0.7 }}
        >
          {t('history.clearAll')}
        </button>
      </div>
    </div>
  )
}
```

- [ ] **Step 3: Commit**

```bash
git add src/windows/history/
git commit -m "feat: add history window with search, filter, and date grouping"
```

---

## Task 16: Window Router + Integration Wiring

**Files:**
- Modify: `src/App.tsx`, `src/main.tsx`
- Create: `src/hooks/useHotkey.ts`, `src/hooks/usePipeline.ts`

- [ ] **Step 1: Create hotkey hook**

```tsx
// src/hooks/useHotkey.ts
import { useEffect } from 'react'
import { listen } from '@tauri-apps/api/event'

interface HotkeyEvent {
  id: string
  action: 'pressed' | 'released'
}

export function useHotkey(onHotkey: (event: HotkeyEvent) => void) {
  useEffect(() => {
    const unlisten = listen<HotkeyEvent>('hotkey', (event) => {
      onHotkey(event.payload)
    })

    return () => {
      unlisten.then((fn) => fn())
    }
  }, [onHotkey])
}
```

- [ ] **Step 2: Create pipeline orchestrator hook**

```tsx
// src/hooks/usePipeline.ts
import { useCallback, useRef } from 'react'
import { invoke } from '@tauri-apps/api/core'
import { useRecordingStore } from '../stores/recording'
import { useHistoryStore } from '../stores/history'
import { useConfigStore } from '../config/store'
import { useAppStore } from '../stores/app'
import { executePipeline } from '../engine/pipeline'
import { createAudioRecorder } from '../audio/recorder'
import type { STTAdapter } from '../adapters/stt/types'
import type { LLMAdapter } from '../adapters/llm/types'
import type { Scene } from '../types/pipeline'

export function usePipeline(
  getSTT: (name: string) => STTAdapter | undefined,
  getLLM: (name: string) => LLMAdapter | undefined,
) {
  const recorder = useRef(createAudioRecorder())
  const streamRef = useRef<ReadableStream<ArrayBuffer> | null>(null)

  const startRecording = useCallback(async () => {
    const store = useRecordingStore.getState()
    store.startRecording()
    streamRef.current = await recorder.current.start()
  }, [])

  const stopAndProcess = useCallback(async (scene: Scene) => {
    const audio = await recorder.current.stop()
    const updateState = useRecordingStore.getState().updateState

    try {
      const result = await executePipeline(scene.pipeline, {
        audio,
        audioStream: streamRef.current ?? undefined,
        getSTT: (name) => getSTT(name),
        getLLM: (name) => getLLM(name),
        onStateChange: updateState,
      })

      // Output text
      let outputStatus: 'inserted' | 'copied' | 'failed' = 'failed'
      try {
        if (scene.output === 'simulate') {
          await invoke('simulate_input', { text: result })
          outputStatus = 'inserted'
        } else {
          await invoke('copy_to_clipboard', { text: result })
          outputStatus = 'copied'
        }
      } catch {
        // Fallback to clipboard
        try {
          await invoke('copy_to_clipboard', { text: result })
          outputStatus = 'copied'
        } catch {
          outputStatus = 'failed'
        }
      }

      // Save to history
      useHistoryStore.getState().addRecord({
        sceneId: scene.id,
        sceneName: scene.name,
        originalText: result, // Will be different from finalText once we track source
        finalText: result,
        outputStatus,
        pipelineSteps: scene.pipeline.map((s) => `${s.type}:${s.provider}`),
      })
    } catch (err) {
      // Error state already set by pipeline engine
      useHistoryStore.getState().addRecord({
        sceneId: scene.id,
        sceneName: scene.name,
        originalText: '',
        finalText: '',
        outputStatus: 'failed',
        pipelineSteps: scene.pipeline.map((s) => `${s.type}:${s.provider}`),
      })
    }
  }, [getSTT, getLLM])

  return { startRecording, stopAndProcess }
}
```

- [ ] **Step 3: Update App.tsx with window router**

```tsx
// src/App.tsx
import { useEffect, useState } from 'react'
import { getCurrentWindow } from '@tauri-apps/api/window'
import { FloatingWindow } from './windows/floating/FloatingWindow'
import { SettingsWindow } from './windows/settings/SettingsWindow'
import { HistoryWindow } from './windows/history/HistoryWindow'
import { initI18n } from './i18n'
import { useConfigStore } from './config/store'

export function App() {
  const [windowType, setWindowType] = useState<string>('floating')
  const [i18nReady, setI18nReady] = useState(false)
  const language = useConfigStore((s) => s.config.general.language)

  useEffect(() => {
    getCurrentWindow().label.then(setWindowType).catch(() => setWindowType('floating'))
  }, [])

  useEffect(() => {
    initI18n(language).then(() => setI18nReady(true))
  }, [language])

  if (!i18nReady) return null

  switch (windowType) {
    case 'settings':
      return <SettingsWindow />
    case 'history':
      return <HistoryWindow />
    default:
      return <FloatingWindow />
  }
}
```

- [ ] **Step 4: Commit**

```bash
git add src/App.tsx src/hooks/
git commit -m "feat: add window router, hotkey hook, and pipeline orchestrator"
```

---

## Task 17: Final Integration + Smoke Test

- [ ] **Step 1: Run all tests**

```bash
npm test
```

Expected: All tests pass.

- [ ] **Step 2: Verify Rust compiles**

```bash
cd src-tauri && cargo check
```

Expected: No errors.

- [ ] **Step 3: Run the full app**

```bash
npm run tauri dev
```

Expected: Floating window appears with idle pill ("Verbo" + hotkey hint). System tray icon visible. No console errors.

- [ ] **Step 4: Verify settings window opens**

From system tray → click Settings. Expected: Settings window opens with scene list.

- [ ] **Step 5: Verify history window opens**

From system tray → click History. Expected: History window opens (empty list).

- [ ] **Step 6: Final commit**

```bash
git add -A
git status  # Verify only expected files
git commit -m "feat: complete Verbo v0.1.0 MVP integration"
```

- [ ] **Step 7: Clean up smoke test**

```bash
git rm tests/smoke.test.ts
git commit -m "chore: remove smoke test"
```
