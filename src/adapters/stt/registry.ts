import type { STTAdapter } from './types'

export interface STTRegistry {
  register(adapter: STTAdapter): void
  get(name: string): STTAdapter | undefined
  list(): readonly string[]
}

export function createSTTRegistry(): STTRegistry {
  const adapters = new Map<string, STTAdapter>()

  return {
    register(adapter: STTAdapter): void {
      adapters.set(adapter.name, adapter)
    },

    get(name: string): STTAdapter | undefined {
      return adapters.get(name)
    },

    list(): readonly string[] {
      return [...adapters.keys()]
    },
  }
}
