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
      name: 'Dictate',
      hotkey: { toggleRecord: 'Alt+D', pushToTalk: null },
      pipeline: [{ type: 'stt', provider: 'iflytek', lang: 'zh' }],
      output: 'simulate',
    },
    {
      id: 'polish',
      name: 'Polish',
      hotkey: { toggleRecord: 'Alt+J', pushToTalk: null },
      pipeline: [
        { type: 'stt', provider: 'iflytek', lang: 'zh' },
        {
          type: 'llm',
          provider: 'openai',
          prompt:
            'Polish the following text for clarity and grammar, keeping the original meaning. Output only the polished text.',
        },
      ],
      output: 'simulate',
    },
    {
      id: 'translate',
      name: 'Translate',
      hotkey: { toggleRecord: 'Alt+T', pushToTalk: null },
      pipeline: [
        { type: 'stt', provider: 'iflytek', lang: 'zh' },
        {
          type: 'llm',
          provider: 'openai',
          prompt:
            'Translate the following text from Chinese to English. Output only the translation.',
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
