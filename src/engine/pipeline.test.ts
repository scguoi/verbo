import { describe, it, expect, vi } from 'vitest'
import type { STTAdapter } from '../adapters/stt/types'
import type { LLMAdapter } from '../adapters/llm/types'
import type { PipelineStep, PipelineState } from '../types/pipeline'
import { executePipeline } from './pipeline'
import type { PipelineContext } from './pipeline'

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function createMockSTT(overrides: Partial<STTAdapter> = {}): STTAdapter {
  return {
    name: 'mock-stt',
    capabilities: { streaming: false },
    transcribe: vi.fn().mockResolvedValue('hello world'),
    ...overrides,
  }
}

function createMockLLM(overrides: Partial<LLMAdapter> = {}): LLMAdapter {
  return {
    name: 'mock-llm',
    complete: vi.fn().mockResolvedValue('translated text'),
    ...overrides,
  }
}

function createContext(overrides: Partial<PipelineContext> = {}): PipelineContext {
  return {
    audio: new ArrayBuffer(16),
    getSTT: vi.fn().mockReturnValue(createMockSTT()),
    getLLM: vi.fn().mockReturnValue(createMockLLM()),
    onStateChange: vi.fn(),
    ...overrides,
  }
}

// ---------------------------------------------------------------------------
// Unit tests — mock adapters
// ---------------------------------------------------------------------------

