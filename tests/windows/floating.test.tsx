import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/react'
import { Waveform } from '../../src/windows/floating/Waveform'
import { Pill } from '../../src/windows/floating/Pill'
import { Bubble } from '../../src/windows/floating/Bubble'
import type { PipelineState } from '../../src/types/pipeline'

// Mock @tauri-apps/api modules
vi.mock('@tauri-apps/api', () => ({}))
vi.mock('@tauri-apps/plugin-global-shortcut', () => ({}))
vi.mock('@tauri-apps/plugin-clipboard-manager', () => ({}))

describe('Waveform', () => {
  it('renders default 5 bars', () => {
    render(<Waveform active={false} />)
    for (let i = 0; i < 5; i++) {
      expect(screen.getByTestId(`waveform-bar-${i}`)).toBeTruthy()
    }
  })

  it('renders custom bar count', () => {
    render(<Waveform active={false} barCount={3} />)
    expect(screen.getByTestId('waveform-bar-0')).toBeTruthy()
    expect(screen.getByTestId('waveform-bar-1')).toBeTruthy()
    expect(screen.getByTestId('waveform-bar-2')).toBeTruthy()
    expect(screen.queryByTestId('waveform-bar-3')).toBeNull()
  })

  it('applies active class when active', () => {
    render(<Waveform active={true} />)
    const bar = screen.getByTestId('waveform-bar-0')
    expect(bar.className).toContain('waveform-bar--active')
  })

  it('does not apply active class when inactive', () => {
    render(<Waveform active={false} />)
    const bar = screen.getByTestId('waveform-bar-0')
    expect(bar.className).not.toContain('waveform-bar--active')
  })
})

describe('Pill', () => {
  it('renders "Verbo" label in idle state', () => {
    const state: PipelineState = { status: 'idle' }
    render(<Pill state={state} />)
    expect(screen.getByTestId('pill-label').textContent).toBe('Verbo')
  })

  it('shows hotkey hint in idle state', () => {
    const state: PipelineState = { status: 'idle' }
    render(<Pill state={state} hotkeyHint="Alt+D" />)
    expect(screen.getByTestId('hotkey-hint').textContent).toBe('Alt+D')
  })

  it('does not show hotkey hint when not provided', () => {
    const state: PipelineState = { status: 'idle' }
    render(<Pill state={state} />)
    expect(screen.queryByTestId('hotkey-hint')).toBeNull()
  })

  it('renders waveform in recording state', () => {
    const state: PipelineState = { status: 'recording', startedAt: Date.now() }
    render(<Pill state={state} />)
    expect(screen.getByTestId('waveform-bar-0')).toBeTruthy()
  })

  it('shows elapsed time in recording state', () => {
    const state: PipelineState = { status: 'recording', startedAt: Date.now() }
    render(<Pill state={state} elapsed={65000} />)
    expect(screen.getByTestId('elapsed-time').textContent).toBe('1:05')
  })

  it('shows "Processing" in processing state', () => {
    const state: PipelineState = { status: 'processing', sourceText: 'hi', partialResult: '' }
    render(<Pill state={state} />)
    expect(screen.getByTestId('processing-label').textContent).toBe('Processing')
  })

  it('shows "Processing" in transcribing state', () => {
    const state: PipelineState = { status: 'transcribing', partialText: '' }
    render(<Pill state={state} />)
    expect(screen.getByTestId('processing-label').textContent).toBe('Processing')
  })

  it('shows "Verbo" in done state', () => {
    const state: PipelineState = { status: 'done', sourceText: '', finalText: '' }
    render(<Pill state={state} />)
    expect(screen.getByTestId('pill-label').textContent).toBe('Verbo')
  })

  it('shows "Error" in error state', () => {
    const state: PipelineState = { status: 'error', message: 'fail' }
    render(<Pill state={state} />)
    expect(screen.getByTestId('error-label').textContent).toBe('Error')
  })

  it('calls onClick when clicked', () => {
    const onClick = vi.fn()
    render(<Pill state={{ status: 'idle' }} onClick={onClick} />)
    fireEvent.click(screen.getByTestId('pill'))
    expect(onClick).toHaveBeenCalledOnce()
  })

  it('renders status dot', () => {
    render(<Pill state={{ status: 'idle' }} />)
    expect(screen.getByTestId('status-dot')).toBeTruthy()
  })
})

