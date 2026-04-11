import { describe, it, expect } from 'vitest'
import type {
  STTStep,
  LLMStep,
  PipelineStep,
  SceneHotkey,
  OutputMode,
  Scene,
  PipelineState,
  GlobalHotkey,
  STTProviderConfig,
  LLMProviderConfig,
  ProvidersConfig,
  GeneralConfig,
  AppConfig,
  OutputStatus,
  HistoryRecord,
} from '../src/types'

describe('pipeline types', () => {
  it('should create a valid STTStep', () => {
    const step: STTStep = {
      type: 'stt',
      provider: 'whisper',
      lang: 'zh-CN',
    }
    expect(step.type).toBe('stt')
    expect(step.provider).toBe('whisper')
    expect(step.lang).toBe('zh-CN')
  })

  it('should create a valid LLMStep', () => {
    const step: LLMStep = {
      type: 'llm',
      provider: 'openai',
      prompt: 'Translate to English',
    }
    expect(step.type).toBe('llm')
    expect(step.provider).toBe('openai')
    expect(step.prompt).toBe('Translate to English')
  })

  it('should discriminate PipelineStep union by type field', () => {
    const steps: PipelineStep[] = [
      { type: 'stt', provider: 'whisper', lang: 'en' },
      { type: 'llm', provider: 'openai', prompt: 'summarize' },
    ]

    for (const step of steps) {
      if (step.type === 'stt') {
        // TypeScript narrows to STTStep here
        expect(step.lang).toBeDefined()
      } else {
        // TypeScript narrows to LLMStep here
        expect(step.prompt).toBeDefined()
      }
    }
  })

  it('should create a valid SceneHotkey with nullable fields', () => {
    const hotkey: SceneHotkey = {
      toggleRecord: 'Ctrl+Shift+R',
      pushToTalk: null,
    }
    expect(hotkey.toggleRecord).toBe('Ctrl+Shift+R')
    expect(hotkey.pushToTalk).toBeNull()
  })

  it('should accept valid OutputMode values', () => {
    const modes: OutputMode[] = ['simulate', 'clipboard']
    expect(modes).toHaveLength(2)
    expect(modes).toContain('simulate')
    expect(modes).toContain('clipboard')
  })

  it('should create a valid Scene', () => {
    const scene: Scene = {
      id: 'scene-1',
      name: 'Translation',
      hotkey: { toggleRecord: 'Ctrl+1', pushToTalk: null },
      pipeline: [
        { type: 'stt', provider: 'whisper', lang: 'zh-CN' },
        { type: 'llm', provider: 'openai', prompt: 'Translate to English' },
      ],
      output: 'clipboard',
    }
    expect(scene.id).toBe('scene-1')
    expect(scene.pipeline).toHaveLength(2)
    expect(scene.output).toBe('clipboard')
  })

  describe('PipelineState discriminated union', () => {
    it('should handle idle state', () => {
      const state: PipelineState = { status: 'idle' }
      expect(state.status).toBe('idle')
    })

    it('should handle recording state with startedAt', () => {
      const state: PipelineState = { status: 'recording', startedAt: Date.now() }
      if (state.status === 'recording') {
        expect(state.startedAt).toBeGreaterThan(0)
      }
    })

    it('should handle transcribing state with partialText', () => {
      const state: PipelineState = { status: 'transcribing', partialText: 'hello' }
      if (state.status === 'transcribing') {
        expect(state.partialText).toBe('hello')
      }
    })

    it('should handle processing state with sourceText and partialResult', () => {
      const state: PipelineState = {
        status: 'processing',
        sourceText: 'hello',
        partialResult: 'hel',
      }
      if (state.status === 'processing') {
        expect(state.sourceText).toBe('hello')
        expect(state.partialResult).toBe('hel')
      }
    })

    it('should handle done state with sourceText and finalText', () => {
      const state: PipelineState = {
        status: 'done',
        sourceText: 'hello',
        finalText: 'Hello!',
      }
      if (state.status === 'done') {
        expect(state.sourceText).toBe('hello')
        expect(state.finalText).toBe('Hello!')
      }
    })

    it('should handle error state with message', () => {
      const state: PipelineState = { status: 'error', message: 'Network error' }
      if (state.status === 'error') {
        expect(state.message).toBe('Network error')
      }
    })

    it('should narrow types correctly via switch', () => {
      const states: PipelineState[] = [
        { status: 'idle' },
        { status: 'recording', startedAt: 1000 },
        { status: 'transcribing', partialText: '' },
        { status: 'processing', sourceText: 'a', partialResult: 'b' },
        { status: 'done', sourceText: 'a', finalText: 'b' },
        { status: 'error', message: 'fail' },
      ]

      for (const state of states) {
        switch (state.status) {
          case 'idle':
            expect(Object.keys(state)).toEqual(['status'])
            break
          case 'recording':
            expect(state.startedAt).toBe(1000)
            break
          case 'transcribing':
            expect(state.partialText).toBe('')
            break
          case 'processing':
            expect(state.sourceText).toBe('a')
            expect(state.partialResult).toBe('b')
            break
          case 'done':
            expect(state.sourceText).toBe('a')
            expect(state.finalText).toBe('b')
            break
          case 'error':
            expect(state.message).toBe('fail')
            break
        }
      }
    })
  })
})

