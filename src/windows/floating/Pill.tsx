import type { PipelineState } from '../../types/pipeline'
import { Waveform } from './Waveform'

export interface PillProps {
  readonly state: PipelineState
  readonly hotkeyHint?: string
  readonly elapsed?: number
  readonly onClick?: () => void
}

function formatElapsed(ms: number): string {
  const totalSeconds = Math.floor(ms / 1000)
  const minutes = Math.floor(totalSeconds / 60)
  const seconds = totalSeconds % 60
  return `${minutes}:${seconds.toString().padStart(2, '0')}`
}

function StatusDot({ status }: { readonly status: PipelineState['status'] }) {
  const colorMap: Record<PipelineState['status'], string> = {
    idle: 'var(--color-ring-deep)',
    recording: 'var(--color-terracotta)',
    transcribing: 'var(--color-coral)',
    processing: 'var(--color-coral)',
    done: 'var(--color-success)',
    error: 'var(--color-error)',
  }

  const isPulsing = status === 'recording' || status === 'processing'

  return (
    <span
      className={isPulsing ? 'status-dot status-dot--pulse' : 'status-dot'}
      data-testid="status-dot"
      style={{
        display: 'inline-block',
        width: '8px',
        height: '8px',
        borderRadius: '50%',
        backgroundColor: colorMap[status],
        flexShrink: 0,
        ...(isPulsing
          ? {
              animation: 'pulse 1.5s ease-in-out infinite',
              boxShadow: `0 0 6px ${colorMap[status]}`,
            }
          : {}),
      }}
    />
  )
}

export function Pill({ state, hotkeyHint, elapsed, onClick }: PillProps) {
  const { status } = state

  return (
    <button
      className="pill"
      data-testid="pill"
      onClick={onClick}
      type="button"
      style={{
        display: 'flex',
        alignItems: 'center',
        gap: '8px',
        padding: '6px 14px',
        borderRadius: 'var(--radius-pill)',
        border: 'none',
        background: 'var(--color-ivory)',
        boxShadow: 'var(--shadow-ring)',
        cursor: 'pointer',
        fontFamily: 'var(--font-sans)',
        fontSize: '13px',
        color: 'var(--color-near-black)',
        lineHeight: 1,
      }}
    >
      <StatusDot status={status} />

      {status === 'idle' && (
        <>
          <span data-testid="pill-label">Verbo</span>
          {hotkeyHint && (
            <span
              data-testid="hotkey-hint"
              style={{
                color: 'var(--color-stone-gray)',
                fontSize: '11px',
              }}
            >
              {hotkeyHint}
            </span>
          )}
        </>
      )}

      {status === 'recording' && (
        <>
          <Waveform active={true} />
          {elapsed !== undefined && (
            <span data-testid="elapsed-time" style={{ fontFamily: 'var(--font-mono)', fontSize: '12px' }}>
              {formatElapsed(elapsed)}
            </span>
          )}
        </>
      )}

      {(status === 'transcribing' || status === 'processing') && (
        <>
          <span
            data-testid="processing-label"
            style={{ animation: 'shimmer 1.5s ease-in-out infinite' }}
          >
            Processing
          </span>
          <span style={{ animation: 'blink 1s step-end infinite' }}>...</span>
        </>
      )}

      {status === 'done' && <span data-testid="pill-label">Verbo</span>}

      {status === 'error' && <span data-testid="error-label">Error</span>}
    </button>
  )
}
