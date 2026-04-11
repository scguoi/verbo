import { describe, it, expect, beforeEach } from 'vitest'
import { DEFAULT_CONFIG } from '../src/config/defaults'
import { useConfigStore } from '../src/config/store'
import type { AppConfig } from '../src/types'

describe('DEFAULT_CONFIG', () => {
  it('has version 1', () => {
    expect(DEFAULT_CONFIG.version).toBe(1)
  })

  it('has defaultScene "dictate"', () => {
    expect(DEFAULT_CONFIG.defaultScene).toBe('dictate')
  })

  it('has correct global hotkeys', () => {
    expect(DEFAULT_CONFIG.globalHotkey.toggleRecord).toBe('CommandOrControl+Shift+H')
    expect(DEFAULT_CONFIG.globalHotkey.pushToTalk).toBe('CommandOrControl+Shift+G')
  })

  it('dictate scene has stt-only pipeline', () => {
    const dictate = DEFAULT_CONFIG.scenes.find((s) => s.id === 'dictate')
    expect(dictate).toBeDefined()
    expect(dictate!.pipeline).toHaveLength(1)
    expect(dictate!.pipeline[0].type).toBe('stt')
    expect(dictate!.hotkey.toggleRecord).toBe('Alt+D')
  })

  it('polish scene has stt + llm pipeline', () => {
    const polish = DEFAULT_CONFIG.scenes.find((s) => s.id === 'polish')
    expect(polish).toBeDefined()
    expect(polish!.pipeline).toHaveLength(2)
    expect(polish!.pipeline[0].type).toBe('stt')
    expect(polish!.pipeline[1].type).toBe('llm')
    expect(polish!.hotkey.toggleRecord).toBe('Alt+J')
  })

  it('translate scene has stt + llm pipeline', () => {
    const translate = DEFAULT_CONFIG.scenes.find((s) => s.id === 'translate')
    expect(translate).toBeDefined()
    expect(translate!.pipeline).toHaveLength(2)
    expect(translate!.pipeline[0].type).toBe('stt')
    expect(translate!.pipeline[1].type).toBe('llm')
    expect(translate!.hotkey.toggleRecord).toBe('Alt+T')
  })

  it('iflytek provider has zh and en enabled', () => {
    const iflytek = DEFAULT_CONFIG.providers.stt.iflytek
    expect(iflytek).toBeDefined()
    expect(iflytek.enabledLangs).toContain('zh')
    expect(iflytek.enabledLangs).toContain('en')
  })

  it('openai provider has correct baseUrl', () => {
    const openai = DEFAULT_CONFIG.providers.llm.openai
    expect(openai).toBeDefined()
    expect(openai.baseUrl).toBe('https://api.openai.com/v1')
    expect(openai.model).toBe('gpt-4o-mini')
    expect(openai.apiKey).toBe('')
  })

  it('general config has sensible defaults', () => {
    const { general } = DEFAULT_CONFIG
    expect(general.defaultOutput).toBe('simulate')
    expect(general.autoCollapseDelay).toBe(1500)
    expect(general.launchAtStartup).toBe(false)
    expect(general.language).toBe('system')
    expect(general.historyRetentionDays).toBe(30)
  })

  it('has exactly 3 scenes', () => {
    expect(DEFAULT_CONFIG.scenes).toHaveLength(3)
  })
})

describe('useConfigStore', () => {
  beforeEach(() => {
    useConfigStore.setState({ config: DEFAULT_CONFIG })
  })

  it('initializes with DEFAULT_CONFIG', () => {
    const { config } = useConfigStore.getState()
    expect(config).toEqual(DEFAULT_CONFIG)
  })

  it('setConfig replaces entire config', () => {
    const newConfig: AppConfig = {
      ...DEFAULT_CONFIG,
      version: 2,
      defaultScene: 'polish',
    }
    useConfigStore.getState().setConfig(newConfig)
    const { config } = useConfigStore.getState()
    expect(config.version).toBe(2)
    expect(config.defaultScene).toBe('polish')
  })

  it('updateScene immutably updates a scene (original not mutated)', () => {
    const originalConfig = useConfigStore.getState().config
    const originalDictate = originalConfig.scenes.find((s) => s.id === 'dictate')

    useConfigStore.getState().updateScene('dictate', { name: 'Dictation Updated' })

    const updatedConfig = useConfigStore.getState().config
    const updatedDictate = updatedConfig.scenes.find((s) => s.id === 'dictate')

    // New value applied
    expect(updatedDictate!.name).toBe('Dictation Updated')
    // Original not mutated
    expect(originalDictate!.name).not.toBe('Dictation Updated')
    // Config reference changed
    expect(updatedConfig).not.toBe(originalConfig)
    expect(updatedConfig.scenes).not.toBe(originalConfig.scenes)
  })

  it('getScene returns correct scene', () => {
    const scene = useConfigStore.getState().getScene('polish')
    expect(scene).toBeDefined()
    expect(scene!.id).toBe('polish')
  })

  it('getScene returns undefined for non-existent id', () => {
    const scene = useConfigStore.getState().getScene('non-existent')
    expect(scene).toBeUndefined()
  })

  it('getDefaultScene returns the default scene', () => {
    const scene = useConfigStore.getState().getDefaultScene()
    expect(scene).toBeDefined()
    expect(scene!.id).toBe('dictate')
  })

  it('updateScene with non-existent id does not crash', () => {
    const configBefore = useConfigStore.getState().config
    useConfigStore.getState().updateScene('non-existent', { name: 'Nope' })
    const configAfter = useConfigStore.getState().config
    // Config should remain unchanged
    expect(configAfter.scenes).toEqual(configBefore.scenes)
  })
})
