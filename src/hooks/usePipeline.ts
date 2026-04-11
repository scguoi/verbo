import { useCallback, useRef } from 'react'
import { invoke } from '@tauri-apps/api/core'
import type { AudioRecorder } from '../audio/recorder'
import { createAudioRecorder } from '../audio/recorder'
import { executePipeline } from '../engine/pipeline'
import type { PipelineContext } from '../engine/pipeline'
import type { Scene } from '../types/pipeline'
import type { STTAdapter } from '../adapters/stt/types'
import type { LLMAdapter } from '../adapters/llm/types'
import type { OutputStatus } from '../types/history'
import type { RecordingStore } from '../stores/recording'
import type { NewRecord, HistoryStore } from '../stores/history'

export interface PipelineHookDeps {
  readonly recordingStore: { getState: () => RecordingStore }
  readonly historyStore: { getState: () => HistoryStore }
  readonly getSTT: (name: string) => STTAdapter | undefined
  readonly getLLM: (name: string) => LLMAdapter | undefined
}

export interface PipelineActions {
  readonly startRecording: () => Promise<void>
  readonly stopAndProcess: (scene: Scene) => Promise<void>
}

export function usePipeline(deps: PipelineHookDeps): PipelineActions {
  const recorderRef = useRef<AudioRecorder | null>(null)
  const audioStreamRef = useRef<ReadableStream<ArrayBuffer> | null>(null)

  const startRecording = useCallback(async () => {
    const recorder = createAudioRecorder()
    recorderRef.current = recorder

    const stream = await recorder.start()
    audioStreamRef.current = stream

    deps.recordingStore.getState().startRecording()
  }, [deps.recordingStore])

  const stopAndProcess = useCallback(
    async (scene: Scene) => {
      const recorder = recorderRef.current
      if (!recorder) {
        throw new Error('No active recorder')
      }

      const audio = await recorder.stop()
      const audioStream = audioStreamRef.current ?? undefined

      recorderRef.current = null
      audioStreamRef.current = null

      const { recordingStore, historyStore, getSTT, getLLM } = deps

      const ctx: PipelineContext = {
        audio,
        audioStream,
        getSTT,
        getLLM,
        onStateChange: (state) => {
          recordingStore.getState().updateState(state)
        },
      }

      let sourceText = ''
      let finalText = ''
      let outputStatus: OutputStatus = 'failed'

      try {
        finalText = await executePipeline(scene.pipeline, ctx)

        const doneState = recordingStore.getState().state
        sourceText =
          doneState.status === 'done' ? doneState.sourceText : finalText

        outputStatus = await attemptOutput(scene.output, finalText)
      } catch (err) {
        outputStatus = 'failed'
        const errorMessage =
          err instanceof Error ? err.message : String(err)
        recordingStore.getState().updateState({
          status: 'error',
          message: errorMessage,
        })
      }

      const newRecord: NewRecord = {
        sceneId: scene.id,
        sceneName: scene.name,
        originalText: sourceText,
        finalText,
        outputStatus,
        pipelineSteps: scene.pipeline.map((s) => s.type),
      }

      historyStore.getState().addRecord(newRecord)
    },
    [deps],
  )

  return { startRecording, stopAndProcess }
}

async function attemptOutput(
  mode: 'simulate' | 'clipboard',
  text: string,
): Promise<OutputStatus> {
  if (mode === 'simulate') {
    try {
      await invoke('simulate_input', { text })
      return 'inserted'
    } catch {
      // fallback to clipboard
      return copyToClipboard(text)
    }
  }

  return copyToClipboard(text)
}

async function copyToClipboard(text: string): Promise<OutputStatus> {
  try {
    await invoke('copy_to_clipboard', { text })
    return 'copied'
  } catch {
    return 'failed'
  }
}
