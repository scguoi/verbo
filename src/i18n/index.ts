import i18n from 'i18next'
import { initReactI18next } from 'react-i18next'
import { zhCN } from './zh-CN'
import { en } from './en'

export function initI18n(language: 'system' | 'zh-CN' | 'en') {
  const lng =
    language === 'system'
      ? navigator.language.startsWith('zh')
        ? 'zh-CN'
        : 'en'
      : language

  return i18n.use(initReactI18next).init({
    resources: {
      'zh-CN': { translation: zhCN },
      en: { translation: en },
    },
    lng,
    fallbackLng: 'en',
    interpolation: { escapeValue: false },
  })
}
