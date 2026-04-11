import { createStore } from 'zustand/vanilla'

export type ActiveWindow = 'floating' | 'settings' | 'history'

export interface AppStore {
  readonly currentSceneId: string
  readonly activeWindow: ActiveWindow
  readonly setCurrentScene: (sceneId: string) => void
  readonly setActiveWindow: (window: ActiveWindow) => void
}

export const createAppStore = () =>
  createStore<AppStore>((set) => ({
    currentSceneId: 'dictate',
    activeWindow: 'floating',

    setCurrentScene: (sceneId: string) => {
      set({ currentSceneId: sceneId })
    },

    setActiveWindow: (window: ActiveWindow) => {
      set({ activeWindow: window })
    },
  }))

/** Singleton instance for app-wide use */
export const appStore = createAppStore()
