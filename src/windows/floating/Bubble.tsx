import type { PipelineState } from '../../types/pipeline'
import { Waveform } from './Waveform'

export interface BubbleProps {
  readonly state: PipelineState
  readonly sceneName: string
  readonly onCopy?: () => void
  readonly onRetry?: () => void
}

export function Bubble({ state, sceneName, onCopy, onRetry }: BubbleProps) {
  const { status } = state

  if (status === 'idle' || status === 'recording') {
    return null
  }

  return (
    <div
      className="bubble"
      data-testid="bubble"
      style={{
        padding: '12px 16px',
        borderRadius: 'var(--radius-lg)',
        background: 'var(--color-ivory)',
        boxShadow: 'var(--shadow-ring)',
        animation: 'bubbleExpand 0.2s ease-out',
        maxWidth: '360px',
        fontFamily: 'var(--font-sans)',
        fontSize: '14px',
        color: 'var(--color-near-black)',
      }}
    >
      <div
        style={{
          fontSize: '11px',
          color: 'var(--color-stone-gray)',
          marginBottom: '8px',
        }}
      >
        {sceneName}
      </div>

      {status === 'transcribing' && (
        <div data-testid="bubble-transcribing">
          <Waveform active={true} color="var(--color-coral)" />
          <p
            data-testid="partial-text"
            style={{
              marginTop: '8px',
              color: 'var(--color-olive-gray)',
              fontStyle: 'italic',
            }}
          >
            {state.partialText || '...'}
          </p>
        </div>
      )}

      {status === 'processing' && (
        <div data-testid="bubble-processing">
          <p
            style={{
              textDecoration: 'line-through',
              color: 'var(--color-stone-gray)',
              marginBottom: '4px',
            }}
          >
            {state.sourceText}
          </p>
          <p>
            {state.partialResult}
            <span
              style={{
                animation: 'blink 1s step-end infinite',
                borderRight: '2px solid var(--color-near-black)',
                marginLeft: '1px',
              }}
            >
              &nbsp;
            </span>
          </p>
        </div>
      )}

      {status === 'done' && (
        <div data-testid="bubble-done">
          <p>{state.finalText}</p>
          <div
            style={{
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
              marginTop: '8px',
              paddingTop: '8px',
              borderTop: '1px solid var(--color-border-cream)',
            }}
          >
            <span
              data-testid="done-status"
              style={{ fontSize: '11px', color: 'var(--color-success)' }}
            >
              Done
            </span>
            <div style={{ display: 'flex', gap: '8px' }}>
              {onCopy && (
                <button
                  data-testid="copy-button"
                  data-no-drag
                  onClick={onCopy}
                  type="button"
                  style={{
                    fontSize: '12px',
                    padding: '2px 8px',
                    border: '1px solid var(--color-border-warm)',
                    borderRadius: 'var(--radius-sm)',
                    background: 'transparent',
                    cursor: 'pointer',
                    color: 'var(--color-charcoal-warm)',
                  }}
                >
                  Copy
                </button>
              )}
              {onRetry && (
                <button
                  data-testid="retry-button"
                  data-no-drag
                  onClick={onRetry}
                  type="button"
                  style={{
                    fontSize: '12px',
                    padding: '2px 8px',
                    border: '1px solid var(--color-border-warm)',
                    borderRadius: 'var(--radius-sm)',
                    background: 'transparent',
                    cursor: 'pointer',
                    color: 'var(--color-charcoal-warm)',
                  }}
                >
                  Retry
                </button>
              )}
            </div>
          </div>
        </div>
      )}

      {status === 'error' && (
        <div data-testid="bubble-error">
          <p style={{ color: 'var(--color-error)' }}>{state.message}</p>
          <div style={{ display: 'flex', gap: '8px', marginTop: '8px' }}>
            {onRetry && (
              <button
                data-testid="retry-button"
                  data-no-drag
                onClick={onRetry}
                type="button"
                style={{
                  fontSize: '12px',
                  padding: '2px 8px',
                  border: '1px solid var(--color-border-warm)',
                  borderRadius: 'var(--radius-sm)',
                  background: 'transparent',
                  cursor: 'pointer',
                  color: 'var(--color-charcoal-warm)',
                }}
              >
                Retry
              </button>
            )}
          </div>
        </div>
      )}
    </div>
  )
}
