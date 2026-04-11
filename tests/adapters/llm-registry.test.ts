import { describe, it, expect } from 'vitest'
import { createLLMRegistry } from '../../src/adapters/llm/registry'
import type { LLMAdapter } from '../../src/adapters/llm/types'

function makeMockAdapter(name: string): LLMAdapter {
  return {
    name,
    complete: async () => '',
  }
}

describe('LLM adapter registry', () => {
  it('should register and retrieve an adapter', () => {
    const registry = createLLMRegistry()
    const adapter = makeMockAdapter('openai')

    registry.register(adapter)
    expect(registry.get('openai')).toBe(adapter)
  })

  it('should return undefined for an unknown adapter', () => {
    const registry = createLLMRegistry()
    expect(registry.get('nonexistent')).toBeUndefined()
  })

  it('should list registered adapter names', () => {
    const registry = createLLMRegistry()
    registry.register(makeMockAdapter('openai'))
    registry.register(makeMockAdapter('anthropic'))

    const names = registry.list()
    expect(names).toEqual(['openai', 'anthropic'])
  })

  it('should overwrite an existing adapter with the same name', () => {
    const registry = createLLMRegistry()
    const original = makeMockAdapter('openai')
    const replacement = makeMockAdapter('openai')

    registry.register(original)
    registry.register(replacement)

    expect(registry.get('openai')).toBe(replacement)
    expect(registry.list()).toEqual(['openai'])
  })

  it('should accept and return adapters that match LLMAdapter interface', () => {
    const registry = createLLMRegistry()
    const adapter: LLMAdapter = {
      name: 'test',
      complete: async (_options) => 'result',
      completeStream: async (_options, _onChunk) => 'streamed',
    }

    registry.register(adapter)
    const retrieved = registry.get('test')

    expect(retrieved).toBeDefined()
    expect(retrieved!.name).toBe('test')
    expect(typeof retrieved!.complete).toBe('function')
    expect(typeof retrieved!.completeStream).toBe('function')
  })
})
