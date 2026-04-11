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
})
