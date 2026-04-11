import { useTranslation } from 'react-i18next'
import { useStore } from 'zustand'
import { useConfigStore } from '../../config/store'
import type { PipelineStep } from '../../types/pipeline'

function StepCard({
  step,
  index,
}: {
  readonly step: PipelineStep
  readonly index: number
}) {
  const { t } = useTranslation()

  return (
    <div
      data-testid={`pipeline-step-${index}`}
      style={{
        display: 'flex',
        gap: '12px',
        padding: '16px',
        background: 'var(--color-parchment)',
        borderRadius: 'var(--radius-md)',
        boxShadow: 'var(--shadow-ring)',
        marginBottom: '8px',
      }}
    >
      {/* Step number */}
      <span
        style={{
          width: '28px',
          height: '28px',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          borderRadius: '50%',
          background: 'var(--color-terracotta)',
          color: 'var(--color-ivory)',
          fontFamily: 'var(--font-sans)',
          fontSize: '0.82rem',
          fontWeight: 500,
          flexShrink: 0,
        }}
      >
        {index + 1}
      </span>

      <div style={{ flex: 1, minWidth: 0 }}>
        <div
          style={{
            fontFamily: 'var(--font-sans)',
            fontSize: '0.88rem',
            fontWeight: 500,
            color: 'var(--color-near-black)',
            marginBottom: '8px',
          }}
        >
          {step.type === 'stt' ? t('stt.speechToText') : t('llm.llmTransform')}
        </div>

        {step.type === 'stt' && (
          <div style={{ display: 'flex', gap: '16px' }}>
            <div>
              <label
                style={{
                  fontFamily: 'var(--font-sans)',
                  fontSize: '0.75rem',
                  color: 'var(--color-stone-gray)',
                }}
              >
                {t('common.provider')}
              </label>
              <div
                style={{
                  fontFamily: 'var(--font-sans)',
                  fontSize: '0.88rem',
                  color: 'var(--color-charcoal-warm)',
                }}
              >
                {step.provider}
              </div>
            </div>
            <div>
              <label
                style={{
                  fontFamily: 'var(--font-sans)',
                  fontSize: '0.75rem',
                  color: 'var(--color-stone-gray)',
                }}
              >
                {t('common.language')}
              </label>
              <div
                style={{
                  fontFamily: 'var(--font-sans)',
                  fontSize: '0.88rem',
                  color: 'var(--color-charcoal-warm)',
                }}
              >
                {step.lang}
              </div>
            </div>
          </div>
        )}

        {step.type === 'llm' && (
          <div>
            <div style={{ marginBottom: '8px' }}>
              <label
                style={{
                  fontFamily: 'var(--font-sans)',
                  fontSize: '0.75rem',
                  color: 'var(--color-stone-gray)',
                }}
              >
                {t('common.provider')}
              </label>
              <div
                style={{
                  fontFamily: 'var(--font-sans)',
                  fontSize: '0.88rem',
                  color: 'var(--color-charcoal-warm)',
                }}
              >
                {step.provider}
              </div>
            </div>
            <div>
              <label
                style={{
                  display: 'block',
                  fontFamily: 'var(--font-sans)',
                  fontSize: '0.75rem',
                  color: 'var(--color-stone-gray)',
                  marginBottom: '4px',
                }}
              >
                Prompt
              </label>
              <textarea
                data-testid={`step-prompt-${index}`}
                value={step.prompt}
                readOnly
                placeholder={t('llm.promptHint')}
                style={{
                  width: '100%',
                  minHeight: '80px',
                  fontFamily: 'var(--font-sans)',
                  fontSize: '0.88rem',
                  padding: '8px 12px',
                  border: '1px solid var(--color-border-warm)',
                  borderRadius: 'var(--radius-md)',
                  background: 'var(--color-ivory)',
                  color: 'var(--color-near-black)',
                  resize: 'vertical',
                  boxSizing: 'border-box',
                }}
              />
              <p
                style={{
                  fontFamily: 'var(--font-sans)',
                  fontSize: '0.7rem',
                  color: 'var(--color-stone-gray)',
                  marginTop: '4px',
                }}
              >
                {'Use {{input}} to reference the recognized text'}
              </p>
            </div>
          </div>
        )}
      </div>
    </div>
  )
}

