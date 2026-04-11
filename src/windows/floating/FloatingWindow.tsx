import { useCallback, useEffect, useRef, useState } from 'react'
import { useStore } from 'zustand'
import { recordingStore } from '../../stores/recording'
import { appStore } from '../../stores/app'
import { useConfigStore } from '../../config/store'
import { Pill } from './Pill'
import { Bubble } from './Bubble'


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

  // Track elapsed time during recording
  useEffect(() => {
    if (pipelineState.status === 'recording') {
      const { startedAt } = pipelineState
      setElapsed(Date.now() - startedAt)

      elapsedTimerRef.current = setInterval(() => {
        setElapsed(Date.now() - startedAt)
      }, 200)

      return () => {
        if (elapsedTimerRef.current) {
          clearInterval(elapsedTimerRef.current)
        }
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
      collapseTimerRef.current = setTimeout(() => {
        reset()
      }, autoCollapseDelay)

      return () => {
        if (collapseTimerRef.current) {
          clearTimeout(collapseTimerRef.current)
        }
      }
    }
  }, [pipelineState.status, autoCollapseDelay, reset])

  const handlePillClick = useCallback(() => {
    if (pipelineState.status === 'idle' && lastResult) {
      setShowLastResult((prev) => !prev)
    }
  }, [pipelineState.status, lastResult])

  const handleCopy = useCallback(() => {
    const text =
      pipelineState.status === 'done'
        ? pipelineState.finalText
        : lastResult?.finalText ?? ''
    if (text) {
      navigator.clipboard.writeText(text).catch(() => {
        // clipboard write failed silently in floating window
      })
    }
  }, [pipelineState, lastResult])

  const bubbleState =
    pipelineState.status === 'idle' && showLastResult && lastResult
      ? ({ status: 'done', sourceText: lastResult.sourceText, finalText: lastResult.finalText } as const)
      : pipelineState

  const hotkeyHint = scene?.hotkey.toggleRecord ?? undefined

  return (
    <div
      className="floating-window"
      data-testid="floating-window"
      style={{
        display: 'flex',
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
