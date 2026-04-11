import type { CSSProperties } from 'react'

export interface WaveformProps {
  readonly active: boolean
  readonly barCount?: number
  readonly color?: string
}

const DEFAULT_BAR_COUNT = 5

export function Waveform({
  active,
  barCount = DEFAULT_BAR_COUNT,
  color = 'var(--color-terracotta)',
}: WaveformProps) {
  const bars = Array.from({ length: barCount }, (_, i) => i)

  return (
    <div
      className="waveform"
      style={{
        display: 'flex',
        alignItems: 'center',
        gap: '2px',
        height: '16px',
      }}
    >
      {bars.map((i) => {
        const style: CSSProperties = {
          width: '3px',
          height: active ? '100%' : '4px',
          backgroundColor: color,
          borderRadius: '1px',
          transition: 'height 0.1s ease',
          ...(active
            ? {
                animation: `wave 0.8s ease-in-out infinite`,
                animationDelay: `${i * 0.1}s`,
              }
            : {}),
        }

        return (
          <div
            key={i}
            className={active ? 'waveform-bar waveform-bar--active' : 'waveform-bar'}
            style={style}
            data-testid={`waveform-bar-${i}`}
          />
        )
      })}
    </div>
  )
}
