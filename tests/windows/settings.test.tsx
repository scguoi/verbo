import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/react'
import { I18nextProvider } from 'react-i18next'
import i18n from 'i18next'
import { initReactI18next } from 'react-i18next'
import { en } from '../../src/i18n/en'
import { useConfigStore } from '../../src/config/store'
import { DEFAULT_CONFIG } from '../../src/config/defaults'

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

describe('SettingsWindow', () => {
  beforeEach(() => {
    useConfigStore.setState({ config: DEFAULT_CONFIG })
  })

  it('renders sidebar with all tab labels', async () => {
    const { SettingsWindow } = await import(
      '../../src/windows/settings/SettingsWindow'
    )
    renderWithI18n(<SettingsWindow />)

    expect(screen.getByTestId('settings-sidebar')).toBeTruthy()
    expect(screen.getByTestId('tab-scenes').textContent).toBe('Scenes')
    expect(screen.getByTestId('tab-providers').textContent).toBe('Providers')
    expect(screen.getByTestId('tab-general').textContent).toBe('General')
    expect(screen.getByTestId('tab-about').textContent).toBe('About')
  })

  it('clicking tab changes content', async () => {
    const { SettingsWindow } = await import(
      '../../src/windows/settings/SettingsWindow'
    )
    renderWithI18n(<SettingsWindow />)

    // Default: scenes page
    expect(screen.getByTestId('scenes-page')).toBeTruthy()

    // Click providers
    fireEvent.click(screen.getByTestId('tab-providers'))
    expect(screen.getByTestId('providers-page')).toBeTruthy()
    expect(screen.queryByTestId('scenes-page')).toBeNull()

    // Click general
    fireEvent.click(screen.getByTestId('tab-general'))
    expect(screen.getByTestId('general-page')).toBeTruthy()

    // Click about
    fireEvent.click(screen.getByTestId('tab-about'))
    expect(screen.getByTestId('about-page')).toBeTruthy()
  })
})

describe('ScenesPage', () => {
  beforeEach(() => {
    useConfigStore.setState({ config: DEFAULT_CONFIG })
  })

  it('lists all scenes from config', async () => {
    const { ScenesPage } = await import(
      '../../src/windows/settings/ScenesPage'
    )
    renderWithI18n(<ScenesPage onSelectScene={vi.fn()} />)

    expect(screen.getByTestId('scene-item-dictate')).toBeTruthy()
    expect(screen.getByTestId('scene-item-polish')).toBeTruthy()
    expect(screen.getByTestId('scene-item-translate')).toBeTruthy()
  })

  it('shows default badge on the default scene', async () => {
    const { ScenesPage } = await import(
      '../../src/windows/settings/ScenesPage'
    )
    renderWithI18n(<ScenesPage onSelectScene={vi.fn()} />)

    expect(screen.getByTestId('scene-default-dictate')).toBeTruthy()
    expect(screen.queryByTestId('scene-default-polish')).toBeNull()
  })

  it('calls onSelectScene when a scene is clicked', async () => {
    const { ScenesPage } = await import(
      '../../src/windows/settings/ScenesPage'
    )
    const onSelect = vi.fn()
    renderWithI18n(<ScenesPage onSelectScene={onSelect} />)

    fireEvent.click(screen.getByTestId('scene-item-polish'))
    expect(onSelect).toHaveBeenCalledWith('polish')
  })
})

