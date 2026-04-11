import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { ScenesPage } from './ScenesPage'
import { SceneEditor } from './SceneEditor'
import { ProvidersPage } from './ProvidersPage'
import { GeneralPage } from './GeneralPage'
import { AboutPage } from './AboutPage'

type TabId = 'scenes' | 'providers' | 'general' | 'about'

interface SidebarTabProps {
  readonly id: TabId
  readonly label: string
  readonly active: boolean
  readonly onClick: () => void
}

function SidebarTab({ id, label, active, onClick }: SidebarTabProps) {
  return (
    <button
      data-testid={`tab-${id}`}
      onClick={onClick}
      style={{
        display: 'block',
        width: '100%',
        textAlign: 'left',
        padding: '10px 20px',
        fontFamily: 'var(--font-sans)',
        fontSize: '0.94rem',
        fontWeight: active ? 500 : 400,
        color: active ? 'var(--color-terracotta)' : 'var(--color-charcoal-warm)',
        background: active ? 'var(--color-ivory)' : 'transparent',
        border: 'none',
        borderRight: active ? '3px solid var(--color-terracotta)' : '3px solid transparent',
        cursor: 'pointer',
      }}
    >
      {label}
    </button>
  )
}

export function SettingsWindow() {
  const { t } = useTranslation()
  const [activeTab, setActiveTab] = useState<TabId>('scenes')
  const [editingSceneId, setEditingSceneId] = useState<string | null>(null)

  const tabs: readonly { readonly id: TabId; readonly labelKey: string }[] = [
    { id: 'scenes', labelKey: 'settings.scenes' },
    { id: 'providers', labelKey: 'settings.providers' },
    { id: 'general', labelKey: 'settings.general' },
    { id: 'about', labelKey: 'settings.about' },
  ]

  const handleTabClick = (tabId: TabId) => {
    setActiveTab(tabId)
    setEditingSceneId(null)
  }

  const renderContent = () => {
    if (activeTab === 'scenes' && editingSceneId) {
      return (
        <SceneEditor
          sceneId={editingSceneId}
          onBack={() => setEditingSceneId(null)}
        />
      )
    }

    switch (activeTab) {
      case 'scenes':
        return <ScenesPage onSelectScene={setEditingSceneId} />
      case 'providers':
        return <ProvidersPage />
      case 'general':
        return <GeneralPage />
      case 'about':
        return <AboutPage />
    }
  }

  return (
    <div
      data-testid="settings-window"
      style={{
        display: 'flex',
        height: '100vh',
        fontFamily: 'var(--font-sans)',
      }}
    >
      {/* Sidebar */}
      <aside
        data-testid="settings-sidebar"
        style={{
          width: '200px',
          flexShrink: 0,
          background: 'var(--color-parchment)',
          borderRight: '1px solid var(--color-border-cream)',
          paddingTop: '24px',
        }}
      >
        <h2
          style={{
            fontFamily: 'var(--font-serif)',
            fontWeight: 500,
            fontSize: '1.3rem',
            color: 'var(--color-near-black)',
            padding: '0 20px',
            marginBottom: '20px',
          }}
        >
          {t('settings.title')}
        </h2>
        <nav>
          {tabs.map((tab) => (
            <SidebarTab
              key={tab.id}
              id={tab.id}
              label={t(tab.labelKey)}
              active={activeTab === tab.id}
              onClick={() => handleTabClick(tab.id)}
            />
          ))}
        </nav>
      </aside>

      {/* Content */}
      <main
        data-testid="settings-content"
        style={{
          flex: 1,
          background: 'var(--color-ivory)',
          overflowY: 'auto',
        }}
      >
        {renderContent()}
      </main>
    </div>
  )
}
