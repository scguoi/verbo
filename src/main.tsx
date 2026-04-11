import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App'
import './styles/global.css'
import { recordingStore } from './stores/recording'
import { appStore } from './stores/app'
import { useConfigStore } from './config/store'

// Expose stores for dev/testing
if (import.meta.env.DEV) {
  Object.assign(window, { __verbo: { recordingStore, appStore, configStore: useConfigStore } })
}

ReactDOM.createRoot(document.getElementById('root') as HTMLElement).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
)
