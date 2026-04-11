import { useEffect } from 'react'
import { listen } from '@tauri-apps/api/event'

export interface HotkeyEvent {
  readonly id: string
  readonly action: 'pressed' | 'released'
}

export function useHotkey(onHotkey: (event: HotkeyEvent) => void) {
  useEffect(() => {
    const unlisten = listen<HotkeyEvent>('hotkey', (event) => {
      onHotkey(event.payload)
    })
    return () => {
      unlisten.then((fn) => fn())
    }
  }, [onHotkey])
}
