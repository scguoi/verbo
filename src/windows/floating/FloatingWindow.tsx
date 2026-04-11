import { useCallback, useEffect, useRef, useState } from 'react'
import { useStore } from 'zustand'
import { recordingStore } from '../../stores/recording'
import { appStore } from '../../stores/app'
import { useConfigStore } from '../../config/store'
import { createHistoryStore } from '../../stores/history'
import { createSTTRegistry } from '../../adapters/stt/registry'
import { createIFlytekAdapter } from '../../adapters/stt/iflytek'
import { createLLMRegistry } from '../../adapters/llm/registry'
import { createOpenAIAdapter } from '../../adapters/llm/openai'
import { usePipeline } from '../../hooks/usePipeline'
import { Pill } from './Pill'
import { Bubble } from './Bubble'

const isTauri = typeof window !== 'undefined' && '__TAURI_INTERNALS__' in window

// ── Singleton registries & history store ──
const historyStore = createHistoryStore()
const sttRegistry = createSTTRegistry()
const llmRegistry = createLLMRegistry()

// Initialize adapters from config
function initAdapters() {
  const config = useConfigStore.getState().config

  // Register STT adapters
  const iflytekConfig = config.providers.stt['iflytek']
  if (iflytekConfig) {
    sttRegistry.register(
      createIFlytekAdapter({
        appId: (iflytekConfig as Record<string, string>).appId ?? '',
        apiKey: (iflytekConfig as Record<string, string>).apiKey ?? '',
        apiSecret: (iflytekConfig as Record<string, string>).apiSecret ?? '',
      }),
    )
  }

  // Register LLM adapters
  const openaiConfig = config.providers.llm['openai']
  if (openaiConfig) {
    llmRegistry.register(
      createOpenAIAdapter({
        apiKey: openaiConfig.apiKey,
        model: openaiConfig.model,
        baseUrl: openaiConfig.baseUrl,
      }),
    )
  }
}

// Init on load
initAdapters()

// ── Window helpers ──
async function startWindowDrag() {
  if (!isTauri) return
  try {
    const { getCurrentWindow } = await import('@tauri-apps/api/window')
    await getCurrentWindow().startDragging()
  } catch {
    // ignore
  }
}

async function resizeWindowToContent() {
  if (!isTauri) return
  try {
    const { getCurrentWindow } = await import('@tauri-apps/api/window')
    const { LogicalSize } = await import('@tauri-apps/api/dpi')
    const root = document.getElementById('root')
    if (!root) return
    const rect = root.getBoundingClientRect()
    const width = Math.max(Math.ceil(rect.width) + 16, 120)
    const height = Math.max(Math.ceil(rect.height) + 16, 40)
    await getCurrentWindow().setSize(new LogicalSize(width, height))
  } catch {
    // ignore
  }
}

// ── Component ──
export function FloatingWindow() {
  const pipelineState = useStore(recordingStore, (s) => s.state)
  const lastResult = useStore(recordingStore, (s) => s.lastResult)
  const reset = useStore(recordingStore, (s) => s.reset)
  const currentSceneId = useStore(appStore, (s) => s.currentSceneId)
  const autoCollapseDelay = useStore(useConfigStore, (s) => s.config.general.autoCollapseDelay)
  const getScene = useStore(useConfigStore, (s) => s.getScene)

  const [elapsed, setElapsed] = useState(0)
  const [showLastResult, setShowLastResult] = useState(false)
  const collapseTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null)
  const elapsedTimerRef = useRef<ReturnType<typeof setInterval> | null>(null)

  const scene = getScene(currentSceneId)
  const sceneName = scene?.name ?? 'Unknown'

  // Pipeline hook
  const { startRecording, stopAndProcess } = usePipeline({
    recordingStore,
    historyStore,
    getSTT: (name) => sttRegistry.get(name),
    getLLM: (name) => llmRegistry.get(name),
  })

  // Track elapsed time during recording
  useEffect(() => {
    if (pipelineState.status === 'recording') {
      const { startedAt } = pipelineState
      setElapsed(Date.now() - startedAt)
      elapsedTimerRef.current = setInterval(() => {
        setElapsed(Date.now() - startedAt)
      }, 200)
      return () => {
        if (elapsedTimerRef.current) clearInterval(elapsedTimerRef.current)
      }
    } else {
      setElapsed(0)
      if (elapsedTimerRef.current) {
        clearInterval(elapsedTimerRef.current)
        elapsedTimerRef.current = null
      }
    }
  }, [pipelineState.status, pipelineState.status === 'recording' ? pipelineState.startedAt : 0])

  // Auto-collapse after done
  useEffect(() => {
    if (pipelineState.status === 'done') {
      setShowLastResult(false)
      collapseTimerRef.current = setTimeout(() => reset(), autoCollapseDelay)
      return () => {
        if (collapseTimerRef.current) clearTimeout(collapseTimerRef.current)
      }
    }
  }, [pipelineState.status, autoCollapseDelay, reset])

  // Pill click: idle → start recording, recording → stop and process
  const handlePillClick = useCallback(async () => {
    if (pipelineState.status === 'idle') {
      if (lastResult && !scene) {
        setShowLastResult((prev) => !prev)
        return
      }
      try {
        await startRecording()
      } catch (err) {
        recordingStore.getState().updateState({
          status: 'error',
          message: err instanceof Error ? err.message : String(err),
        })
      }
    } else if (pipelineState.status === 'recording') {
      if (!scene) return
      try {
        await stopAndProcess(scene)
      } catch {
        // Error already handled in usePipeline
      }
    }
  }, [pipelineState.status, lastResult, scene, startRecording, stopAndProcess])

  const handleCopy = useCallback(() => {
    const text =
      pipelineState.status === 'done'
        ? pipelineState.finalText
        : lastResult?.finalText ?? ''
    if (text) {
      navigator.clipboard.writeText(text).catch(() => {})
    }
  }, [pipelineState, lastResult])

  const bubbleState =
    pipelineState.status === 'idle' && showLastResult && lastResult
      ? ({ status: 'done', sourceText: lastResult.sourceText, finalText: lastResult.finalText } as const)
      : pipelineState

  const hotkeyHint = scene?.hotkey.toggleRecord ?? undefined

  const handleDragStart = useCallback((e: React.MouseEvent) => {
    if (e.button !== 0) return
    if ((e.target as HTMLElement).closest('button[data-no-drag]')) return
    if ((e.target as HTMLElement).closest('button.pill')) return // don't drag on pill click
    startWindowDrag()
  }, [])

  // Auto-resize window to match content size
  useEffect(() => {
    resizeWindowToContent()
  }, [pipelineState.status, showLastResult])

  return (
    <div
      className="floating-window"
      data-testid="floating-window"
      onMouseDown={handleDragStart}
      style={{
        display: 'inline-flex',
        flexDirection: 'column',
        alignItems: 'center',
        gap: '8px',
      }}
    >
      <Pill
        state={pipelineState}
        hotkeyHint={hotkeyHint}
        elapsed={pipelineState.status === 'recording' ? elapsed : undefined}
        onClick={handlePillClick}
      />
      <Bubble
        state={bubbleState}
        sceneName={sceneName}
        onCopy={handleCopy}
      />
    </div>
  )
}