describe('SceneEditor', () => {
  beforeEach(() => {
    useConfigStore.setState({ config: DEFAULT_CONFIG })
  })

  it('shows scene name input with correct value', async () => {
    const { SceneEditor } = await import(
      '../../src/windows/settings/SceneEditor'
    )
    renderWithI18n(<SceneEditor sceneId="dictate" onBack={vi.fn()} />)

    const nameInput = screen.getByTestId('scene-name-input') as HTMLInputElement
    expect(nameInput.value).toBe('Dictate')
  })

  it('shows breadcrumb with scene name', async () => {
    const { SceneEditor } = await import(
      '../../src/windows/settings/SceneEditor'
    )
    renderWithI18n(<SceneEditor sceneId="polish" onBack={vi.fn()} />)

    const breadcrumb = screen.getByTestId('scene-breadcrumb')
    expect(breadcrumb.textContent).toContain('Scenes')
    expect(breadcrumb.textContent).toContain('Polish')
  })

  it('renders pipeline steps', async () => {
    const { SceneEditor } = await import(
      '../../src/windows/settings/SceneEditor'
    )
    renderWithI18n(<SceneEditor sceneId="polish" onBack={vi.fn()} />)

    expect(screen.getByTestId('pipeline-step-0')).toBeTruthy()
    expect(screen.getByTestId('pipeline-step-1')).toBeTruthy()
  })

  it('calls onBack when cancel is clicked', async () => {
    const { SceneEditor } = await import(
      '../../src/windows/settings/SceneEditor'
    )
    const onBack = vi.fn()
    renderWithI18n(<SceneEditor sceneId="dictate" onBack={onBack} />)

    fireEvent.click(screen.getByTestId('cancel-button'))
    expect(onBack).toHaveBeenCalledOnce()
  })
})

describe('ProvidersPage', () => {
  beforeEach(() => {
    useConfigStore.setState({ config: DEFAULT_CONFIG })
  })

  it('renders STT and LLM sections', async () => {
    const { ProvidersPage } = await import(
      '../../src/windows/settings/ProvidersPage'
    )
    renderWithI18n(<ProvidersPage />)

    expect(screen.getByTestId('stt-section-title').textContent).toBe(
      'Speech-to-Text Providers',
    )
    expect(screen.getByTestId('llm-section-title').textContent).toBe(
      'LLM Providers',
    )
  })

  it('renders provider cards', async () => {
    const { ProvidersPage } = await import(
      '../../src/windows/settings/ProvidersPage'
    )
    renderWithI18n(<ProvidersPage />)

    expect(screen.getByTestId('provider-card-iflytek')).toBeTruthy()
    expect(screen.getByTestId('provider-card-openai')).toBeTruthy()
  })

  it('renders language chips for STT providers', async () => {
    const { ProvidersPage } = await import(
      '../../src/windows/settings/ProvidersPage'
    )
    renderWithI18n(<ProvidersPage />)

    expect(screen.getByTestId('lang-chip-zh')).toBeTruthy()
    expect(screen.getByTestId('lang-chip-en')).toBeTruthy()
  })
})

describe('GeneralPage', () => {
  beforeEach(() => {
    useConfigStore.setState({ config: DEFAULT_CONFIG })
  })

  it('renders global hotkey fields', async () => {
    const { GeneralPage } = await import(
      '../../src/windows/settings/GeneralPage'
    )
    renderWithI18n(<GeneralPage />)

    const toggleInput = screen.getByTestId(
      'global-toggle-hotkey',
    ) as HTMLInputElement
    const pushInput = screen.getByTestId(
      'global-push-hotkey',
    ) as HTMLInputElement

    expect(toggleInput.value).toBe('CommandOrControl+Shift+H')
    expect(pushInput.value).toBe('CommandOrControl+Shift+G')
  })

  it('renders general page container', async () => {
    const { GeneralPage } = await import(
      '../../src/windows/settings/GeneralPage'
    )
    renderWithI18n(<GeneralPage />)

    expect(screen.getByTestId('general-page')).toBeTruthy()
  })
})

describe('AboutPage', () => {
  it('shows version number', async () => {
    const { AboutPage } = await import(
      '../../src/windows/settings/AboutPage'
    )
    renderWithI18n(<AboutPage />)

    const version = screen.getByTestId('about-version')
    expect(version.textContent).toContain('0.1.0')
  })

  it('shows app name and license', async () => {
    const { AboutPage } = await import(
      '../../src/windows/settings/AboutPage'
    )
    renderWithI18n(<AboutPage />)

    const page = screen.getByTestId('about-page')
    expect(page.textContent).toContain('Verbo')
    expect(page.textContent).toContain('MIT License')
  })
})
