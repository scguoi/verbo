import { useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useStore } from 'zustand'
import { useConfigStore } from '../../config/store'
import type { HistoryRecord } from '../../types/history'
import type { HistoryStore } from '../../stores/history'
import { HistoryItem } from './HistoryItem'

interface HistoryWindowProps {
  readonly store: { getState: () => HistoryStore; subscribe: (listener: (state: HistoryStore, prevState: HistoryStore) => void) => () => void }
}

interface DateGroup {
  readonly label: string
  readonly records: readonly HistoryRecord[]
}

function getDateLabel(timestamp: number, t: (key: string) => string): string {
  const date = new Date(timestamp)
  const now = new Date()

  const toDateKey = (d: Date) =>
    `${d.getFullYear()}-${d.getMonth()}-${d.getDate()}`

  if (toDateKey(date) === toDateKey(now)) {
    return t('history.today')
  }

  const yesterday = new Date(now)
  yesterday.setDate(yesterday.getDate() - 1)
  if (toDateKey(date) === toDateKey(yesterday)) {
    return t('history.yesterday')
  }

  return date.toLocaleDateString()
}

function groupByDate(
  records: readonly HistoryRecord[],
  t: (key: string) => string,
): readonly DateGroup[] {
  const groups = new Map<string, HistoryRecord[]>()
  const labelOrder: string[] = []

  for (const record of records) {
    const label = getDateLabel(record.timestamp, t)
    const existing = groups.get(label)
    if (existing) {
      existing.push(record)
    } else {
      groups.set(label, [record])
      labelOrder.push(label)
    }
  }

  return labelOrder.map((label) => ({
    label,
    records: groups.get(label) ?? [],
  }))
}

export function HistoryWindow({ store }: HistoryWindowProps) {
  const { t } = useTranslation()
  const [searchQuery, setSearchQuery] = useState('')
  const [sceneFilter, setSceneFilter] = useState('')

  const records = useStore(store, (s) => s.records)
  const search = useStore(store, (s) => s.search)
  const filterByScene = useStore(store, (s) => s.filterByScene)
  const clearAll = useStore(store, (s) => s.clearAll)
  const scenes = useStore(useConfigStore, (s) => s.config.scenes)

  const filteredRecords = useMemo(() => {
    if (searchQuery && sceneFilter) {
      const searched = search(searchQuery)
      return searched.filter((r) => r.sceneId === sceneFilter)
    }
    if (searchQuery) {
      return search(searchQuery)
    }
    if (sceneFilter) {
      return filterByScene(sceneFilter)
    }
    return records
  }, [records, searchQuery, sceneFilter, search, filterByScene])

  const dateGroups = useMemo(
    () => groupByDate(filteredRecords, t),
    [filteredRecords, t],
  )

  const handleCopy = (text: string) => {
    navigator.clipboard.writeText(text).catch(() => {
      // clipboard write failed silently
    })
  }

  return (
    <div
      data-testid="history-window"
      style={{
        display: 'flex',
        flexDirection: 'column',
        height: '100vh',
        background: 'var(--color-ivory)',
        fontFamily: 'var(--font-sans)',
      }}
    >
      {/* Toolbar */}
      <div
        data-testid="history-toolbar"
        style={{
          display: 'flex',
          alignItems: 'center',
          gap: '12px',
          padding: '12px 16px',
          borderBottom: '1px solid var(--color-border-cream)',
        }}
      >
        <h2
          style={{
            margin: 0,
            fontFamily: 'var(--font-serif)',
            fontWeight: 500,
            fontSize: '1.2rem',
            color: 'var(--color-near-black)',
            flexShrink: 0,
          }}
        >
          {t('history.title')}
        </h2>
        <input
          data-testid="history-search"
          type="text"
          placeholder={t('history.search')}
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
          style={{
            flex: 1,
            padding: '6px 12px',
            border: '1px solid var(--color-border-cream)',
            borderRadius: '6px',
            fontSize: '0.9rem',
            fontFamily: 'var(--font-sans)',
            background: 'white',
            outline: 'none',
          }}
        />
        <select
          data-testid="history-scene-filter"
          value={sceneFilter}
          onChange={(e) => setSceneFilter(e.target.value)}
          style={{
            padding: '6px 12px',
            border: '1px solid var(--color-border-cream)',
            borderRadius: '6px',
            fontSize: '0.9rem',
            fontFamily: 'var(--font-sans)',
            background: 'white',
            cursor: 'pointer',
          }}
        >
          <option value="">{t('history.allScenes')}</option>
          {scenes.map((scene) => (
            <option key={scene.id} value={scene.id}>
              {scene.name}
            </option>
          ))}
        </select>
      </div>

      {/* Record list */}
      <div
        data-testid="history-list"
        style={{ flex: 1, overflowY: 'auto' }}
      >
        {dateGroups.map((group) => (
          <div key={group.label}>
            <div
              data-testid={`date-group-${group.label}`}
              style={{
                padding: '8px 16px',
                fontSize: '0.75rem',
                fontWeight: 600,
                textTransform: 'uppercase',
                letterSpacing: '0.05em',
                color: 'var(--color-olive-gray)',
                background: 'var(--color-parchment)',
              }}
            >
              {group.label}
            </div>
            {group.records.map((record) => (
              <HistoryItem
                key={record.id}
                record={record}
                onCopy={handleCopy}
              />
            ))}
          </div>
        ))}
      </div>

      {/* Footer */}
      <div
        data-testid="history-footer"
        style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          padding: '10px 16px',
          borderTop: '1px solid var(--color-border-cream)',
          fontSize: '0.85rem',
          color: 'var(--color-olive-gray)',
        }}
      >
        <span data-testid="history-record-count">
          {filteredRecords.length} {t('history.records')}
        </span>
        <button
          data-testid="clear-all-button"
          onClick={clearAll}
          style={{
            background: 'transparent',
            border: 'none',
            color: 'var(--color-error)',
            fontSize: '0.85rem',
            fontWeight: 500,
            cursor: 'pointer',
            padding: '4px 8px',
          }}
        >
          {t('history.clearAll')}
        </button>
      </div>
    </div>
  )
}
