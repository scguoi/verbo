# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test Commands

All commands run from `Verbo/` directory (or use `cd Verbo && ...`):

```bash
make build              # xcodegen generate + xcodebuild
make test               # All tests (skips TextOutputServiceTests — needs CGEvent)
make test-unit          # Fast subset: Models, Adapters, Core, ViewModels
make test-integration   # Unit + integration (skips View smoke)
make deploy             # Build → copy to /Applications/Verbo.app → launch
make clean              # Remove DerivedData
```

Run a single test suite:
```bash
cd Verbo && xcodegen generate && xcodebuild test -project Verbo.xcodeproj -scheme VerboTests \
  -only-testing:VerboTests/FloatingViewModelTests
```

After adding/removing source files, always run `xcodegen generate` before building — the `.xcodeproj` is generated from `project.yml`.

## Architecture

**Verbo** is a native macOS voice input tool (Swift 6, macOS 14+). Users record audio → STT transcribes → optional LLM processes → text outputs to focused app.

### Layer Separation

- **AppKit layer** (`AppDelegate.swift`): NSStatusItem (tray), FloatingPanel (NSPanel subclass), window management, hotkey registration
- **SwiftUI layer** (`Views/`, `ViewModels/`): Observable ViewModels drive UI. FloatingPanelView is hosted inside NSPanel via NSHostingView
- **Core layer** (`Core/`): PipelineEngine (actor), AudioRecorder (actor), ConfigManager, HistoryManager, HotkeyManager, TextOutputService
- **Adapter layer** (`Adapters/`): Protocol-based STT/LLM providers. Currently: iFlytek WebSocket STT, OpenAI-compatible SSE LLM

### Pipeline Flow

Scenes define ordered pipeline steps in JSON config. PipelineEngine executes sequentially — each step's output becomes `{{input}}` for the next:

```
AudioRecorder (AsyncStream<Data>) → STT Adapter (streaming) → LLM Adapter (streaming) → TextOutputService
```

State machine: `idle → recording → transcribing(partial) → processing(source, partial) → done(result, source) → idle`

### Concurrency Model

- **Actors**: PipelineEngine, AudioRecorder (thread-safe mutable state)
- **@MainActor @Observable**: FloatingViewModel, ConfigManager, HistoryManager, HotkeyManager (UI-bound)
- **Sendable protocols**: STTAdapter, LLMAdapter, AudioRecording, TextOutputting

### Dependency Injection

FloatingViewModel accepts protocols via init for testability:
```swift
init(audioRecorder: any AudioRecording = AudioRecorder(),
     textOutputService: any TextOutputting = TextOutputService(),
     pipelineEngine: PipelineEngine = PipelineEngine())
```

PipelineEngine.execute() takes `getSTT`/`getLLM` closures — tests inject MockSTTAdapter/MockLLMAdapter.

## Data Storage

All app data lives in `~/.verbo/`:
- `config.json` — scenes, provider API keys, general settings
- `history.json` — input history records
- `debug.log` — debug-build-only file log

## Key Conventions

- **XcodeGen**: Project defined in `Verbo/project.yml`. Never edit `.xcodeproj` directly.
- **Swift 6 strict concurrency**: All types must be Sendable-correct. Use `@unchecked Sendable` for adapter classes with URLSession.
- **Logging**: Use `Log.stt/llm/audio/pipeline/config/hotkey/ui` (os.log-based). Debug-level logs compile out in Release.
- **Codable robustness**: All config structs use `decodeIfPresent` with defaults for new fields — missing fields must never crash JSON decoding.
- **FloatingPanel**: Fixed-width window (450px), transparent background. Pill anchored right, toast appears left. Window never resizes horizontally.

## Testing

161 tests across 24 suites. Test helpers in `VerboTests/TestHelpers/`:
- `MockSTTAdapter`, `MockLLMAdapter` — configurable results + error injection
- `MockAudioRecorder` — simulates audio stream without hardware
- `MockTextOutputService` — records output calls without CGEvent
- `TestFixtures` — factory methods for AppConfig, Scene, HistoryRecord, audio streams, iFlytek JSON samples

TextOutputServiceTests are skipped in CI/headless (`-skip-testing:VerboTests/TextOutputServiceTests`) because CGEvent requires a display.
