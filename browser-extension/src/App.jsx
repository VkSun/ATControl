import { useState, useEffect, useCallback } from 'react'
import { supabase } from './lib/supabase'
import LoginScreen from './components/LoginScreen'
import ClockCard from './components/ClockCard'
import SearchCard from './components/SearchCard'
import WeatherCard from './components/WeatherCard'
import ShortcutsCard from './components/ShortcutsCard'
import TodoCard from './components/TodoCard'
import CalendarCard from './components/CalendarCard'
import SettingsDrawer from './components/SettingsDrawer'
import { I } from './components/Icons'

const DEFAULT_SETTINGS = { accent: 'blue', greeting: true }

const ACCENTS = {
  blue:   { primary: '#435EBE', primary2: '#5A75D9', soft: '#EDF0FB' },
  violet: { primary: '#7B3FB5', primary2: '#9B5FD5', soft: '#F4E9FB' },
  green:  { primary: '#0E8C68', primary2: '#20C997', soft: '#E6F8F1' },
  orange: { primary: '#E65100', primary2: '#F5A623', soft: '#FFF3E0' },
  rose:   { primary: '#C73548', primary2: '#E74C5E', soft: '#FCE6EA' },
}

function applyAccent(key) {
  const acc = ACCENTS[key]
  if (!acc) return
  document.documentElement.style.setProperty('--primary', acc.primary)
  document.documentElement.style.setProperty('--primary-2', acc.primary2)
  document.documentElement.style.setProperty('--primary-soft', acc.soft)
}

function loadLocalSettings() {
  try {
    const s = JSON.parse(localStorage.getItem('atc_settings'))
    return { ...DEFAULT_SETTINGS, ...s }
  } catch {
    return DEFAULT_SETTINGS
  }
}

export default function App() {
  const [session, setSession] = useState(null)
  const [profile, setProfile] = useState(null)
  const [settings, setSettings] = useState(() => {
    const s = loadLocalSettings()
    applyAccent(s.accent)
    return s
  })
  const [settingsOpen, setSettingsOpen] = useState(false)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    supabase.auth.getSession().then(({ data: { session } }) => {
      setSession(session)
      setLoading(false)
      if (session) loadProfileAndSettings(session.user.id)
    })

    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      setSession(session)
      if (session) loadProfileAndSettings(session.user.id)
      else setProfile(null)
    })

    return () => subscription.unsubscribe()
  }, [])

  async function loadProfileAndSettings(userId) {
    const [profileRes, settingsRes] = await Promise.all([
      supabase.from('user_roles').select('*').eq('user_id', userId).single(),
      supabase.from('newtab_settings').select('*').eq('user_id', userId).single(),
    ])
    if (profileRes.data) setProfile(profileRes.data)
    if (settingsRes.data) {
      const s = {
        accent: settingsRes.data.accent || 'blue',
        greeting: settingsRes.data.greeting ?? true,
      }
      setSettings(s)
      localStorage.setItem('atc_settings', JSON.stringify(s))
      applyAccent(s.accent)
    }
  }

  const handleSettingsChange = useCallback(async (newSettings) => {
    setSettings(newSettings)
    localStorage.setItem('atc_settings', JSON.stringify(newSettings))
    applyAccent(newSettings.accent)
    if (session?.user?.id) {
      await supabase.from('newtab_settings').upsert({
        user_id: session.user.id,
        accent: newSettings.accent,
        greeting: newSettings.greeting,
        updated_at: new Date().toISOString(),
      })
    }
  }, [session])

  if (loading) {
    return (
      <div style={{ minHeight: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center', background: 'var(--bg)' }}>
        <div style={{ fontFamily: 'Nunito', fontWeight: 700, fontSize: 18, color: 'var(--primary)' }}>Загрузка...</div>
      </div>
    )
  }

  if (!session) return <LoginScreen />

  return (
    <div style={{ minHeight: '100vh', padding: '32px 40px 40px', maxWidth: 1480, margin: '0 auto', display: 'flex', flexDirection: 'column', gap: 24 }}>
      <div style={{ display: 'grid', gridTemplateColumns: '240px 1fr 240px', gap: 20, alignItems: 'center' }}>
        <ClockCard />
        <SearchCard greeting={settings.greeting} userName={profile?.full_name} />
        <WeatherCard />
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '1.4fr 1fr 1fr', gap: 20, alignItems: 'start' }}>
        <ShortcutsCard userId={session.user.id} />
        <TodoCard userId={session.user.id} />
        <CalendarCard userId={session.user.id} />
      </div>

      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginTop: 'auto', paddingTop: 12 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <div style={{ width: 28, height: 28, borderRadius: 8, background: 'var(--primary)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            {I.atc({ size: 14, stroke: 2, style: { color: '#fff' } })}
          </div>
          <span style={{ font: '700 12px/1 Nunito', color: 'var(--muted)' }}>ATControl</span>
          {profile?.full_name && <span style={{ font: '500 12px/1 Inter', color: 'var(--muted)' }}>· {profile.full_name}</span>}
        </div>
        <button onClick={() => setSettingsOpen(true)} style={{
          display: 'flex', alignItems: 'center', gap: 6, padding: '7px 14px',
          background: 'var(--surface)', border: '1px solid var(--line)', borderRadius: 99,
          cursor: 'pointer', fontSize: 12, fontWeight: 600, color: 'var(--ink-2)',
        }}>
          {I.gear({ size: 14 })} Настройки
        </button>
      </div>

      <SettingsDrawer open={settingsOpen} onClose={() => setSettingsOpen(false)} settings={settings} onSettingsChange={handleSettingsChange} />
    </div>
  )
}
