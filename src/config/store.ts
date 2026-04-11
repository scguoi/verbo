import { createStore } from 'zustand/vanilla'
import type { AppConfig } from '../types/config'
import type { Scene } from '../types/pipeline'
import { DEFAULT_CONFIG } from './defaults'

export interface ConfigStore {
  readonly config: AppConfig
  readonly setConfig: (config: AppConfig) => void
  readonly updateScene: (sceneId: string, updates: Partial<Scene>) => void
  readonly getScene: (sceneId: string) => Scene | undefined
  readonly getDefaultScene: () => Scene | undefined
}

export const useConfigStore = createStore<ConfigStore>((set, get) => ({
  config: DEFAULT_CONFIG,

  setConfig: (config: AppConfig) => {
    set({ config })
  },

  updateScene: (sceneId: string, updates: Partial<Scene>) => {
    const { config } = get()
    const sceneIndex = config.scenes.findIndex((s) => s.id === sceneId)
    if (sceneIndex === -1) return

    const updatedScenes = config.scenes.map((scene) =>
      scene.id === sceneId ? { ...scene, ...updates } : scene,
    )

    set({
      config: {
        ...config,
        scenes: updatedScenes,
      },
    })
  },

  getScene: (sceneId: string) => {
    const { config } = get()
    return config.scenes.find((s) => s.id === sceneId)
  },

  getDefaultScene: () => {
    const { config } = get()
    return config.scenes.find((s) => s.id === config.defaultScene)
  },
}))
