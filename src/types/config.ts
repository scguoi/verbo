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
