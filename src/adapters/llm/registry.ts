import type { LLMAdapter } from './types'

export interface LLMRegistry {
  register(adapter: LLMAdapter): void
  get(name: string): LLMAdapter | undefined
  list(): readonly string[]
}

export function createLLMRegistry(): LLMRegistry {
  const adapters = new Map<string, LLMAdapter>()

  return {
    register(adapter: LLMAdapter): void {
      adapters.set(adapter.name, adapter)
    },

    get(name: string): LLMAdapter | undefined {
      return adapters.get(name)
    },

    list(): readonly string[] {
      return [...adapters.keys()]
    },
  }
}
