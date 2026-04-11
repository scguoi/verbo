import { describe, it, expect } from 'vitest'
import {
  createIFlytekAdapter,
  buildAuthUrl,
  mapLanguage,
  parseIFlytekResponse,
  createResultAccumulator,
} from './iflytek'
import type { STTAdapter, STTOptions } from './types'

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
            sn: 0,
            ws: [
              { cw: [{ w: 'hello' }] },
              { cw: [{ w: ' world' }] },
            ],
          },
        },
      }
      expect(parseIFlytekResponse(response).text).toBe('hello world')
    })

    it('should return empty string for empty ws array', () => {
      const response = {
        data: {
          result: {
            sn: 0,
            ws: [],
          },
        },
      }
      expect(parseIFlytekResponse(response).text).toBe('')
    })

    it('should handle multiple cw entries per ws item', () => {
      const response = {
        data: {
          result: {
            sn: 0,
            ws: [
              { cw: [{ w: 'a' }, { w: 'b' }] },
            ],
          },
        },
      }
      expect(parseIFlytekResponse(response).text).toBe('ab')
    })

    it('should return empty string when data is missing', () => {
      expect(parseIFlytekResponse({}).text).toBe('')
      expect(parseIFlytekResponse({ data: {} }).text).toBe('')
      expect(parseIFlytekResponse({ data: { result: {} } }).text).toBe('')
    })

    it('should extract pgs and sn fields', () => {
      const response = {
        data: {
          result: {
            sn: 2,
            pgs: 'rpl',
            rg: [1, 2],
            ws: [{ cw: [{ w: 'text' }] }],
          },
          status: 1,
        },
      }
      const parsed = parseIFlytekResponse(response)
      expect(parsed.sn).toBe(2)
      expect(parsed.pgs).toBe('rpl')
      expect(parsed.rgBegin).toBe(1)
      expect(parsed.rgEnd).toBe(2)
      expect(parsed.isLast).toBe(false)
    })

    it('should detect isLast from status 2', () => {
      const response = {
        data: {
          result: { sn: 0, ws: [] },
          status: 2,
        },
      }
      expect(parseIFlytekResponse(response).isLast).toBe(true)
    })
  })

  describe('createResultAccumulator', () => {
    it('should accumulate appended results', () => {
      const acc = createResultAccumulator()
      const r1 = acc.update({ text: 'hello', sn: 0, pgs: 'apd', rgBegin: 0, rgEnd: 0, isLast: false })
      expect(r1).toBe('hello')
      const r2 = acc.update({ text: ' world', sn: 1, pgs: 'apd', rgBegin: 0, rgEnd: 0, isLast: false })
      expect(r2).toBe('hello world')
    })

    it('should handle replace (rpl) by removing sentences in range', () => {
      const acc = createResultAccumulator()
      acc.update({ text: 'hello', sn: 0, pgs: 'apd', rgBegin: 0, rgEnd: 0, isLast: false })
      acc.update({ text: ' wor', sn: 1, pgs: 'apd', rgBegin: 0, rgEnd: 0, isLast: false })
      // Replace sn 0-1 with corrected text
      const r = acc.update({ text: 'hello world', sn: 2, pgs: 'rpl', rgBegin: 0, rgEnd: 1, isLast: false })
      expect(r).toBe('hello world')
    })

    it('should handle sequential replacements correctly', () => {
      const acc = createResultAccumulator()
      acc.update({ text: 'I', sn: 0, pgs: 'apd', rgBegin: 0, rgEnd: 0, isLast: false })
      acc.update({ text: ' thin', sn: 1, pgs: 'apd', rgBegin: 0, rgEnd: 0, isLast: false })
      // Replace partial with full word
      acc.update({ text: ' think', sn: 2, pgs: 'rpl', rgBegin: 1, rgEnd: 1, isLast: false })
      const r = acc.update({ text: ' therefore', sn: 3, pgs: 'apd', rgBegin: 0, rgEnd: 0, isLast: false })
      expect(r).toBe('I think therefore')
    })

    it('should work without pgs field (batch mode)', () => {
      const acc = createResultAccumulator()
      const r1 = acc.update({ text: 'hello', sn: 0, pgs: undefined, rgBegin: 0, rgEnd: 0, isLast: false })
      expect(r1).toBe('hello')
      const r2 = acc.update({ text: ' world', sn: 1, pgs: undefined, rgBegin: 0, rgEnd: 0, isLast: true })
      expect(r2).toBe('hello world')
    })
  })
})
