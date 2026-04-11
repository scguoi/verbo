import { describe, it, expect, beforeEach } from 'vitest'
import { createHistoryStore, type HistoryStore, type NewRecord } from './history'
import type { StoreApi } from 'zustand/vanilla'

describe('HistoryStore', () => {
  let store: StoreApi<HistoryStore>

  beforeEach(() => {
    store = createHistoryStore()
  })

  const makeNewRecord = (overrides: Partial<NewRecord> = {}): NewRecord => ({
    sceneId: 'dictate',
    sceneName: 'Dictation',
    originalText: 'hello world',
    finalText: 'Hello, world!',
    outputStatus: 'inserted',
    pipelineSteps: ['stt', 'llm'],
    ...overrides,
  })

  it('starts empty', () => {
    expect(store.getState().records).toEqual([])
  })

  it('addRecord creates record with id and timestamp', () => {
    const before = Date.now()
    store.getState().addRecord(makeNewRecord())
    const records = store.getState().records

    expect(records).toHaveLength(1)
    expect(records[0].id).toBeDefined()
    expect(typeof records[0].id).toBe('string')
    expect(records[0].id.length).toBeGreaterThan(0)
    expect(records[0].timestamp).toBeGreaterThanOrEqual(before)
    expect(records[0].timestamp).toBeLessThanOrEqual(Date.now())
  })

  it('records are newest first (prepended)', () => {
    store.getState().addRecord(makeNewRecord({ finalText: 'first' }))
    store.getState().addRecord(makeNewRecord({ finalText: 'second' }))
    store.getState().addRecord(makeNewRecord({ finalText: 'third' }))

    const records = store.getState().records
    expect(records[0].finalText).toBe('third')
    expect(records[1].finalText).toBe('second')
    expect(records[2].finalText).toBe('first')
  })

  it('clearAll empties records', () => {
    store.getState().addRecord(makeNewRecord())
    store.getState().addRecord(makeNewRecord())
    expect(store.getState().records).toHaveLength(2)

    store.getState().clearAll()
    expect(store.getState().records).toEqual([])
  })

  it('search finds by finalText (case-insensitive)', () => {
    store.getState().addRecord(makeNewRecord({ originalText: 'hi', finalText: 'Hello World' }))
    store.getState().addRecord(makeNewRecord({ originalText: 'bye', finalText: 'Goodbye' }))

    const results = store.getState().search('hello')
    expect(results).toHaveLength(1)
    expect(results[0].finalText).toBe('Hello World')
  })

  it('search finds by originalText', () => {
    store.getState().addRecord(makeNewRecord({ originalText: 'unique phrase', finalText: 'other' }))
    store.getState().addRecord(makeNewRecord({ originalText: 'common', finalText: 'common' }))

    const results = store.getState().search('unique')
    expect(results).toHaveLength(1)
    expect(results[0].originalText).toBe('unique phrase')
  })

  it('search returns empty for no match', () => {
    store.getState().addRecord(makeNewRecord({ finalText: 'abc' }))
    const results = store.getState().search('xyz')
    expect(results).toEqual([])
  })

  it('filterByScene returns matching records', () => {
    store.getState().addRecord(makeNewRecord({ sceneId: 'dictate' }))
    store.getState().addRecord(makeNewRecord({ sceneId: 'translate' }))
    store.getState().addRecord(makeNewRecord({ sceneId: 'dictate' }))

    const results = store.getState().filterByScene('dictate')
    expect(results).toHaveLength(2)
    results.forEach((r) => expect(r.sceneId).toBe('dictate'))
  })

  it('filterByScene returns empty for unknown scene', () => {
    store.getState().addRecord(makeNewRecord({ sceneId: 'dictate' }))
    const results = store.getState().filterByScene('nonexistent')
    expect(results).toEqual([])
  })

  it('addRecord input matches expected NewRecord shape', () => {
    const newRecord: NewRecord = {
      sceneId: 'test',
      sceneName: 'Test',
      originalText: 'orig',
      finalText: 'final',
      outputStatus: 'copied',
      pipelineSteps: ['stt'],
    }
    // Should not throw
    store.getState().addRecord(newRecord)
    const record = store.getState().records[0]
    expect(record.sceneId).toBe('test')
    expect(record.sceneName).toBe('Test')
    expect(record.originalText).toBe('orig')
    expect(record.finalText).toBe('final')
    expect(record.outputStatus).toBe('copied')
    expect(record.pipelineSteps).toEqual(['stt'])
  })

  it('reading state returns readonly data', () => {
    store.getState().addRecord(makeNewRecord())
    const records = store.getState().records
    expect(Array.isArray(records)).toBe(true)
    // Verify it's an array (readonly at type level)
    expect(records).toHaveLength(1)
  })
})
