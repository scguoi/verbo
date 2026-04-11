import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/react'
import { I18nextProvider } from 'react-i18next'
import i18n from 'i18next'
import { initReactI18next } from 'react-i18next'
import { en } from '../../src/i18n/en'
import { useConfigStore } from '../../src/config/store'
import { DEFAULT_CONFIG } from '../../src/config/defaults'
import { createHistoryStore } from '../../src/stores/history'
import type { HistoryRecord } from '../../src/types/history'

// Mock Tauri APIs
vi.mock('@tauri-apps/api', () => ({}))
vi.mock('@tauri-apps/plugin-global-shortcut', () => ({}))
vi.mock('@tauri-apps/plugin-clipboard-manager', () => ({}))

// Initialize i18n for tests
const testI18n = i18n.createInstance()
testI18n.use(initReactI18next).init({
  resources: { en: { translation: en } },
  lng: 'en',
  fallbackLng: 'en',
  interpolation: { escapeValue: false },
})

function Wrapper({ children }: { readonly children: React.ReactNode }) {
  return <I18nextProvider i18n={testI18n}>{children}</I18nextProvider>
}

function renderWithI18n(ui: React.ReactElement) {
  return render(ui, { wrapper: Wrapper })
}

const now = new Date()
const todayTimestamp = now.getTime()
const yesterdayTimestamp = now.getTime() - 24 * 60 * 60 * 1000
const olderTimestamp = now.getTime() - 3 * 24 * 60 * 60 * 1000

const makeRecord = (overrides: Partial<HistoryRecord> = {}): HistoryRecord => ({
  id: 'rec-1',
  timestamp: todayTimestamp,
  sceneId: 'dictate',
  sceneName: 'Dictate',
  originalText: 'hello world',
  finalText: 'Hello, world!',
  outputStatus: 'inserted',
  pipelineSteps: ['stt'],
  ...overrides,
})

describe('HistoryItem', () => {
  it('renders time, scene name, and text', async () => {
    const { HistoryItem } = await import(
      '../../src/windows/history/HistoryItem'
    )
    const record = makeRecord()
    renderWithI18n(<HistoryItem record={record} onCopy={vi.fn()} />)

    const time = screen.getByTestId('history-item-time')
    const hours = new Date(todayTimestamp).getHours().toString().padStart(2, '0')
    const minutes = new Date(todayTimestamp).getMinutes().toString().padStart(2, '0')
    expect(time.textContent).toBe(`${hours}:${minutes}`)

    expect(screen.getByTestId('history-item-scene').textContent).toContain('Dictate')
    expect(screen.getByTestId('history-item-text').textContent).toBe('Hello, world!')
  })

  it('shows status badge with correct color for inserted', async () => {
    const { HistoryItem } = await import(
      '../../src/windows/history/HistoryItem'
    )
    const record = makeRecord({ outputStatus: 'inserted' })
    renderWithI18n(<HistoryItem record={record} onCopy={vi.fn()} />)

    const badge = screen.getByTestId('history-item-status')
    expect(badge.textContent).toBe('Inserted')
    expect(badge.style.background).toContain('76, 140, 74')
  })

  it('shows status badge for failed', async () => {
    const { HistoryItem } = await import(
      '../../src/windows/history/HistoryItem'
    )
    const record = makeRecord({ outputStatus: 'failed' })
    renderWithI18n(<HistoryItem record={record} onCopy={vi.fn()} />)

    const badge = screen.getByTestId('history-item-status')
    expect(badge.textContent).toBe('Failed')
    expect(badge.style.background).toContain('200, 60, 50')
  })

  it('copy button calls onCopy with finalText', async () => {
    const { HistoryItem } = await import(
      '../../src/windows/history/HistoryItem'
    )
    const onCopy = vi.fn()
    const record = makeRecord({ finalText: 'copied text' })
    renderWithI18n(<HistoryItem record={record} onCopy={onCopy} />)

    // Hover to show the copy button
    fireEvent.mouseEnter(screen.getByTestId(`history-item-${record.id}`))
    fireEvent.click(screen.getByTestId('copy-button'))

    expect(onCopy).toHaveBeenCalledWith('copied text')
  })

  it('"View original" link toggles text when originalText differs', async () => {
    const { HistoryItem } = await import(
      '../../src/windows/history/HistoryItem'
    )
    const record = makeRecord({
      originalText: 'raw input',
      finalText: 'polished output',
    })
    renderWithI18n(<HistoryItem record={record} onCopy={vi.fn()} />)

    expect(screen.getByTestId('history-item-text').textContent).toBe('polished output')

    const viewOriginal = screen.getByTestId('view-original-button')
    expect(viewOriginal).toBeTruthy()

    fireEvent.click(viewOriginal)
    expect(screen.getByTestId('history-item-text').textContent).toBe('raw input')

    fireEvent.click(viewOriginal)
    expect(screen.getByTestId('history-item-text').textContent).toBe('polished output')
  })

  it('does not show "View original" when texts are the same', async () => {
    const { HistoryItem } = await import(
      '../../src/windows/history/HistoryItem'
    )
    const record = makeRecord({
      originalText: 'same text',
      finalText: 'same text',
    })
    renderWithI18n(<HistoryItem record={record} onCopy={vi.fn()} />)

    expect(screen.queryByTestId('view-original-button')).toBeNull()
  })
})

