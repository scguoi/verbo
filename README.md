# Verbo

A native macOS voice input tool. Press a hotkey, speak, and the transcribed (and optionally post-processed) text is typed into whichever app you were using.

Verbo is built for people who dictate a lot and want full control over the pipeline: pick your own STT provider, chain an LLM on top to polish / translate / reformat, and bind the whole thing to any key — including bare modifiers like Right Option or the Fn / 🌐 key.

## Features

- **Menu-bar app with a floating pill**. No dock icon, no focus stealing. The pill sits in the corner and shows recording state.
- **Configurable scenes.** Each scene is a named pipeline (STT → optional LLM → output). Switch between scenes via per-scene hotkeys. Shipped presets: dictate, polish, translate.
- **Any key can be a hotkey**, including `Fn` / 🌐, bare `Right Option`, bare `Right Command`, or any modifier combo. Captured via a dedicated-thread `CGEventTap`, so the Fn key actually works on modern macOS.
- **Streaming STT** via iFlytek WebSocket. Partial results appear as you speak.
- **LLM post-processing** via any OpenAI-compatible endpoint (OpenAI, Azure, local models through OpenRouter / vLLM / Ollama, …). Configure provider / model / base URL / prompt per scene.
- **Smart target routing.** Verbo tracks the frontmost non-self app when you start recording, so the text lands in the window you were actually using — even if focus shifted to a system notification or Verbo's own UI in between.
- **End-to-end latency metric** per recording, with a rolling average shown in the status-bar menu.
- **Input history** stored in `~/.verbo/history.json`.
- **Dark mode**, full i18n (zh / en), push-to-talk or toggle modes.

## Requirements

- macOS 14 Sonoma or later
- Apple Silicon (the shipped release is arm64; Intel builds can be made from source)
- Microphone permission (prompted on first record)
- Accessibility permission — required for Fn / modifier-only hotkeys and for simulated typing. You'll be prompted on first launch.

## Install

### From release (recommended)

1. Download `Verbo-x.y.z.zip` from the [Releases](https://github.com/scguoi/verbo/releases) page.
2. Unzip and drag `Verbo.app` into `/Applications`.
3. The release is signed with an Apple Development certificate but not notarized, so Gatekeeper will complain on first launch. Either:
   - **Right-click** `Verbo.app` → **Open** → confirm in the dialog, or
   - Run `xattr -cr /Applications/Verbo.app` once to clear the quarantine flag.
4. Launch Verbo. When prompted, grant **Microphone** and **Accessibility** permissions in System Settings → Privacy & Security.
5. Open **Settings** from the menu bar icon and fill in your iFlytek / LLM provider credentials.

### From source

```bash
brew install xcodegen
git clone https://github.com/scguoi/verbo.git
cd verbo/Verbo
make build        # xcodegen generate + xcodebuild Debug
make deploy       # build → copy to /Applications → launch
make test         # run the full test suite (161 tests)
```

All commands are also documented in [`CLAUDE.md`](CLAUDE.md).

## Configuration

All user state lives under `~/.verbo/`:

| File | Purpose |
|------|---------|
| `config.json` | scenes, provider credentials, general settings |
| `history.json` | per-recording history with latency + pipeline info |
| `debug.log` | timestamped trace log (DEBUG builds and the `DebugLog` hot-path markers) |

You can edit scenes / hotkeys / providers from the Settings window; the pill auto-refreshes when config changes.

### Scenes

A scene is an ordered list of pipeline steps. Each step is either an STT or LLM call. The STT result becomes the input for the next LLM step via the `{{input}}` placeholder in the prompt.

Example:

```
dictate:   [ STT(iflytek, zh) ] → simulate typing
polish:    [ STT(iflytek, zh) ] → [ LLM(gpt-4o-mini, "Polish: {{input}}") ] → simulate typing
translate: [ STT(iflytek, zh) ] → [ LLM(gpt-4o-mini, "Translate to English: {{input}}") ] → simulate typing
```

### Hotkeys

Every scene can bind a toggle-record hotkey. Accepted forms:

- Named single keys: `Fn`, `RightCommand`, `RightOption`, etc.
- Modifier combos: `Cmd+Shift+H`, `Alt+D`, `Ctrl+Space`
- Bare modifiers (single tap): `RightOption`, `Fn`

The hotkey implementation runs on a dedicated thread with a session-level `CGEventTap` in default (non-listen-only) mode so it can capture and optionally block the Fn key before the system uses it for dictation / emoji picker / input-source switching.

## Architecture

High-level layers:

```
AppKit layer    — AppDelegate, FloatingPanel (NSPanel), tray, window management
SwiftUI layer   — Views/, ViewModels/ (@MainActor @Observable)
Core layer      — PipelineEngine (actor), AudioRecorder (actor),
                  HotkeyManager, ConfigManager, HistoryManager,
                  TextOutputService
Adapters        — Sendable STT / LLM protocols + concrete providers
```

State machine:

```
idle → recording → transcribing(partial) → processing(source, partial) → done → idle
```

See [`CLAUDE.md`](CLAUDE.md) for layer conventions and concurrency rules, and [`docs/DESIGN.md`](docs/DESIGN.md) for the visual design system.

## Development notes

- The project is generated from `Verbo/project.yml` via XcodeGen. Don't edit `Verbo.xcodeproj` directly — run `xcodegen generate` after adding or removing source files.
- Swift 6 strict concurrency is enabled. Types crossing actor boundaries must be Sendable.
- Tests live in `Verbo/VerboTests/`. `TextOutputServiceTests` is skipped in headless runs because CGEvent needs a display.
- `DebugLog.write` appends timestamped (`HH:mm:ss.SSS`) lines to `~/.verbo/debug.log` from any thread and is used for latency tracing.

## License

[MIT](LICENSE) © 2026 scguoi
