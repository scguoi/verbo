import { createStore } from 'zustand/vanilla'
import type { PipelineState } from '../types/pipeline'

export interface RecordingStore {
  readonly state: PipelineState
  readonly lastResult: { readonly sourceText: string; readonly finalText: string } | null
  readonly startRecording: () => void
  readonly updateState: (state: PipelineState) => void
  readonly reset: () => void
}

const IDLE_STATE: PipelineState = { status: 'idle' }

export const createRecordingStore = () =>
  createStore<RecordingStore>((set) => ({
    state: IDLE_STATE,
    lastResult: null,

    startRecording: () => {
      set({
        state: { status: 'recording', startedAt: Date.now() },
      })
    },

    updateState: (newState: PipelineState) => {
      if (newState.status === 'done') {
        set({
          state: newState,
          lastResult: {
            sourceText: newState.sourceText,
            finalText: newState.finalText,
          },
        })
      } else {
        set({ state: newState })
      }
    },

    reset: () => {
      set({ state: IDLE_STATE })
    },
  }))

/** Singleton instance for app-wide use */
export const recordingStore = createRecordingStore()
