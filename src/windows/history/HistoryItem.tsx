import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import type { HistoryRecord, OutputStatus } from '../../types/history'

interface HistoryItemProps {
  readonly record: HistoryRecord
  readonly onCopy: (text: string) => void
}

const STATUS_STYLES: Record<OutputStatus, { readonly bg: string; readonly color: string }> = {
  inserted: { bg: 'rgba(76, 140, 74, 0.15)', color: 'var(--color-olive-gray)' },
  copied: { bg: 'var(--color-parchment)', color: 'var(--color-olive-gray)' },
  failed: { bg: 'rgba(200, 60, 50, 0.15)', color: 'var(--color-error)' },
}

function formatTime(timestamp: number): string {
  const date = new Date(timestamp)
  const hours = date.getHours().toString().padStart(2, '0')
  const minutes = date.getMinutes().toString().padStart(2, '0')
  return `${hours}:${minutes}`
}

export function HistoryItem({ record, onCopy }: HistoryItemProps) {
  const { t } = useTranslation()
  const [showOriginal, setShowOriginal] = useState(false)
  const [hovered, setHovered] = useState(false)

  const hasOriginal = record.originalText !== record.finalText
  const displayText = showOriginal ? record.originalText : record.finalText
  const statusStyle = STATUS_STYLES[record.outputStatus]

  const statusLabel: Record<OutputStatus, string> = {
    inserted: t('history.inserted'),
    copied: t('history.copied'),
    failed: t('history.failed'),
  }

  return (
    <div
      data-testid={`history-item-${record.id}`}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      style={{
        display: 'flex',
        alignItems: 'flex-start',
        gap: '12px',
        padding: '10px 16px',
        borderBottom: '1px solid var(--color-border-cream)',
        fontFamily: 'var(--font-sans)',
        fontSize: '0.9rem',
        position: 'relative',
      }}
    >
      {/* Time */}
      <span
        data-testid="history-item-time"
        style={{
          flexShrink: 0,
          width: '48px',
          color: 'var(--color-olive-gray)',
          fontSize: '0.85rem',
        }}
      >
        {formatTime(record.timestamp)}
      </span>

      {/* Scene */}
      <span
        data-testid="history-item-scene"
        style={{
          flexShrink: 0,
          display: 'flex',
          alignItems: 'center',
          gap: '6px',
          width: '100px',
          fontSize: '0.85rem',
          color: 'var(--color-charcoal-warm)',
        }}
      >
        <span
          style={{
            width: '8px',
            height: '8px',
            borderRadius: '50%',
            background: 'var(--color-terracotta)',
            flexShrink: 0,
          }}
        />
        {record.sceneName}
      </span>

      {/* Text content */}
      <div style={{ flex: 1, minWidth: 0 }}>
        <p
          data-testid="history-item-text"
          style={{
            margin: 0,
            color: 'var(--color-near-black)',
            overflow: 'hidden',
            display: '-webkit-box',
            WebkitLineClamp: 2,
            WebkitBoxOrient: 'vertical',
            lineHeight: '1.4',
          }}
        >
          {displayText}
        </p>
        {hasOriginal && (
          <button
            data-testid="view-original-button"
            onClick={() => setShowOriginal((prev) => !prev)}
            style={{
              background: 'none',
              border: 'none',
              padding: 0,
              marginTop: '4px',
              color: 'var(--color-terracotta)',
              fontSize: '0.8rem',
              cursor: 'pointer',
              textDecoration: 'underline',
            }}
          >
            {t('history.viewOriginal')}
          </button>
        )}
      </div>

      {/* Status badge */}
      <span
        data-testid="history-item-status"
        style={{
          flexShrink: 0,
          padding: '2px 8px',
          borderRadius: '10px',
          fontSize: '0.75rem',
          fontWeight: 500,
          background: statusStyle.bg,
          color: statusStyle.color,
        }}
      >
        {statusLabel[record.outputStatus]}
      </span>

      {/* Copy button */}
      {hovered && (
        <button
          data-testid="copy-button"
          onClick={() => onCopy(record.finalText)}
          style={{
            flexShrink: 0,
            padding: '4px 10px',
            fontSize: '0.8rem',
            fontWeight: 500,
            background: 'var(--color-warm-sand)',
            color: 'var(--color-near-black)',
            border: 'none',
            borderRadius: '6px',
            cursor: 'pointer',
            boxShadow: '0 0 0 1px var(--color-border-cream)',
          }}
        >
          {t('history.copy')}
        </button>
      )}
    </div>
  )
}
