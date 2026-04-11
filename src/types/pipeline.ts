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
