import { useState, useEffect } from 'react'
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

const DEFAULT_SETTINGS = { accent: 'blue', greeting: true, userName: '' }

function loadSettings() {
  try { return { ...DEFAULT_SETTINGS, ...JSON.parse(localStorage.getItem('atc_settings')) } } catch { return DEFAULT_SETTINGS }
}

export default function App() {
  const [session, setSession] = useState(null)
  const [profile, setProfile] = useState(null)
  const [settings, setSettings] = useState(loadSettings)
  const [settingsOpen, setSettingsOpen] = useState(false)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    supabase.auth.getSession().then(({ data: { session } }) => {
      setSession(session)
      setLoading(false)
      if (session) loadProfile(session.user.id)
    })

    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      setSession(session)
      if (session) loadProfile(session.user.id)
      else setProfile(null)
    })

    return () => subscription.unsubscribe()
  }, [])

  async function loadProfile(userId) {
    const { data } = await supabase.from('user_roles').select('*').eq('user_id', userId).single()
    if (data) setProfile(data)
  }

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
      {/* Top row */}
      <div style={{ display: 'grid', gridTemplateColumns: '240px 1fr 240px', gap: 20, alignItems: 'center' }}>
        <ClockCard />
        <SearchCard greeting={settings.greeting} userName={profile?.full_name || settings.userName} />
        <WeatherCard />
      </div>

      {/* Main row */}
      <div style={{ display: 'grid', gridTemplateColumns: '1.4fr 1fr 1fr', gap: 20, alignItems: 'start' }}>
        <ShortcutsCard />
        <TodoCard userId={session.user.id} />
        <CalendarCard />
      </div>

      {/* Footer */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginTop: 'auto', paddingTop: 12 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <div style={{ width: 28, height: 28, borderRadius: 8, background: 'var(--primary)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            {I.atc({ size: 14, stroke: 2, style: { color: '#fff' } })}
          </div>
          <span style={{ font: '700 12px/1 Nunito', color: 'var(--muted)' }}>ATControl</span>
          {profile?.full_name && <span style={{ font: '500 12px/1 Inter', color: 'var(--muted)' }}>· {profile.full_name}</span>}
        </div>
        <div style={{ display: 'flex', gap: 8 }}>
          <button onClick={() => setSettingsOpen(true)} style={{
            display: 'flex', alignItems: 'center', gap: 6, padding: '7px 14px',
            background: 'var(--surface)', border: '1px solid var(--line)', borderRadius: 99,
            cursor: 'pointer', fontSize: 12, fontWeight: 600, color: 'var(--ink-2)',
          }}>
            {I.gear({ size: 14 })} Настройки
          </button>
        </div>
      </div>

      <SettingsDrawer open={settingsOpen} onClose={() => setSettingsOpen(false)} settings={settings} onSettingsChange={setSettings} />
    </div>
  )
}