export function SceneEditor({
  sceneId,
  onBack,
}: {
  readonly sceneId: string
  readonly onBack: () => void
}) {
  const { t } = useTranslation()
  const scene = useStore(useConfigStore, (s) => s.getScene(sceneId))

  if (!scene) {
    return (
      <div style={{ padding: '32px' }}>
        <p style={{ color: 'var(--color-error)' }}>Scene not found</p>
      </div>
    )
  }

  const inputStyle: React.CSSProperties = {
    width: '100%',
    fontFamily: 'var(--font-sans)',
    fontSize: '0.94rem',
    padding: '8px 12px',
    border: '1px solid var(--color-border-warm)',
    borderRadius: 'var(--radius-md)',
    background: 'var(--color-ivory)',
    color: 'var(--color-near-black)',
    boxSizing: 'border-box',
  }

  return (
    <div data-testid="scene-editor" style={{ padding: '32px' }}>
      {/* Breadcrumb */}
      <nav
        data-testid="scene-breadcrumb"
        style={{
          fontFamily: 'var(--font-sans)',
          fontSize: '0.88rem',
          color: 'var(--color-stone-gray)',
          marginBottom: '24px',
        }}
      >
        <span
          onClick={onBack}
          style={{
            cursor: 'pointer',
            color: 'var(--color-terracotta)',
          }}
        >
          {t('settings.scenes')}
        </span>
        <span style={{ margin: '0 8px' }}>{'>'}</span>
        <span style={{ color: 'var(--color-near-black)' }}>{scene.name}</span>
      </nav>

      {/* Scene Name */}
      <div style={{ marginBottom: '24px' }}>
        <label
          style={{
            display: 'block',
            fontFamily: 'var(--font-sans)',
            fontSize: '0.82rem',
            color: 'var(--color-stone-gray)',
            marginBottom: '6px',
          }}
        >
          {t('settings.sceneName')}
        </label>
        <input
          data-testid="scene-name-input"
          type="text"
          value={scene.name}
          readOnly
          style={inputStyle}
        />
      </div>

      {/* Pipeline Steps */}
      <div style={{ marginBottom: '24px' }}>
        <h3
          style={{
            fontFamily: 'var(--font-serif)',
            fontWeight: 500,
            fontSize: '1.3rem',
            color: 'var(--color-near-black)',
            marginBottom: '12px',
          }}
        >
          {t('settings.pipelineSteps')}
        </h3>
        {scene.pipeline.map((step, index) => (
          <StepCard key={index} step={step} index={index} />
        ))}
      </div>

      {/* Output mode */}
      <div style={{ marginBottom: '24px' }}>
        <label
          style={{
            display: 'block',
            fontFamily: 'var(--font-sans)',
            fontSize: '0.82rem',
            color: 'var(--color-stone-gray)',
            marginBottom: '6px',
          }}
        >
          {t('settings.outputMode')}
        </label>
        <select
          data-testid="output-mode-select"
          value={scene.output}
          readOnly
          style={{
            ...inputStyle,
            width: '200px',
          }}
        >
          <option value="simulate">{t('settings.simulateInput')}</option>
          <option value="clipboard">{t('settings.clipboard')}</option>
        </select>
      </div>

      {/* Hotkeys */}
      <div style={{ marginBottom: '24px', display: 'flex', gap: '16px' }}>
        <div style={{ flex: 1 }}>
          <label
            style={{
              display: 'block',
              fontFamily: 'var(--font-sans)',
              fontSize: '0.82rem',
              color: 'var(--color-stone-gray)',
              marginBottom: '6px',
            }}
          >
            {t('settings.hotkeyToggle')}
          </label>
          <input
            data-testid="scene-toggle-hotkey"
            type="text"
            value={scene.hotkey.toggleRecord ?? ''}
            readOnly
            placeholder={t('settings.clickToRecord')}
            style={inputStyle}
          />
        </div>
        <div style={{ flex: 1 }}>
          <label
            style={{
              display: 'block',
              fontFamily: 'var(--font-sans)',
              fontSize: '0.82rem',
              color: 'var(--color-stone-gray)',
              marginBottom: '6px',
            }}
          >
            {t('settings.hotkeyPush')}
          </label>
          <input
            data-testid="scene-push-hotkey"
            type="text"
            value={scene.hotkey.pushToTalk ?? ''}
            readOnly
            placeholder={t('settings.clickToRecord')}
            style={inputStyle}
          />
        </div>
      </div>

      {/* Action buttons */}
      <div style={{ display: 'flex', gap: '12px' }}>
        <button
          data-testid="save-button"
          style={{
            fontFamily: 'var(--font-sans)',
            fontSize: '0.94rem',
            fontWeight: 500,
            padding: '8px 24px',
            background: 'var(--color-terracotta)',
            color: 'var(--color-ivory)',
            border: 'none',
            borderRadius: 'var(--radius-md)',
            cursor: 'pointer',
          }}
        >
          {t('settings.save')}
        </button>
        <button
          data-testid="cancel-button"
          onClick={onBack}
          style={{
            fontFamily: 'var(--font-sans)',
            fontSize: '0.94rem',
            fontWeight: 500,
            padding: '8px 24px',
            background: 'var(--color-warm-sand)',
            color: 'var(--color-charcoal-warm)',
            border: 'none',
            borderRadius: 'var(--radius-md)',
            cursor: 'pointer',
          }}
        >
          {t('settings.cancel')}
        </button>
      </div>
    </div>
  )
}