describe('executePipeline', () => {
  // ---- basic flows ----

  it('returns empty string for empty pipeline', async () => {
    const ctx = createContext()
    const result = await executePipeline([], ctx)
    expect(result).toBe('')
  })

  it('single STT step returns transcribed text', async () => {
    const stt = createMockSTT()
    const ctx = createContext({ getSTT: vi.fn().mockReturnValue(stt) })
    const steps: readonly PipelineStep[] = [{ type: 'stt', provider: 'mock-stt', lang: 'en' }]

    const result = await executePipeline(steps, ctx)

    expect(result).toBe('hello world')
    expect(stt.transcribe).toHaveBeenCalledWith(ctx.audio, { lang: 'en' })
  })

  it('STT + LLM pipeline: LLM receives {{input}} resolved with STT output', async () => {
    const stt = createMockSTT()
    const llm = createMockLLM()
    const ctx = createContext({
      getSTT: vi.fn().mockReturnValue(stt),
      getLLM: vi.fn().mockReturnValue(llm),
    })
    const steps: readonly PipelineStep[] = [
      { type: 'stt', provider: 'mock-stt', lang: 'en' },
      { type: 'llm', provider: 'mock-llm', prompt: 'Translate: {{input}}' },
    ]

    const result = await executePipeline(steps, ctx)

    expect(result).toBe('translated text')
    expect(llm.complete).toHaveBeenCalledWith({
      prompt: 'Translate: hello world',
    })
  })

  it('handles multiple {{input}} replacements in prompt', async () => {
    const stt = createMockSTT()
    const llm = createMockLLM()
    const ctx = createContext({
      getSTT: vi.fn().mockReturnValue(stt),
      getLLM: vi.fn().mockReturnValue(llm),
    })
    const steps: readonly PipelineStep[] = [
      { type: 'stt', provider: 'mock-stt', lang: 'en' },
      { type: 'llm', provider: 'mock-llm', prompt: '{{input}} -> translate -> {{input}}' },
    ]

    await executePipeline(steps, ctx)

    expect(llm.complete).toHaveBeenCalledWith({
      prompt: 'hello world -> translate -> hello world',
    })
  })

  // ---- state transitions ----

  it('calls onStateChange with transcribing during STT', async () => {
    const ctx = createContext()
    const steps: readonly PipelineStep[] = [{ type: 'stt', provider: 'mock-stt', lang: 'en' }]

    await executePipeline(steps, ctx)

    expect(ctx.onStateChange).toHaveBeenCalledWith(
      expect.objectContaining({ status: 'transcribing' }),
    )
  })

  it('calls onStateChange with processing during LLM', async () => {
    const ctx = createContext()
    const steps: readonly PipelineStep[] = [
      { type: 'stt', provider: 'mock-stt', lang: 'en' },
      { type: 'llm', provider: 'mock-llm', prompt: '{{input}}' },
    ]

    await executePipeline(steps, ctx)

    expect(ctx.onStateChange).toHaveBeenCalledWith(
      expect.objectContaining({ status: 'processing' }),
    )
  })

  it('calls onStateChange with done at completion — STT only', async () => {
    const ctx = createContext()
    const steps: readonly PipelineStep[] = [{ type: 'stt', provider: 'mock-stt', lang: 'en' }]

    await executePipeline(steps, ctx)

    expect(ctx.onStateChange).toHaveBeenCalledWith({
      status: 'done',
      sourceText: 'hello world',
      finalText: 'hello world',
    })
  })

  it('calls onStateChange with done at completion — STT + LLM', async () => {
    const ctx = createContext()
    const steps: readonly PipelineStep[] = [
      { type: 'stt', provider: 'mock-stt', lang: 'en' },
      { type: 'llm', provider: 'mock-llm', prompt: '{{input}}' },
    ]

    await executePipeline(steps, ctx)

    expect(ctx.onStateChange).toHaveBeenCalledWith({
      status: 'done',
      sourceText: 'hello world',
      finalText: 'translated text',
    })
  })

  // ---- error handling ----

  it('calls onStateChange with error on adapter failure, then re-throws', async () => {
    const stt = createMockSTT({
      transcribe: vi.fn().mockRejectedValue(new Error('STT failed')),
    })
    const ctx = createContext({ getSTT: vi.fn().mockReturnValue(stt) })
    const steps: readonly PipelineStep[] = [{ type: 'stt', provider: 'mock-stt', lang: 'en' }]

    await expect(executePipeline(steps, ctx)).rejects.toThrow('STT failed')
    expect(ctx.onStateChange).toHaveBeenCalledWith({
      status: 'error',
      message: 'STT failed',
    })
  })

  it('throws if STT adapter not found', async () => {
    const ctx = createContext({ getSTT: vi.fn().mockReturnValue(undefined) })
    const steps: readonly PipelineStep[] = [{ type: 'stt', provider: 'missing', lang: 'en' }]

    await expect(executePipeline(steps, ctx)).rejects.toThrow()
  })

  it('throws if LLM adapter not found', async () => {
    const ctx = createContext({ getLLM: vi.fn().mockReturnValue(undefined) })
    const steps: readonly PipelineStep[] = [
      { type: 'stt', provider: 'mock-stt', lang: 'en' },
      { type: 'llm', provider: 'missing', prompt: '{{input}}' },
    ]

    await expect(executePipeline(steps, ctx)).rejects.toThrow()
  })

  // ---- streaming modes ----

  it('STT streaming mode: uses transcribeStream when capability is true and audioStream provided', async () => {
    const transcribeStream = vi.fn().mockResolvedValue('streamed text')
    const stt = createMockSTT({
      capabilities: { streaming: true },
      transcribeStream,
    })
    const audioStream = new ReadableStream<ArrayBuffer>()
    const ctx = createContext({
      audioStream,
      getSTT: vi.fn().mockReturnValue(stt),
    })
    const steps: readonly PipelineStep[] = [{ type: 'stt', provider: 'mock-stt', lang: 'en' }]

    const result = await executePipeline(steps, ctx)

    expect(result).toBe('streamed text')
    expect(transcribeStream).toHaveBeenCalledWith(
      audioStream,
      { lang: 'en' },
      expect.any(Function),
    )
    expect(stt.transcribe).not.toHaveBeenCalled()
  })

  it('STT batch mode: uses transcribe when streaming not available', async () => {
    const stt = createMockSTT({ capabilities: { streaming: false } })
    const ctx = createContext({
      audioStream: new ReadableStream<ArrayBuffer>(),
      getSTT: vi.fn().mockReturnValue(stt),
    })
    const steps: readonly PipelineStep[] = [{ type: 'stt', provider: 'mock-stt', lang: 'en' }]

    const result = await executePipeline(steps, ctx)

    expect(result).toBe('hello world')
    expect(stt.transcribe).toHaveBeenCalled()
  })

  it('STT streaming partial text updates onStateChange', async () => {
    const transcribeStream = vi.fn().mockImplementation(
      async (
        _stream: ReadableStream<ArrayBuffer>,
        _opts: { lang: string },
        onPartial: (text: string) => void,
      ) => {
        onPartial('hel')
        onPartial('hello')
        return 'hello world'
      },
    )
    const stt = createMockSTT({
      capabilities: { streaming: true },
      transcribeStream,
    })
    const ctx = createContext({
      audioStream: new ReadableStream<ArrayBuffer>(),
      getSTT: vi.fn().mockReturnValue(stt),
    })
    const steps: readonly PipelineStep[] = [{ type: 'stt', provider: 'mock-stt', lang: 'en' }]

    await executePipeline(steps, ctx)

    expect(ctx.onStateChange).toHaveBeenCalledWith({
      status: 'transcribing',
      partialText: 'hel',
    })
    expect(ctx.onStateChange).toHaveBeenCalledWith({
      status: 'transcribing',
      partialText: 'hello',
    })
  })

  it('LLM streaming mode: uses completeStream when available', async () => {
    const completeStream = vi.fn().mockResolvedValue('streamed result')
    const llm = createMockLLM({ completeStream })
    const ctx = createContext({
      getLLM: vi.fn().mockReturnValue(llm),
    })
    const steps: readonly PipelineStep[] = [
      { type: 'stt', provider: 'mock-stt', lang: 'en' },
      { type: 'llm', provider: 'mock-llm', prompt: '{{input}}' },
    ]

    const result = await executePipeline(steps, ctx)

    expect(result).toBe('streamed result')
    expect(completeStream).toHaveBeenCalledWith(
      { prompt: 'hello world' },
      expect.any(Function),
    )
    expect(llm.complete).not.toHaveBeenCalled()
  })

  it('LLM streaming partial updates onStateChange with processing', async () => {
    const completeStream = vi.fn().mockImplementation(
      async (_opts: { prompt: string }, onChunk: (text: string) => void) => {
        onChunk('trans')
        onChunk('translated')
        return 'translated text'
      },
    )
    const llm = createMockLLM({ completeStream })
    const ctx = createContext({ getLLM: vi.fn().mockReturnValue(llm) })
    const steps: readonly PipelineStep[] = [
      { type: 'stt', provider: 'mock-stt', lang: 'en' },
      { type: 'llm', provider: 'mock-llm', prompt: '{{input}}' },
    ]

    await executePipeline(steps, ctx)

    expect(ctx.onStateChange).toHaveBeenCalledWith({
      status: 'processing',
      sourceText: 'hello world',
      partialResult: 'trans',
    })
    expect(ctx.onStateChange).toHaveBeenCalledWith({
      status: 'processing',
      sourceText: 'hello world',
      partialResult: 'translated',
    })
  })
})

