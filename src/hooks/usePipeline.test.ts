import { describe, it, expect, vi, beforeEach } from 'vitest'
import { renderHook, act } from '@testing-library/react'
import type { AudioRecorder } from '../audio/recorder'
import type { Scene } from '../types/pipeline'
import type { RecordingStore } from '../stores/recording'
import type { HistoryStore } from '../stores/history'
import { usePipeline } from './usePipeline'
import type { PipelineHookDeps } from './usePipeline'

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

const mockInvoke = vi.fn()

vi.mock('@tauri-apps/api/core', () => ({
  invoke: (...args: unknown[]) => mockInvoke(...args),
}))

const mockRecorderInstance: AudioRecorder = {
  start: vi.fn().mockResolvedValue(new ReadableStream<ArrayBuffer>()),
  stop: vi.fn().mockResolvedValue(new ArrayBuffer(16)),
  isRecording: vi.fn().mockReturnValue(false),
}

vi.mock('../audio/recorder', () => ({
  createAudioRecorder: () => ({ ...mockRecorderInstance }),
}))

const mockExecutePipeline = vi.fn().mockResolvedValue('final output')

vi.mock('../engine/pipeline', () => ({
  executePipeline: (...args: unknown[]) => mockExecutePipeline(...args),
}))

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const testScene: Scene = {
  id: 'test-scene',
  name: 'Test Scene',
  hotkey: { toggleRecord: null, pushToTalk: null },
  pipeline: [
    { type: 'stt', provider: 'mock-stt', lang: 'en' },
    { type: 'llm', provider: 'mock-llm', prompt: '{{input}}' },
  ],
  output: 'simulate',
}

function createMockRecordingStore(): { getState: () => RecordingStore } {
  const store: RecordingStore = {
    state: { status: 'idle' },
    lastResult: null,
    startRecording: vi.fn(),
    updateState: vi.fn(),
    reset: vi.fn(),
  }
  return { getState: () => store }
}

function createMockHistoryStore(): { getState: () => HistoryStore } {
  const store: HistoryStore = {
    records: [],
    addRecord: vi.fn(),
    clearAll: vi.fn(),
    search: vi.fn().mockReturnValue([]),
    filterByScene: vi.fn().mockReturnValue([]),
  }
  return { getState: () => store }
}

function createDeps(overrides: Partial<PipelineHookDeps> = {}): PipelineHookDeps {
  return {
    recordingStore: createMockRecordingStore(),
    historyStore: createMockHistoryStore(),
    getSTT: vi.fn(),
    getLLM: vi.fn(),
    ...overrides,
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('usePipeline', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    mockExecutePipeline.mockResolvedValue('final output')
    mockInvoke.mockResolvedValue(undefined)
  })

  it('startRecording calls recorder.start and updates store', async () => {
    const deps = createDeps()
    const { result } = renderHook(() => usePipeline(deps))

    await act(async () => {
      await result.current.startRecording()
    })

    expect(deps.recordingStore.getState().startRecording).toHaveBeenCalled()
  })

  it('stopAndProcess executes pipeline and attempts output', async () => {
    const recordingStore = createMockRecordingStore()
    // After pipeline executes, simulate the store having 'done' state
    const originalGetState = recordingStore.getState
    let callCount = 0
    const getStateSpy = vi.fn(() => {
      const state = originalGetState()
      callCount++
      // After updateState is called (during pipeline), return done state
      if (callCount > 1) {
        return {
          ...state,
          state: {
            status: 'done' as const,
            sourceText: 'source text',
            finalText: 'final output',
          },
        }
      }
      return state
    })
    recordingStore.getState = getStateSpy

    const deps = createDeps({ recordingStore })
    const { result } = renderHook(() => usePipeline(deps))

    // First start recording
    await act(async () => {
      await result.current.startRecording()
    })

    // Then stop and process
    await act(async () => {
      await result.current.stopAndProcess(testScene)
    })

    expect(mockExecutePipeline).toHaveBeenCalled()
    expect(mockInvoke).toHaveBeenCalledWith('simulate_input', {
      text: 'final output',
    })
  })

  it('on simulate failure, falls back to clipboard', async () => {
    mockInvoke
      .mockRejectedValueOnce(new Error('simulate failed'))
      .mockResolvedValueOnce(undefined)

    const deps = createDeps()
    const { result } = renderHook(() => usePipeline(deps))

    await act(async () => {
      await result.current.startRecording()
    })

    await act(async () => {
      await result.current.stopAndProcess(testScene)
    })

    expect(mockInvoke).toHaveBeenCalledWith('simulate_input', {
      text: 'final output',
    })
    expect(mockInvoke).toHaveBeenCalledWith('copy_to_clipboard', {
      text: 'final output',
    })

    const addRecord = deps.historyStore.getState().addRecord as ReturnType<typeof vi.fn>
    expect(addRecord).toHaveBeenCalledWith(
      expect.objectContaining({ outputStatus: 'copied' }),
    )
  })

  it('saves to history after pipeline completion', async () => {
    const deps = createDeps()
    const { result } = renderHook(() => usePipeline(deps))

    await act(async () => {
      await result.current.startRecording()
    })

    await act(async () => {
      await result.current.stopAndProcess(testScene)
    })

    const addRecord = deps.historyStore.getState().addRecord as ReturnType<typeof vi.fn>
    expect(addRecord).toHaveBeenCalledTimes(1)
    expect(addRecord).toHaveBeenCalledWith(
      expect.objectContaining({
        sceneId: 'test-scene',
        sceneName: 'Test Scene',
        finalText: 'final output',
        pipelineSteps: ['stt', 'llm'],
      }),
    )
  })

  it('saves failed status on pipeline error', async () => {
    mockExecutePipeline.mockRejectedValue(new Error('Pipeline exploded'))

    const deps = createDeps()
    const { result } = renderHook(() => usePipeline(deps))

    await act(async () => {
      await result.current.startRecording()
    })

    await act(async () => {
      await result.current.stopAndProcess(testScene)
    })

    const addRecord = deps.historyStore.getState().addRecord as ReturnType<typeof vi.fn>
    expect(addRecord).toHaveBeenCalledWith(
      expect.objectContaining({ outputStatus: 'failed' }),
    )

    const updateState = deps.recordingStore.getState().updateState as ReturnType<typeof vi.fn>
    expect(updateState).toHaveBeenCalledWith(
      expect.objectContaining({
        status: 'error',
        message: 'Pipeline exploded',
      }),
    )
  })

  it('uses clipboard mode when scene output is clipboard', async () => {
    const clipboardScene: Scene = { ...testScene, output: 'clipboard' }
    const deps = createDeps()
    const { result } = renderHook(() => usePipeline(deps))

    await act(async () => {
      await result.current.startRecording()
    })

    await act(async () => {
      await result.current.stopAndProcess(clipboardScene)
    })

    expect(mockInvoke).toHaveBeenCalledWith('copy_to_clipboard', {
      text: 'final output',
    })
    expect(mockInvoke).not.toHaveBeenCalledWith('simulate_input', expect.anything())
  })
})
