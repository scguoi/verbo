import { describe, it, expect } from 'vitest'
import {
  createIFlytekAdapter,
  buildAuthUrl,
  mapLanguage,
  parseIFlytekResponse,
} from '../../src/adapters/stt/iflytek'
import type { STTAdapter, STTOptions } from '../../src/adapters/stt/types'

const testConfig = {
  appId: 'test-app-id',
  apiKey: 'test-api-key',
  apiSecret: 'test-api-secret',
}

describe('iFlytek STT adapter', () => {
  describe('adapter shape', () => {
    it('should have correct name', () => {
      const adapter = createIFlytekAdapter(testConfig)
      expect(adapter.name).toBe('iflytek')
    })

    it('should have streaming capability set to true', () => {
      const adapter = createIFlytekAdapter(testConfig)
      expect(adapter.capabilities.streaming).toBe(true)
    })

    it('should have transcribe method', () => {
      const adapter = createIFlytekAdapter(testConfig)
      expect(typeof adapter.transcribe).toBe('function')
    })

    it('should have transcribeStream method', () => {
      const adapter = createIFlytekAdapter(testConfig)
      expect(typeof adapter.transcribeStream).toBe('function')
    })

    it('should conform to STTAdapter interface', () => {
      const adapter: STTAdapter = createIFlytekAdapter(testConfig)
      expect(adapter.name).toBe('iflytek')
    })
  })

  describe('transcribe signature', () => {
    it('should accept ArrayBuffer and STTOptions', () => {
      const adapter = createIFlytekAdapter(testConfig)
      const audio = new ArrayBuffer(16)
      const options: STTOptions = { lang: 'zh' }

      // Verify it returns a Promise (we don't await since no real WS)
      const result = adapter.transcribe(audio, options)
      expect(result).toBeInstanceOf(Promise)
      // Let it reject gracefully (no real WebSocket)
      result.catch(() => {})
    })

    it('should accept ReadableStream, STTOptions, and callback for transcribeStream', () => {
      const adapter = createIFlytekAdapter(testConfig)
      const stream = new ReadableStream<ArrayBuffer>()
      const options: STTOptions = { lang: 'en' }
      const onPartial = (_text: string) => {}

      const result = adapter.transcribeStream!(stream, options, onPartial)
      expect(result).toBeInstanceOf(Promise)
      result.catch(() => {})
    })
  })

  describe('buildAuthUrl', () => {
    it('should produce a valid WebSocket URL', async () => {
      const url = await buildAuthUrl(testConfig)
      expect(url).toMatch(/^wss?:\/\//)
      expect(url).toContain('authorization=')
      expect(url).toContain('date=')
      expect(url).toContain('host=')
    })
  })

  describe('mapLanguage', () => {
    it('should map zh to cn_mandarin', () => {
      expect(mapLanguage('zh')).toBe('cn_mandarin')
    })

    it('should map en to en_us', () => {
      expect(mapLanguage('en')).toBe('en_us')
    })

    it('should fallback to cn_mandarin for unknown language', () => {
      expect(mapLanguage('fr')).toBe('cn_mandarin')
    })
  })

  describe('parseIFlytekResponse', () => {
    it('should extract text from iFlytek response format', () => {
      const response = {
        data: {
          result: {
            ws: [
              { cw: [{ w: 'hello' }] },
              { cw: [{ w: ' world' }] },
            ],
          },
        },
      }
      expect(parseIFlytekResponse(response)).toBe('hello world')
    })

    it('should return empty string for empty ws array', () => {
      const response = {
        data: {
          result: {
            ws: [],
          },
        },
      }
      expect(parseIFlytekResponse(response)).toBe('')
    })

    it('should handle multiple cw entries per ws item', () => {
      const response = {
        data: {
          result: {
            ws: [
              { cw: [{ w: 'a' }, { w: 'b' }] },
            ],
          },
        },
      }
      expect(parseIFlytekResponse(response)).toBe('ab')
    })

    it('should return empty string when data is missing', () => {
      expect(parseIFlytekResponse({})).toBe('')
      expect(parseIFlytekResponse({ data: {} })).toBe('')
      expect(parseIFlytekResponse({ data: { result: {} } })).toBe('')
    })
  })
})
