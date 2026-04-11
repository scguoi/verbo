import { createStore } from 'zustand/vanilla'
import type { HistoryRecord, OutputStatus } from '../types/history'

export interface NewRecord {
  readonly sceneId: string
  readonly sceneName: string
  readonly originalText: string
  readonly finalText: string
  readonly outputStatus: OutputStatus
  readonly pipelineSteps: readonly string[]
}

export interface HistoryStore {
  readonly records: readonly HistoryRecord[]
  readonly addRecord: (newRecord: NewRecord) => void
  readonly clearAll: () => void
  readonly search: (query: string) => readonly HistoryRecord[]
  readonly filterByScene: (sceneId: string) => readonly HistoryRecord[]
}

const generateId = (): string =>
  `${Date.now()}-${Math.random().toString(36).slice(2, 9)}`

export const createHistoryStore = () =>
  createStore<HistoryStore>((set, get) => ({
    records: [],

    addRecord: (newRecord: NewRecord) => {
      const record: HistoryRecord = {
        ...newRecord,
        id: generateId(),
        timestamp: Date.now(),
      }
      set({ records: [record, ...get().records] })
    },

    clearAll: () => {
      set({ records: [] })
    },

    search: (query: string) => {
      const lowerQuery = query.toLowerCase()
      return get().records.filter(
        (r) =>
          r.finalText.toLowerCase().includes(lowerQuery) ||
          r.originalText.toLowerCase().includes(lowerQuery),
      )
    },

    filterByScene: (sceneId: string) => {
      return get().records.filter((r) => r.sceneId === sceneId)
    },
  }))
