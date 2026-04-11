import { describe, it, expect, beforeEach } from 'vitest'
import i18n from 'i18next'
import { zhCN } from '../../src/i18n/zh-CN'
import { en } from '../../src/i18n/en'
import { initI18n } from '../../src/i18n'

// ── helpers ──────────────────────────────────────────────────────────

/** Recursively collect all leaf keys as dot-separated paths */
function flattenKeys(obj: Record<string, unknown>, prefix = ''): string[] {
  return Object.entries(obj).flatMap(([key, value]) => {
    const path = prefix ? `${prefix}.${key}` : key
    if (typeof value === 'object' && value !== null && !Array.isArray(value)) {
      return flattenKeys(value as Record<string, unknown>, path)
    }
    return [path]
  })
}

// ── unit tests ───────────────────────────────────────────────────────

describe('i18n translation files', () => {
  it('zh-CN and en have identical keys', () => {
    const zhKeys = flattenKeys(zhCN).sort()
    const enKeys = flattenKeys(en).sort()
    expect(zhKeys).toEqual(enKeys)
  })

  it('has all floating window keys', () => {
    const requiredKeys = [
      'floating.ready',
      'floating.listening',
      'floating.processing',
      'floating.polishing',
      'floating.translating',
      'floating.done',
      'floating.error',
      'floating.offline',
      'floating.copy',
      'floating.retry',
      'floating.settings',
      'floating.inserted',
      'floating.copied',
      'floating.failed',
    ]
    const enKeys = flattenKeys(en)
    for (const key of requiredKeys) {
      expect(enKeys).toContain(key)
    }
  })

  it('has all settings keys', () => {
    const requiredKeys = [
      'settings.title',
      'settings.scenes',
      'settings.providers',
      'settings.general',
      'settings.about',
      'settings.scenesDesc',
      'settings.newScene',
      'settings.defaultBadge',
      'settings.sceneName',
      'settings.pipelineSteps',
      'settings.addStep',
      'settings.outputMode',
      'settings.simulateInput',
      'settings.clipboard',
      'settings.hotkeyToggle',
      'settings.hotkeyPush',
      'settings.clickToRecord',
      'settings.save',
      'settings.cancel',
      'settings.providersDesc',
      'settings.sttSection',
      'settings.llmSection',
      'settings.connected',
      'settings.supportedLangs',
      'settings.supportedLangsHint',
      'settings.addSttProvider',
      'settings.addLlmProvider',
      'settings.generalDesc',
      'settings.globalHotkeys',
      'settings.globalHotkeysHint',
      'settings.behavior',
      'settings.defaultOutputMode',
      'settings.autoCollapseDelay',
      'settings.launchAtStartup',
      'settings.uiLanguage',
      'settings.followSystem',
      'settings.data',
      'settings.historyRetention',
      'settings.configPath',
      'settings.forever',
      'settings.enabled',
      'settings.disabled',
      'settings.aboutVersion',
    ]
    const enKeys = flattenKeys(en)
    for (const key of requiredKeys) {
      expect(enKeys).toContain(key)
    }
  })

  it('has all history keys', () => {
    const requiredKeys = [
      'history.title',
      'history.search',
      'history.allScenes',
      'history.today',
      'history.yesterday',
      'history.copy',
      'history.viewOriginal',
      'history.clearAll',
      'history.records',
      'history.inserted',
      'history.copied',
      'history.failed',
    ]
    const enKeys = flattenKeys(en)
    for (const key of requiredKeys) {
      expect(enKeys).toContain(key)
    }
  })

  it('has all tray keys', () => {
    const enKeys = flattenKeys(en)
    expect(enKeys).toContain('tray.history')
    expect(enKeys).toContain('tray.settings')
    expect(enKeys).toContain('tray.quit')
  })

  it('has all stt keys', () => {
    const enKeys = flattenKeys(en)
    expect(enKeys).toContain('stt.speechToText')
  })

  it('has all llm keys', () => {
    const enKeys = flattenKeys(en)
    expect(enKeys).toContain('llm.llmTransform')
    expect(enKeys).toContain('llm.promptHint')
  })

  it('has all common keys', () => {
    const enKeys = flattenKeys(en)
    expect(enKeys).toContain('common.engine')
    expect(enKeys).toContain('common.language')
    expect(enKeys).toContain('common.provider')
    expect(enKeys).toContain('common.model')
  })

  it('all values are non-empty strings', () => {
    const checkValues = (obj: Record<string, unknown>, path = '') => {
      for (const [key, value] of Object.entries(obj)) {
        const fullPath = path ? `${path}.${key}` : key
        if (typeof value === 'object' && value !== null && !Array.isArray(value)) {
          checkValues(value as Record<string, unknown>, fullPath)
        } else {
          expect(value, `${fullPath} should be a non-empty string`).toBeTypeOf('string')
          expect((value as string).length, `${fullPath} should not be empty`).toBeGreaterThan(0)
        }
      }
    }
    checkValues(en)
    checkValues(zhCN)
  })
})

// ── interface-level tests ────────────────────────────────────────────

describe('initI18n', () => {
  beforeEach(() => {
    // Reset i18n state between tests
    if (i18n.isInitialized) {
      i18n.changeLanguage('en')
    }
  })

  it('sets language to English when initialized with "en"', async () => {
    await initI18n('en')
    expect(i18n.language).toBe('en')
    expect(i18n.t('floating.ready')).toBe(en.floating.ready)
  })

  it('sets language to Chinese when initialized with "zh-CN"', async () => {
    await initI18n('zh-CN')
    expect(i18n.language).toBe('zh-CN')
    expect(i18n.t('floating.ready')).toBe(zhCN.floating.ready)
  })

  it('falls back to English for unknown locale', async () => {
    await initI18n('en')
    // Access a key with a non-existent language to verify fallback
    await i18n.changeLanguage('fr')
    expect(i18n.t('floating.ready')).toBe(en.floating.ready)
  })
})
