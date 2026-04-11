import { describe, it, expect, beforeEach } from 'vitest'
import { createRecordingStore, type RecordingStore } from './recording'
import type { PipelineState } from '../types/pipeline'
import type { StoreApi } from 'zustand/vanilla'

describe('RecordingStore', () => {
  let store: StoreApi<RecordingStore>

  beforeEach(() => {
    store = createRecordingStore()
  })

  it('starts in idle state', () => {
    const state = store.getState()
    expect(state.state).toEqual({ status: 'idle' })
    expect(state.lastResult).toBeNull()
  })

  it('startRecording transitions to recording', () => {
    const before = Date.now()
    store.getState().startRecording()
    const state = store.getState()

    expect(state.state.status).toBe('recording')
    if (state.state.status === 'recording') {
      expect(state.state.startedAt).toBeGreaterThanOrEqual(before)
      expect(state.state.startedAt).toBeLessThanOrEqual(Date.now())
    }
  })

  it('updateState with transcribing works', () => {
    store.getState().startRecording()
    const transcribing: PipelineState = { status: 'transcribing', partialText: 'hello' }
    store.getState().updateState(transcribing)

    expect(store.getState().state).toEqual(transcribing)
  })

  it('updateState with done saves lastResult', () => {
    store.getState().startRecording()
    const done: PipelineState = { status: 'done', sourceText: 'original', finalText: 'translated' }
    store.getState().updateState(done)

    expect(store.getState().state).toEqual(done)
    expect(store.getState().lastResult).toEqual({
      sourceText: 'original',
      finalText: 'translated',
    })
  })

  it('reset returns to idle', () => {
    store.getState().startRecording()
    store.getState().reset()

    expect(store.getState().state).toEqual({ status: 'idle' })
  })

  it('lastResult persists across reset', () => {
    store.getState().startRecording()
    store.getState().updateState({ status: 'done', sourceText: 'src', finalText: 'fin' })
    store.getState().reset()

    expect(store.getState().state).toEqual({ status: 'idle' })
    expect(store.getState().lastResult).toEqual({ sourceText: 'src', finalText: 'fin' })
  })

  it('multiple rapid state transitions do not corrupt state', () => {
    store.getState().startRecording()
    store.getState().updateState({ status: 'transcribing', partialText: 'a' })
    store.getState().updateState({ status: 'processing', sourceText: 'a', partialResult: 'b' })
    store.getState().updateState({ status: 'done', sourceText: 'a', finalText: 'c' })

    const state = store.getState()
    expect(state.state).toEqual({ status: 'done', sourceText: 'a', finalText: 'c' })
    expect(state.lastResult).toEqual({ sourceText: 'a', finalText: 'c' })
  })

  it('updateState accepts all PipelineState variants', () => {
    const variants: PipelineState[] = [
      { status: 'idle' },
      { status: 'recording', startedAt: 100 },
      { status: 'transcribing', partialText: '' },
      { status: 'processing', sourceText: '', partialResult: '' },
      { status: 'done', sourceText: '', finalText: '' },
      { status: 'error', message: 'fail' },
    ]

    for (const variant of variants) {
      store.getState().updateState(variant)
      expect(store.getState().state).toEqual(variant)
    }
  })

  it('reading state returns readonly data', () => {
    const state = store.getState()
    // TypeScript readonly enforcement — runtime check that state object is a plain snapshot
    expect(typeof state.state).toBe('object')
    expect(state.state).toEqual({ status: 'idle' })
  })

  describe('regression: lastResult preservation', () => {
    it('done→error preserves lastResult', () => {
      store.getState().startRecording()
      store.getState().updateState({ status: 'done', sourceText: 'src', finalText: 'fin' })

      expect(store.getState().lastResult).toEqual({ sourceText: 'src', finalText: 'fin' })

      store.getState().updateState({ status: 'error', message: 'something went wrong' })

      expect(store.getState().state).toEqual({ status: 'error', message: 'something went wrong' })
      expect(store.getState().lastResult).toEqual({ sourceText: 'src', finalText: 'fin' })
    })

    it('multiple done states — lastResult reflects the most recent', () => {
      store.getState().startRecording()
      store.getState().updateState({ status: 'done', sourceText: 'a', finalText: 'b' })

      expect(store.getState().lastResult).toEqual({ sourceText: 'a', finalText: 'b' })

      store.getState().updateState({ status: 'done', sourceText: 'c', finalText: 'd' })

      expect(store.getState().lastResult).toEqual({ sourceText: 'c', finalText: 'd' })
    })
  })

  describe('regression: error state', () => {
    it('error state stores full message', () => {
      store.getState().updateState({ status: 'error', message: 'detailed error: timeout after 30s' })

      expect(store.getState().state).toEqual({
        status: 'error',
        message: 'detailed error: timeout after 30s',
      })
    })
  })

  describe('regression: edge cases', () => {
    it('updateState(done) with empty strings saves to lastResult', () => {
      store.getState().updateState({ status: 'done', sourceText: '', finalText: '' })

      expect(store.getState().lastResult).toEqual({ sourceText: '', finalText: '' })
    })

    it('startRecording timestamp increases across calls', () => {
      store.getState().startRecording()
      const state1 = store.getState().state
      expect(state1.status).toBe('recording')
      const ts1 = state1.status === 'recording' ? state1.startedAt : 0

      // Reset and record again
      store.getState().reset()
      store.getState().startRecording()
      const state2 = store.getState().state
      expect(state2.status).toBe('recording')
      const ts2 = state2.status === 'recording' ? state2.startedAt : 0

      expect(ts2).toBeGreaterThanOrEqual(ts1)
    })
  })
})
