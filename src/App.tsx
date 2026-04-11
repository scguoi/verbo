import { useEffect, useState } from 'react'
import { getCurrentWindow } from '@tauri-apps/api/window'
import { FloatingWindow } from './windows/floating/FloatingWindow'
import { SettingsWindow } from './windows/settings/SettingsWindow'
import { HistoryWindow } from './windows/history/HistoryWindow'
import { createHistoryStore } from './stores/history'
import { initI18n } from './i18n'
import { useConfigStore } from './config/store'

type WindowLabel = 'floating' | 'settings' | 'history'

const historyStore = createHistoryStore()

function getWindowLabel(): WindowLabel {
  try {
    const label = getCurrentWindow().label
    if (label === 'floating' || label === 'settings' || label === 'history') {
      return label
    }
    return 'floating'
  } catch {
    return 'floating'
  }
}

function WindowRouter({ label }: { readonly label: WindowLabel }) {
  switch (label) {
    case 'settings':
      return <SettingsWindow />
    case 'history':
      return <HistoryWindow store={historyStore} />
    case 'floating':
    default:
      return <FloatingWindow />
  }
}

function App() {
  const [ready, setReady] = useState(false)
  const language = useConfigStore.getState().config.general.language

  useEffect(() => {
    initI18n(language).then(() => {
      setReady(true)
    })
  }, [language])

  if (!ready) {
    return null
  }

  const label = getWindowLabel()

  return <WindowRouter label={label} />
}

export default App