describe('config types', () => {
  it('should create a valid GlobalHotkey', () => {
    const hotkey: GlobalHotkey = {
      toggleRecord: 'Ctrl+Shift+R',
      pushToTalk: 'Ctrl+Space',
    }
    expect(hotkey.toggleRecord).toBe('Ctrl+Shift+R')
    expect(hotkey.pushToTalk).toBe('Ctrl+Space')
  })

  it('should create a valid STTProviderConfig with index signature', () => {
    const config: STTProviderConfig = {
      enabledLangs: ['zh-CN', 'en'],
      customField: 'value',
    }
    expect(config.enabledLangs).toEqual(['zh-CN', 'en'])
    expect(config['customField']).toBe('value')
  })

  it('should create a valid LLMProviderConfig', () => {
    const config: LLMProviderConfig = {
      apiKey: 'sk-test',
      model: 'gpt-4',
      baseUrl: 'https://api.openai.com/v1',
    }
    expect(config.apiKey).toBe('sk-test')
    expect(config.model).toBe('gpt-4')
    expect(config.baseUrl).toBe('https://api.openai.com/v1')
  })

  it('should create a valid ProvidersConfig', () => {
    const providers: ProvidersConfig = {
      stt: {
        whisper: { enabledLangs: ['zh-CN', 'en'] },
      },
      llm: {
        openai: {
          apiKey: 'sk-test',
          model: 'gpt-4',
          baseUrl: 'https://api.openai.com/v1',
        },
      },
    }
    expect(Object.keys(providers.stt)).toEqual(['whisper'])
    expect(Object.keys(providers.llm)).toEqual(['openai'])
  })

  it('should create a valid GeneralConfig', () => {
    const general: GeneralConfig = {
      defaultOutput: 'simulate',
      autoCollapseDelay: 3000,
      launchAtStartup: true,
      language: 'zh-CN',
      historyRetentionDays: 30,
    }
    expect(general.defaultOutput).toBe('simulate')
    expect(general.language).toBe('zh-CN')
  })

  it('should create a valid AppConfig', () => {
    const config: AppConfig = {
      version: 1,
      defaultScene: 'scene-1',
      globalHotkey: {
        toggleRecord: 'Ctrl+Shift+R',
        pushToTalk: 'Ctrl+Space',
      },
      scenes: [
        {
          id: 'scene-1',
          name: 'Default',
          hotkey: { toggleRecord: null, pushToTalk: null },
          pipeline: [{ type: 'stt', provider: 'whisper', lang: 'zh-CN' }],
          output: 'clipboard',
        },
      ],
      providers: {
        stt: { whisper: { enabledLangs: ['zh-CN'] } },
        llm: {
          openai: {
            apiKey: 'sk-test',
            model: 'gpt-4',
            baseUrl: 'https://api.openai.com/v1',
          },
        },
      },
      general: {
        defaultOutput: 'simulate',
        autoCollapseDelay: 3000,
        launchAtStartup: false,
        language: 'system',
        historyRetentionDays: 30,
      },
    }
    expect(config.version).toBe(1)
    expect(config.scenes).toHaveLength(1)
    expect(config.general.language).toBe('system')
  })
})

describe('history types', () => {
  it('should accept valid OutputStatus values', () => {
    const statuses: OutputStatus[] = ['inserted', 'copied', 'failed']
    expect(statuses).toHaveLength(3)
  })

  it('should create a valid HistoryRecord', () => {
    const record: HistoryRecord = {
      id: 'rec-1',
      timestamp: Date.now(),
      sceneId: 'scene-1',
      sceneName: 'Translation',
      originalText: 'hello',
      finalText: 'Hello!',
      outputStatus: 'inserted',
      pipelineSteps: ['stt:whisper', 'llm:openai'],
    }
    expect(record.id).toBe('rec-1')
    expect(record.pipelineSteps).toHaveLength(2)
    expect(record.outputStatus).toBe('inserted')
  })
})

describe('barrel re-exports', () => {
  it('should export all types from index', async () => {
    // Verify the barrel file can be imported without errors
    const types = await import('../src/types')
    expect(types).toBeDefined()
  })
})
