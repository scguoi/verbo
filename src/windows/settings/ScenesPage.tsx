import { useTranslation } from 'react-i18next'
import { useStore } from 'zustand'
import { useConfigStore } from '../../config/store'
import type { Scene } from '../../types/pipeline'

function pipelineSummary(scene: Scene): string {
  return scene.pipeline.map((step) => step.type.toUpperCase()).join(' → ')
}

function SceneItem({
  scene,
  isDefault,
  onClick,
}: {
  readonly scene: Scene
  readonly isDefault: boolean
  readonly onClick: () => void
}) {
  const { t } = useTranslation()

  const dotColors: Record<string, string> = {
    dictate: 'var(--color-terracotta)',
    polish: 'var(--color-coral)',
    translate: 'var(--color-success)',
  }
  const dotColor = dotColors[scene.id] ?? 'var(--color-stone-gray)'

  return (
    <div
      data-testid={`scene-item-${scene.id}`}
      onClick={onClick}
      style={{
        display: 'flex',
        alignItems: 'center',
        gap: '12px',
        padding: '14px 16px',
        background: 'var(--color-parchment)',
        borderRadius: 'var(--radius-md)',
        boxShadow: 'var(--shadow-ring)',
        cursor: 'pointer',
        marginBottom: '8px',
      }}
    >
      {/* Color dot */}
      <span
        data-testid={`scene-dot-${scene.id}`}
        style={{
          width: '10px',
          height: '10px',
          borderRadius: '50%',
          background: dotColor,
          flexShrink: 0,
        }}
      />

      {/* Name + pipeline */}
      <div style={{ flex: 1, minWidth: 0 }}>
        <div
          style={{
            fontFamily: 'var(--font-sans)',
            fontSize: '0.94rem',
            fontWeight: 500,
            color: 'var(--color-near-black)',
          }}
        >
          {scene.name}
        </div>
        <div
          style={{
            fontFamily: 'var(--font-sans)',
            fontSize: '0.75rem',
            color: 'var(--color-stone-gray)',
            marginTop: '2px',
          }}
        >
          {pipelineSummary(scene)}
        </div>
      </div>

      {/* Hotkey badge */}
      {scene.hotkey.toggleRecord && (
        <span
          data-testid={`scene-hotkey-${scene.id}`}
          style={{
            fontFamily: 'var(--font-mono)',
            fontSize: '0.7rem',
            padding: '2px 8px',
            background: 'var(--color-warm-sand)',
            color: 'var(--color-charcoal-warm)',
            borderRadius: 'var(--radius-sm)',
          }}
        >
          {scene.hotkey.toggleRecord}
        </span>
      )}

      {/* Default badge */}
      {isDefault && (
        <span
          data-testid={`scene-default-${scene.id}`}
          style={{
            fontFamily: 'var(--font-sans)',
            fontSize: '0.7rem',
            padding: '2px 8px',
            background: 'var(--color-terracotta)',
            color: 'var(--color-ivory)',
            borderRadius: 'var(--radius-sm)',
          }}
        >
          {t('settings.defaultBadge')}
        </span>
      )}
    </div>
  )
}

export function ScenesPage({
  onSelectScene,
}: {
  readonly onSelectScene: (sceneId: string) => void
}) {
  const { t } = useTranslation()
  const scenes = useStore(useConfigStore, (s) => s.config.scenes)
  const defaultSceneId = useStore(useConfigStore, (s) => s.config.defaultScene)

  return (
    <div data-testid="scenes-page" style={{ padding: '32px' }}>
      <div
        style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          marginBottom: '24px',
        }}
      >
        <div>
          <h2
            style={{
              fontFamily: 'var(--font-serif)',
              fontWeight: 500,
              fontSize: '1.6rem',
              color: 'var(--color-near-black)',
              marginBottom: '4px',
            }}
          >
            {t('settings.scenes')}
          </h2>
          <p
            style={{
              fontFamily: 'var(--font-sans)',
              fontSize: '0.88rem',
              color: 'var(--color-stone-gray)',
            }}
          >
            {t('settings.scenesDesc')}
          </p>
        </div>
        <button
          data-testid="new-scene-button"
          style={{
            fontFamily: 'var(--font-sans)',
            fontSize: '0.94rem',
            fontWeight: 500,
            padding: '8px 20px',
            background: 'var(--color-terracotta)',
            color: 'var(--color-ivory)',
            border: 'none',
            borderRadius: 'var(--radius-md)',
            cursor: 'pointer',
          }}
        >
          {t('settings.newScene')}
        </button>
      </div>

      <div>
        {scenes.map((scene) => (
          <SceneItem
            key={scene.id}
            scene={scene}
            isDefault={scene.id === defaultSceneId}
            onClick={() => onSelectScene(scene.id)}
          />
        ))}
      </div>
    </div>
  )
}