describe('Bubble', () => {
  it('does not render in idle state', () => {
    render(<Bubble state={{ status: 'idle' }} sceneName="Dictate" />)
    expect(screen.queryByTestId('bubble')).toBeNull()
  })

  it('does not render in recording state', () => {
    render(<Bubble state={{ status: 'recording', startedAt: Date.now() }} sceneName="Dictate" />)
    expect(screen.queryByTestId('bubble')).toBeNull()
  })

  it('renders partial text in transcribing state', () => {
    const state: PipelineState = { status: 'transcribing', partialText: 'hello world' }
    render(<Bubble state={state} sceneName="Dictate" />)
    expect(screen.getByTestId('bubble')).toBeTruthy()
    expect(screen.getByTestId('partial-text').textContent).toBe('hello world')
  })

  it('renders waveform in transcribing state', () => {
    const state: PipelineState = { status: 'transcribing', partialText: '' }
    render(<Bubble state={state} sceneName="Dictate" />)
    expect(screen.getByTestId('waveform-bar-0')).toBeTruthy()
  })

  it('renders source text with strikethrough in processing state', () => {
    const state: PipelineState = { status: 'processing', sourceText: 'original', partialResult: 'translated' }
    render(<Bubble state={state} sceneName="Polish" />)
    expect(screen.getByTestId('bubble-processing')).toBeTruthy()
  })

  it('shows copy button in done state', () => {
    const onCopy = vi.fn()
    const state: PipelineState = { status: 'done', sourceText: 'src', finalText: 'result' }
    render(<Bubble state={state} sceneName="Dictate" onCopy={onCopy} />)
    const copyBtn = screen.getByTestId('copy-button')
    expect(copyBtn).toBeTruthy()
    fireEvent.click(copyBtn)
    expect(onCopy).toHaveBeenCalledOnce()
  })

  it('shows retry button in done state', () => {
    const onRetry = vi.fn()
    const state: PipelineState = { status: 'done', sourceText: 'src', finalText: 'result' }
    render(<Bubble state={state} sceneName="Dictate" onRetry={onRetry} />)
    const retryBtn = screen.getByTestId('retry-button')
    expect(retryBtn).toBeTruthy()
    fireEvent.click(retryBtn)
    expect(onRetry).toHaveBeenCalledOnce()
  })

  it('shows final text in done state', () => {
    const state: PipelineState = { status: 'done', sourceText: 'src', finalText: 'final result' }
    render(<Bubble state={state} sceneName="Dictate" />)
    expect(screen.getByTestId('bubble-done').textContent).toContain('final result')
  })

  it('shows error message in error state', () => {
    const state: PipelineState = { status: 'error', message: 'Something went wrong' }
    render(<Bubble state={state} sceneName="Dictate" />)
    expect(screen.getByTestId('bubble-error').textContent).toContain('Something went wrong')
  })

  it('shows retry button in error state', () => {
    const onRetry = vi.fn()
    const state: PipelineState = { status: 'error', message: 'fail' }
    render(<Bubble state={state} sceneName="Dictate" onRetry={onRetry} />)
    fireEvent.click(screen.getByTestId('retry-button'))
    expect(onRetry).toHaveBeenCalledOnce()
  })

  it('displays scene name', () => {
    const state: PipelineState = { status: 'done', sourceText: '', finalText: '' }
    render(<Bubble state={state} sceneName="Translate" />)
    expect(screen.getByTestId('bubble').textContent).toContain('Translate')
  })

  it('shows done status text', () => {
    const state: PipelineState = { status: 'done', sourceText: '', finalText: '' }
    render(<Bubble state={state} sceneName="Dictate" />)
    expect(screen.getByTestId('done-status').textContent).toBe('Done')
  })
})

describe('FloatingWindow integration', () => {
  beforeEach(() => {
    vi.resetModules()
  })

  it('renders pill and responds to state', () => {
    // Test Pill + Bubble integration without full FloatingWindow store wiring
    const state: PipelineState = { status: 'idle' }
    const { container } = render(
      <div>
        <Pill state={state} hotkeyHint="Alt+D" />
        <Bubble state={state} sceneName="Dictate" />
      </div>,
    )
    expect(screen.getByTestId('pill')).toBeTruthy()
    expect(screen.queryByTestId('bubble')).toBeNull()
    expect(container).toBeTruthy()
  })

  it('shows bubble when state transitions to done', () => {
    const state: PipelineState = { status: 'done', sourceText: 'src', finalText: 'result' }
    render(
      <div data-testid="floating-window">
        <Pill state={state} />
        <Bubble state={state} sceneName="Dictate" onCopy={vi.fn()} />
      </div>,
    )
    expect(screen.getByTestId('pill')).toBeTruthy()
    expect(screen.getByTestId('bubble')).toBeTruthy()
    expect(screen.getByTestId('copy-button')).toBeTruthy()
  })

  it('shows bubble with error content on error state', () => {
    const state: PipelineState = { status: 'error', message: 'Network error' }
    render(
      <div data-testid="floating-window">
        <Pill state={state} />
        <Bubble state={state} sceneName="Dictate" onRetry={vi.fn()} />
      </div>,
    )
    expect(screen.getByTestId('error-label').textContent).toBe('Error')
    expect(screen.getByTestId('bubble-error').textContent).toContain('Network error')
  })

  it('shows recording state with waveform and timer', () => {
    const state: PipelineState = { status: 'recording', startedAt: Date.now() - 30000 }
    render(
      <div data-testid="floating-window">
        <Pill state={state} elapsed={30000} />
        <Bubble state={state} sceneName="Dictate" />
      </div>,
    )
    expect(screen.getByTestId('waveform-bar-0')).toBeTruthy()
    expect(screen.getByTestId('elapsed-time').textContent).toBe('0:30')
    expect(screen.queryByTestId('bubble')).toBeNull()
  })
})
