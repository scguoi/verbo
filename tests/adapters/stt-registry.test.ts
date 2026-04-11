import { describe, it, expect } from 'vitest'
import { createSTTRegistry } from '../../src/adapters/stt/registry'
import type { STTAdapter } from '../../src/adapters/stt/types'

function makeMockAdapter(name: string): STTAdapter {
  return {
    name,
    capabilities: { streaming: false },
    transcribe: async () => '',
  }
}

describe('STT adapter registry', () => {
  it('should register and retrieve an adapter', () => {
    const registry = createSTTRegistry()
    const adapter = makeMockAdapter('whisper')

    registry.register(adapter)
    expect(registry.get('whisper')).toBe(adapter)
  })

  it('should return undefined for an unknown adapter', () => {
    const registry = createSTTRegistry()
    expect(registry.get('nonexistent')).toBeUndefined()
  })

  it('should list registered adapter names', () => {
    const registry = createSTTRegistry()
    registry.register(makeMockAdapter('whisper'))
    registry.register(makeMockAdapter('iflytek'))

    const names = registry.list()
    expect(names).toEqual(['whisper', 'iflytek'])
  })

  it('should overwrite an existing adapter with the same name', () => {
    const registry = createSTTRegistry()
    const original = makeMockAdapter('whisper')
    const replacement = makeMockAdapter('whisper')

    registry.register(original)
    registry.register(replacement)

    expect(registry.get('whisper')).toBe(replacement)
    expect(registry.list()).toEqual(['whisper'])
  })

  it('should accept and return adapters that match STTAdapter interface', () => {
    const registry = createSTTRegistry()
    const adapter: STTAdapter = {
      name: 'test',
      capabilities: { streaming: true },
      transcribe: async (_audio: ArrayBuffer, _options) => 'result',
      transcribeStream: async (_stream, _options, _onPartial) => 'streamed',
    }

    registry.register(adapter)
    const retrieved = registry.get('test')

    expect(retrieved).toBeDefined()
    expect(retrieved!.name).toBe('test')
    expect(retrieved!.capabilities.streaming).toBe(true)
    expect(typeof retrieved!.transcribe).toBe('function')
    expect(typeof retrieved!.transcribeStream).toBe('function')
  })
})
