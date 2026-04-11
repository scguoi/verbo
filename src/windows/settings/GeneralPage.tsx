import { useTranslation } from 'react-i18next'
import { useStore } from 'zustand'
import { useConfigStore } from '../../config/store'

function SectionTitle({ children }: { readonly children: React.ReactNode }) {
  return (
    <h3
      style={{
        fontFamily: 'var(--font-serif)',
        fontWeight: 500,
        fontSize: '1.3rem',
        color: 'var(--color-near-black)',
        marginBottom: '16px',
      }}
    >
      {children}
    </h3>
  )
}

function FieldRow({
  label,
  children,
}: {
  readonly label: string
  readonly children: React.ReactNode
}) {
  return (
    <div
      style={{
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        padding: '12px 0',
        borderBottom: '1px solid var(--color-border-cream)',
      }}
    >
      <span
        style={{
          fontFamily: 'var(--font-sans)',
          fontSize: '0.94rem',
          color: 'var(--color-charcoal-warm)',
        }}
      >
        {label}
      </span>
      {children}
    </div>
  )
}

export function GeneralPage() {
  const { t } = useTranslation()
  const config = useStore(useConfigStore, (s) => s.config)

  const inputStyle: React.CSSProperties = {
    fontFamily: 'var(--font-sans)',
    fontSize: '0.94rem',
    padding: '6px 12px',
    border: '1px solid var(--color-border-warm)',
    borderRadius: 'var(--radius-md)',
    background: 'var(--color-ivory)',
    color: 'var(--color-near-black)',
    minWidth: '160px',
  }

  return (
    <div data-testid="general-page" style={{ padding: '32px' }}>
      <h2
        style={{
          fontFamily: 'var(--font-serif)',
          fontWeight: 500,
          fontSize: '1.6rem',
          color: 'var(--color-near-black)',
          marginBottom: '4px',
        }}
      >
        {t('settings.general')}
      </h2>
      <p
        style={{
          fontFamily: 'var(--font-sans)',
          fontSize: '0.88rem',
          color: 'var(--color-stone-gray)',
          marginBottom: '32px',
        }}
      >
        {t('settings.generalDesc')}
      </p>

      {/* Global Hotkeys */}
      <div style={{ marginBottom: '32px' }}>
        <SectionTitle>{t('settings.globalHotkeys')}</SectionTitle>
        <p
          style={{
            fontFamily: 'var(--font-sans)',
            fontSize: '0.82rem',
            color: 'var(--color-stone-gray)',
            marginBottom: '12px',
          }}
        >
          {t('settings.globalHotkeysHint')}
        </p>
        <div
          style={{
            background: 'var(--color-parchment)',
            borderRadius: 'var(--radius-lg)',
            padding: '16px',
            boxShadow: 'var(--shadow-ring)',
          }}
        >
          <FieldRow label={t('settings.hotkeyToggle')}>
            <input
              data-testid="global-toggle-hotkey"
              type="text"
              readOnly
              value={config.globalHotkey.toggleRecord}
              style={inputStyle}
            />
          </FieldRow>
          <FieldRow label={t('settings.hotkeyPush')}>
            <input
              data-testid="global-push-hotkey"
              type="text"
              readOnly
              value={config.globalHotkey.pushToTalk}
              style={inputStyle}
            />
          </FieldRow>
        </div>
      </div>

      {/* Behavior */}
      <div style={{ marginBottom: '32px' }}>
        <SectionTitle>{t('settings.behavior')}</SectionTitle>
        <div
          style={{
            background: 'var(--color-parchment)',
            borderRadius: 'var(--radius-lg)',
            padding: '16px',
            boxShadow: 'var(--shadow-ring)',
          }}
        >
          <FieldRow label={t('settings.defaultOutputMode')}>
            <select style={inputStyle} value={config.general.defaultOutput} readOnly>
              <option value="simulate">{t('settings.simulateInput')}</option>
              <option value="clipboard">{t('settings.clipboard')}</option>
            </select>
          </FieldRow>
          <FieldRow label={t('settings.autoCollapseDelay')}>
            <select style={inputStyle} value={config.general.autoCollapseDelay} readOnly>
              <option value={1000}>1s</option>
              <option value={1500}>1.5s</option>
              <option value={2000}>2s</option>
              <option value={3000}>3s</option>
              <option value={5000}>5s</option>
            </select>
          </FieldRow>
          <FieldRow label={t('settings.launchAtStartup')}>
            <span
              style={{
                fontFamily: 'var(--font-sans)',
                fontSize: '0.88rem',
                color: config.general.launchAtStartup
                  ? 'var(--color-success)'
                  : 'var(--color-stone-gray)',
              }}
            >
              {config.general.launchAtStartup
                ? t('settings.enabled')
                : t('settings.disabled')}
            </span>
          </FieldRow>
        </div>
      </div>

      {/* Language */}
      <div style={{ marginBottom: '32px' }}>
        <SectionTitle>{t('settings.uiLanguage')}</SectionTitle>
        <div
          style={{
            background: 'var(--color-parchment)',
            borderRadius: 'var(--radius-lg)',
            padding: '16px',
            boxShadow: 'var(--shadow-ring)',
          }}
        >
          <FieldRow label={t('settings.uiLanguage')}>
            <select style={inputStyle} value={config.general.language} readOnly>
              <option value="system">{t('settings.followSystem')}</option>
              <option value="zh-CN">中文</option>
              <option value="en">English</option>
            </select>
          </FieldRow>
        </div>
      </div>

      {/* Data */}
      <div style={{ marginBottom: '32px' }}>
        <SectionTitle>{t('settings.data')}</SectionTitle>
        <div
          style={{
            background: 'var(--color-parchment)',
            borderRadius: 'var(--radius-lg)',
            padding: '16px',
            boxShadow: 'var(--shadow-ring)',
          }}
        >
          <FieldRow label={t('settings.historyRetention')}>
            <select
              style={inputStyle}
              value={config.general.historyRetentionDays}
              readOnly
            >
              <option value={7}>7 days</option>
              <option value={14}>14 days</option>
              <option value={30}>30 days</option>
              <option value={90}>90 days</option>
              <option value={0}>{t('settings.forever')}</option>
            </select>
          </FieldRow>
          <FieldRow label={t('settings.configPath')}>
            <span
              data-testid="config-path"
              style={{
                fontFamily: 'var(--font-mono)',
                fontSize: '0.82rem',
                color: 'var(--color-olive-gray)',
              }}
            >
              ~/.config/verbo/config.json
            </span>
          </FieldRow>
        </div>
      </div>
    </div>
  )
}
