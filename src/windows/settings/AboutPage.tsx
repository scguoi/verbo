import { useTranslation } from 'react-i18next'

export function AboutPage() {
  const { t } = useTranslation()

  return (
    <div data-testid="about-page" style={{ padding: '32px' }}>
      <h2
        style={{
          fontFamily: 'var(--font-serif)',
          fontWeight: 500,
          fontSize: '1.6rem',
          color: 'var(--color-near-black)',
          marginBottom: '24px',
        }}
      >
        {t('settings.about')}
      </h2>

      <div
        style={{
          background: 'var(--color-parchment)',
          borderRadius: 'var(--radius-lg)',
          padding: '32px',
          boxShadow: 'var(--shadow-ring)',
          maxWidth: '480px',
        }}
      >
        <h3
          style={{
            fontFamily: 'var(--font-serif)',
            fontWeight: 500,
            fontSize: '2rem',
            color: 'var(--color-near-black)',
            marginBottom: '8px',
          }}
        >
          Verbo
        </h3>

        <p
          data-testid="about-version"
          style={{
            fontFamily: 'var(--font-sans)',
            fontSize: '0.94rem',
            color: 'var(--color-olive-gray)',
            marginBottom: '16px',
          }}
        >
          {t('settings.aboutVersion')} 0.1.0
        </p>

        <p
          style={{
            fontFamily: 'var(--font-sans)',
            fontSize: '1rem',
            color: 'var(--color-charcoal-warm)',
            lineHeight: 1.6,
            marginBottom: '16px',
          }}
        >
          Voice-driven input assistant with configurable recognition scenes and
          processing pipelines.
        </p>

        <p
          style={{
            fontFamily: 'var(--font-sans)',
            fontSize: '0.88rem',
            color: 'var(--color-stone-gray)',
          }}
        >
          MIT License
        </p>
      </div>
    </div>
  )
}
