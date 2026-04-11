import type { PipelineStep, PipelineState } from '../types/pipeline'
import type { STTAdapter } from '../adapters/stt/types'
import type { LLMAdapter } from '../adapters/llm/types'

export interface PipelineContext {
  readonly audio: ArrayBuffer
  readonly audioStream?: ReadableStream<ArrayBuffer>
  readonly getSTT: (name: string) => STTAdapter | undefined
  readonly getLLM: (name: string) => LLMAdapter | undefined
  readonly onStateChange: (state: PipelineState) => void
}

function resolveTemplate(template: string, input: string): string {
  return template.replaceAll('{{input}}', input)
}

function toErrorMessage(err: unknown): string {
  return err instanceof Error ? err.message : String(err)
}

async function executeSTTStep(
  step: Extract<PipelineStep, { type: 'stt' }>,
  ctx: PipelineContext,
): Promise<string> {
  const adapter = ctx.getSTT(step.provider)
  if (!adapter) {
    throw new Error(`STT adapter not found: ${step.provider}`)
  }

  ctx.onStateChange({ status: 'transcribing', partialText: '' })

  const useStreaming =
    adapter.capabilities.streaming &&
    ctx.audioStream !== undefined &&
    adapter.transcribeStream !== undefined

  if (useStreaming) {
    return adapter.transcribeStream!(ctx.audioStream!, { lang: step.lang }, (partial) => {
      ctx.onStateChange({ status: 'transcribing', partialText: partial })
    })
  }

  return adapter.transcribe(ctx.audio, { lang: step.lang })
}

async function executeLLMStep(
  step: Extract<PipelineStep, { type: 'llm' }>,
  ctx: PipelineContext,
  input: string,
  sourceText: string,
): Promise<string> {
  const adapter = ctx.getLLM(step.provider)
  if (!adapter) {
    throw new Error(`LLM adapter not found: ${step.provider}`)
  }

  const resolvedPrompt = resolveTemplate(step.prompt, input)

  ctx.onStateChange({ status: 'processing', sourceText, partialResult: '' })

  if (adapter.completeStream) {
    return adapter.completeStream({ prompt: resolvedPrompt }, (chunk) => {
      ctx.onStateChange({ status: 'processing', sourceText, partialResult: chunk })
    })
  }

  return adapter.complete({ prompt: resolvedPrompt })
}

export async function executePipeline(
  steps: readonly PipelineStep[],
  ctx: PipelineContext,
): Promise<string> {
  if (steps.length === 0) {
    return ''
  }

  let currentOutput = ''
  let sttOutput: string | undefined

  try {
    for (const step of steps) {
      switch (step.type) {
        case 'stt': {
          currentOutput = await executeSTTStep(step, ctx)
          sttOutput = currentOutput
          break
        }
        case 'llm': {
          currentOutput = await executeLLMStep(
            step,
            ctx,
            currentOutput,
            sttOutput ?? '',
          )
          break
        }
      }
    }

    ctx.onStateChange({
      status: 'done',
      sourceText: sttOutput ?? currentOutput,
      finalText: currentOutput,
    })

    return currentOutput
  } catch (err) {
    ctx.onStateChange({ status: 'error', message: toErrorMessage(err) })
    throw err
  }
}