// ---------------------------------------------------------------------------
// Interface-level tests
// ---------------------------------------------------------------------------

describe('Pipeline interface contracts', () => {
  it('PipelineContext interface is satisfied by mock objects', () => {
    const ctx: PipelineContext = createContext()
    expect(ctx.audio).toBeInstanceOf(ArrayBuffer)
    expect(typeof ctx.getSTT).toBe('function')
    expect(typeof ctx.getLLM).toBe('function')
    expect(typeof ctx.onStateChange).toBe('function')
  })

  it('executePipeline accepts readonly PipelineStep[]', async () => {
    const steps: readonly PipelineStep[] = Object.freeze([
      { type: 'stt', provider: 'mock-stt', lang: 'en' },
    ]) as readonly PipelineStep[]
    const ctx = createContext()

    const result = await executePipeline(steps, ctx)
    expect(typeof result).toBe('string')
  })

  it('return type is Promise<string>', async () => {
    const ctx = createContext()
    const result = executePipeline([], ctx)
    expect(result).toBeInstanceOf(Promise)
    expect(typeof (await result)).toBe('string')
  })

  it('onStateChange receives valid PipelineState objects', async () => {
    const states: PipelineState[] = []
    const ctx = createContext({
      onStateChange: (state: PipelineState) => { states.push(state) },
    })
    const steps: readonly PipelineStep[] = [
      { type: 'stt', provider: 'mock-stt', lang: 'en' },
      { type: 'llm', provider: 'mock-llm', prompt: '{{input}}' },
    ]

    await executePipeline(steps, ctx)

    // Verify discriminated union — each state has a valid status
    const validStatuses = ['idle', 'recording', 'transcribing', 'processing', 'done', 'error']
    for (const state of states) {
      expect(validStatuses).toContain(state.status)
    }

    // Must include transcribing, processing, and done
    const statuses = states.map((s) => s.status)
    expect(statuses).toContain('transcribing')
    expect(statuses).toContain('processing')
    expect(statuses).toContain('done')

    // done state must have sourceText and finalText
    const doneState = states.find((s) => s.status === 'done')
    expect(doneState).toBeDefined()
    if (doneState?.status === 'done') {
      expect(typeof doneState.sourceText).toBe('string')
      expect(typeof doneState.finalText).toBe('string')
    }
  })
})