describe('HistoryWindow', () => {
  beforeEach(() => {
    useConfigStore.setState({ config: DEFAULT_CONFIG })
  })

  it('renders search input and filter dropdown', async () => {
    const { HistoryWindow } = await import(
      '../../src/windows/history/HistoryWindow'
    )
    const store = createHistoryStore()
    renderWithI18n(<HistoryWindow store={store} />)

    expect(screen.getByTestId('history-search')).toBeTruthy()
    expect(screen.getByTestId('history-scene-filter')).toBeTruthy()
  })

  it('renders grouped records by date', async () => {
    const { HistoryWindow } = await import(
      '../../src/windows/history/HistoryWindow'
    )
    const store = createHistoryStore()

    store.getState().addRecord({
      sceneId: 'dictate',
      sceneName: 'Dictate',
      originalText: 'today text',
      finalText: 'today text',
      outputStatus: 'inserted',
      pipelineSteps: ['stt'],
    })

    // Manually add a yesterday record by manipulating state
    const yesterdayRecord: HistoryRecord = {
      id: 'yesterday-1',
      timestamp: yesterdayTimestamp,
      sceneId: 'polish',
      sceneName: 'Polish',
      originalText: 'yesterday text',
      finalText: 'yesterday polished',
      outputStatus: 'copied',
      pipelineSteps: ['stt', 'llm'],
    }
    store.setState({
      records: [...store.getState().records, yesterdayRecord],
    })

    renderWithI18n(<HistoryWindow store={store} />)

    expect(screen.getByTestId('date-group-Today')).toBeTruthy()
    expect(screen.getByTestId('date-group-Yesterday')).toBeTruthy()
  })

  it('shows record count in footer', async () => {
    const { HistoryWindow } = await import(
      '../../src/windows/history/HistoryWindow'
    )
    const store = createHistoryStore()

    store.getState().addRecord({
      sceneId: 'dictate',
      sceneName: 'Dictate',
      originalText: 'text one',
      finalText: 'text one',
      outputStatus: 'inserted',
      pipelineSteps: ['stt'],
    })
    store.getState().addRecord({
      sceneId: 'polish',
      sceneName: 'Polish',
      originalText: 'text two',
      finalText: 'text two polished',
      outputStatus: 'copied',
      pipelineSteps: ['stt', 'llm'],
    })

    renderWithI18n(<HistoryWindow store={store} />)

    const footer = screen.getByTestId('history-record-count')
    expect(footer.textContent).toContain('2')
    expect(footer.textContent).toContain('records')
  })
})
