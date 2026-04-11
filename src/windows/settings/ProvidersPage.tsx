import { useTranslation } from 'react-i18next'
import { useStore } from 'zustand'
import { useConfigStore } from '../../config/store'
import type { LLMProviderConfig, STTProviderConfig } from '../../types/config'

function ProviderCard({
  name,
  children,
}: {
  readonly name: string
  readonly children: React.ReactNode
}) {
  return (
    <div
      data-testid={`provider-card-${name}`}
      style={{
        background: 'var(--color-parchment)',
        borderRadius: 'var(--radius-lg)',
        padding: '20px',
        boxShadow: 'var(--shadow-ring)',
        marginBottom: '16px',
      }}
    >
      <h4
        style={{
          fontFamily: 'var(--font-serif)',
          fontWeight: 500,
          fontSize: '1.1rem',
          color: 'var(--color-near-black)',
          marginBottom: '16px',
          textTransform: 'capitalize',
        }}
      >
        {name}
      </h4>
      {children}
    </div>
  )
}

function FieldInput({
  label,
  value,
  type = 'text',
}: {
  readonly label: string
  readonly value: string
  readonly type?: string
}) {
  return (
    <div style={{ marginBottom: '12px' }}>
      <label
        style={{
          display: 'block',
          fontFamily: 'var(--font-sans)',
          fontSize: '0.82rem',
          color: 'var(--color-stone-gray)',
          marginBottom: '4px',
        }}
      >
        {label}
      </label>
      <input
        type={type}
        value={value}
        readOnly
        style={{
          width: '100%',
          fontFamily: 'var(--font-sans)',
          fontSize: '0.94rem',
          padding: '6px 12px',
          border: '1px solid var(--color-border-warm)',
          borderRadius: 'var(--radius-md)',
          background: 'var(--color-ivory)',
          color: 'var(--color-near-black)',
          boxSizing: 'border-box',
        }}
      />
    </div>
  )
}

function LanguageChips({
  langs,
}: {
  readonly langs: readonly string[]
}) {
  return (
    <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
      {langs.map((lang) => (
        <span
          key={lang}
          data-testid={`lang-chip-${lang}`}
          style={{
            fontFamily: 'var(--font-sans)',
            fontSize: '0.75rem',
            padding: '2px 10px',
            borderRadius: 'var(--radius-pill)',
            background: 'var(--color-warm-sand)',
            color: 'var(--color-charcoal-warm)',
            cursor: 'pointer',
          }}
        >
          {lang}
        </span>
      ))}
    </div>
  )
}

function STTProviderSection({
  name,
  provider,
}: {
  readonly name: string
  readonly provider: STTProviderConfig
}) {
  const { t } = useTranslation()
  const { enabledLangs, ...fields } = provider

  return (
    <ProviderCard name={name}>
      {Object.entries(fields).map(([key, value]) => (
        <FieldInput
          key={key}
          label={key}
          value={String(value)}
          type={key.toLowerCase().includes('key') || key.toLowerCase().includes('secret') ? 'password' : 'text'}
        />
      ))}
      <div style={{ marginTop: '8px' }}>
        <label
          style={{
            display: 'block',
            fontFamily: 'var(--font-sans)',
            fontSize: '0.82rem',
            color: 'var(--color-stone-gray)',
            marginBottom: '6px',
          }}
        >
          {t('settings.supportedLangs')}
        </label>
        <LanguageChips langs={enabledLangs} />
      </div>
    </ProviderCard>
  )
}

function LLMProviderSection({
  name,
  provider,
}: {
  readonly name: string
  readonly provider: LLMProviderConfig
}) {
  return (
    <ProviderCard name={name}>
      <FieldInput label="API Key" value={provider.apiKey} type="password" />
      <div style={{ marginBottom: '12px' }}>
        <label
          style={{
            display: 'block',
            fontFamily: 'var(--font-sans)',
            fontSize: '0.82rem',
            color: 'var(--color-stone-gray)',
            marginBottom: '4px',
          }}
        >
          Model
        </label>
        <select
          value={provider.model}
          readOnly
          style={{
            width: '100%',
            fontFamily: 'var(--font-sans)',
            fontSize: '0.94rem',
            padding: '6px 12px',
            border: '1px solid var(--color-border-warm)',
            borderRadius: 'var(--radius-md)',
            background: 'var(--color-ivory)',
            color: 'var(--color-near-black)',
          }}
        >
          <option value={provider.model}>{provider.model}</option>
        </select>
      </div>
      <FieldInput label="Base URL" value={provider.baseUrl} />
    </ProviderCard>
  )
}

export function ProvidersPage() {
  const { t } = useTranslation()
  const providers = useStore(useConfigStore, (s) => s.config.providers)

  return (
    <div data-testid="providers-page" style={{ padding: '32px' }}>
      <h2
        style={{
          fontFamily: 'var(--font-serif)',
          fontWeight: 500,
          fontSize: '1.6rem',
          color: 'var(--color-near-black)',
          marginBottom: '4px',
        }}
      >
        {t('settings.providers')}
      </h2>
      <p
        style={{
          fontFamily: 'var(--font-sans)',
          fontSize: '0.88rem',
          color: 'var(--color-stone-gray)',
          marginBottom: '32px',
        }}
      >
        {t('settings.providersDesc')}
      </p>

      {/* STT Section */}
      <div style={{ marginBottom: '32px' }}>
        <h3
          data-testid="stt-section-title"
          style={{
            fontFamily: 'var(--font-serif)',
            fontWeight: 500,
            fontSize: '1.3rem',
            color: 'var(--color-near-black)',
            marginBottom: '16px',
          }}
        >
          {t('settings.sttSection')}
        </h3>
        {Object.entries(providers.stt).map(([name, provider]) => (
          <STTProviderSection key={name} name={name} provider={provider} />
        ))}
        <button
          data-testid="add-stt-provider"
          style={{
            fontFamily: 'var(--font-sans)',
            fontSize: '0.94rem',
            padding: '8px 16px',
            background: 'var(--color-warm-sand)',
            color: 'var(--color-charcoal-warm)',
            border: 'none',
            borderRadius: 'var(--radius-md)',
            cursor: 'pointer',
            boxShadow: 'var(--shadow-ring)',
          }}
        >
          {t('settings.addSttProvider')}
        </button>
      </div>

      {/* LLM Section */}
      <div style={{ marginBottom: '32px' }}>
        <h3
          data-testid="llm-section-title"
          style={{
            fontFamily: 'var(--font-serif)',
            fontWeight: 500,
            fontSize: '1.3rem',
            color: 'var(--color-near-black)',
            marginBottom: '16px',
          }}
        >
          {t('settings.llmSection')}
        </h3>
        {Object.entries(providers.llm).map(([name, provider]) => (
          <LLMProviderSection key={name} name={name} provider={provider} />
        ))}
        <button
          data-testid="add-llm-provider"
          style={{
            fontFamily: 'var(--font-sans)',
            fontSize: '0.94rem',
            padding: '8px 16px',
            background: 'var(--color-warm-sand)',
            color: 'var(--color-charcoal-warm)',
            border: 'none',
            borderRadius: 'var(--radius-md)',
            cursor: 'pointer',
            boxShadow: 'var(--shadow-ring)',
          }}
        >
          {t('settings.addLlmProvider')}
        </button>
      </div>
    </div>
  )
}
