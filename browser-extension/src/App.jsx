import { useState, useEffect, useCallback, useRef } from 'react'
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

const DEFAULT_SETTINGS = {
  accent: 'blue',
  greeting: true,
  cols: { shortcuts: 1.4, todo: 1, calendar: 1 },
  rowHeight: null,
}

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
    return {
      ...DEFAULT_SETTINGS,
      ...s,
      cols: { ...DEFAULT_SETTINGS.cols, ...(s?.cols || {}) },
    }
  } catch {
    return DEFAULT_SETTINGS
  }
}

function PanelDragHandle({ onMouseDown, active, resizeMode }) {
  const [hov, setHov] = useState(false)
  return (
    <div
      onMouseDown={resizeMode ? onMouseDown : undefined}
      onMouseEnter={resizeMode ? () => setHov(true) : undefined}
      onMouseLeave={resizeMode ? () => setHov(false) : undefined}
      title={resizeMode ? 'Потянуть для изменения ширины' : undefined}
      style={{
        width: 20, alignSelf: 'stretch',
        cursor: resizeMode ? 'col-resize' : 'default',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        flexShrink: 0, userSelect: 'none', WebkitUserSelect: 'none',
      }}
    >
      <div style={{
        width: 4, height: 40, borderRadius: 2,
        background: (hov || active) ? 'var(--primary)' : 'var(--line-2)',
        opacity: resizeMode ? ((hov || active) ? 1 : 0.5) : 0.1,
        transition: 'background .15s, opacity .15s',
      }} />
    </div>
  )
}

function HeightDragHandle({ onMouseDown, active }) {
  const [hov, setHov] = useState(false)
  return (
    <div
      onMouseDown={onMouseDown}
      onMouseEnter={() => setHov(true)}
      onMouseLeave={() => setHov(false)}
      title="Потянуть для изменения высоты"
      style={{
        height: 20, cursor: 'row-resize',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        userSelect: 'none', WebkitUserSelect: 'none', marginTop: -2,
      }}
    >
      <div style={{
        height: 4, width: 80, borderRadius: 2,
        background: (hov || active) ? 'var(--primary)' : 'var(--line-2)',
        opacity: (hov || active) ? 1 : 0.5,
        transition: 'background .15s, opacity .15s',
      }} />
    </div>
  )
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
  const [resizeMode, setResizeMode] = useState(false)
  const [activeHandle, setActiveHandle] = useState(null)
  const [heightDragActive, setHeightDragActive] = useState(false)

  const settingsRef = useRef(settings)
  const sessionRef = useRef(session)
  const contentRef = useRef(null)
  const dragInfo = useRef(null)
  const heightDragInfo = useRef(null)

  useEffect(() => { settingsRef.current = settings }, [settings])
  useEffect(() => { sessionRef.current = session }, [session])

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
      const local = loadLocalSettings()
      const s = {
        accent: settingsRes.data.accent || 'blue',
        greeting: settingsRes.data.greeting ?? true,
        cols: local.cols,
        rowHeight: local.rowHeight,
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

  const saveToSupabase = useCallback(async (s) => {
    const userId = sessionRef.current?.user?.id
    if (userId) {
      await supabase.from('newtab_settings').upsert({
        user_id: userId,
        accent: s.accent,
        greeting: s.greeting,
        updated_at: new Date().toISOString(),
      })
    }
  }, [])

  // Width drag
  const startDrag = useCallback((handleIdx, e) => {
    if (!resizeMode) return
    e.preventDefault()
    if (!contentRef.current) return
    const panels = [...contentRef.current.querySelectorAll('[data-panel]')]
    const widths = panels.map(p => p.getBoundingClientRect().width)
    const cols = settingsRef.current.cols || { shortcuts: 1.4, todo: 1, calendar: 1 }
    const keys = ['shortcuts', 'todo', 'calendar']
    dragInfo.current = {
      handleIdx,
      startX: e.clientX,
      startWidths: [...widths],
      totalWidth: widths.reduce((a, b) => a + b, 0),
      totalFr: keys.reduce((sum, k) => sum + (cols[k] ?? 1), 0),
    }
    setActiveHandle(handleIdx)
  }, [resizeMode])

  useEffect(() => {
    if (activeHandle === null) return

    const onMove = (e) => {
      if (!dragInfo.current) return
      const { handleIdx, startX, startWidths, totalWidth, totalFr } = dragInfo.current
      const dx = e.clientX - startX
      const keys = ['shortcuts', 'todo', 'calendar']
      const newWidths = [...startWidths]
      const minPx = 140
      const maxDelta = startWidths[handleIdx + 1] - minPx
      const minDelta = -(startWidths[handleIdx] - minPx)
      const delta = Math.max(minDelta, Math.min(dx, maxDelta))
      newWidths[handleIdx] = startWidths[handleIdx] + delta
      newWidths[handleIdx + 1] = startWidths[handleIdx + 1] - delta
      const newCols = {}
      keys.forEach((k, i) => { newCols[k] = (newWidths[i] / totalWidth) * totalFr })
      const next = { ...settingsRef.current, cols: newCols }
      settingsRef.current = next
      setSettings(next)
      localStorage.setItem('atc_settings', JSON.stringify(next))
    }

    const onUp = async () => {
      setActiveHandle(null)
      await saveToSupabase(settingsRef.current)
    }

    window.addEventListener('mousemove', onMove)
    window.addEventListener('mouseup', onUp)
    return () => {
      window.removeEventListener('mousemove', onMove)
      window.removeEventListener('mouseup', onUp)
    }
  }, [activeHandle, saveToSupabase])

  // Height drag
  const startHeightDrag = useCallback((e) => {
    e.preventDefault()
    if (!contentRef.current) return
    heightDragInfo.current = {
      startY: e.clientY,
      startHeight: contentRef.current.getBoundingClientRect().height,
    }
    setHeightDragActive(true)
  }, [])

  useEffect(() => {
    if (!heightDragActive) return

    const onMove = (e) => {
      if (!heightDragInfo.current) return
      const { startY, startHeight } = heightDragInfo.current
      const dy = e.clientY - startY
      const newHeight = Math.max(200, startHeight + dy)
      const next = { ...settingsRef.current, rowHeight: newHeight }
      settingsRef.current = next
      setSettings(next)
      localStorage.setItem('atc_settings', JSON.stringify(next))
    }

    const onUp = async () => {
      setHeightDragActive(false)
      await saveToSupabase(settingsRef.current)
    }

    window.addEventListener('mousemove', onMove)
    window.addEventListener('mouseup', onUp)
    return () => {
      window.removeEventListener('mousemove', onMove)
      window.removeEventListener('mouseup', onUp)
    }
  }, [heightDragActive, saveToSupabase])

  if (loading) {
    return (
      <div style={{ minHeight: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center', background: 'var(--bg)' }}>
        <div style={{ fontFamily: 'Nunito', fontWeight: 700, fontSize: 18, color: 'var(--primary)' }}>Загрузка...</div>
      </div>
    )
  }

  if (!session) return <LoginScreen />

  const rowH = settings.rowHeight
  const panelOverflow = rowH ? 'auto' : undefined

  return (
    <div style={{ minHeight: '100vh', padding: '32px 40px 40px', maxWidth: 1480, margin: '0 auto', display: 'flex', flexDirection: 'column', gap: 24 }}>
      <div style={{ display: 'grid', gridTemplateColumns: '240px 1fr 240px', gap: 20, alignItems: 'center' }}>
        <ClockCard />
        <SearchCard greeting={settings.greeting} userName={profile?.full_name} />
        <WeatherCard />
      </div>

      <div
        ref={contentRef}
        style={{
          display: 'flex',
          alignItems: rowH ? 'stretch' : 'start',
          height: rowH ? rowH : undefined,
          userSelect: (activeHandle !== null || heightDragActive) ? 'none' : undefined,
          overflow: rowH ? 'hidden' : undefined,
        }}
      >
        <div data-panel style={{ flex: `${settings.cols?.shortcuts ?? 1.4} 1 0`, minWidth: 0, overflow: panelOverflow, height: rowH ? '100%' : undefined }}>
          <ShortcutsCard userId={session.user.id} />
        </div>
        <PanelDragHandle onMouseDown={e => startDrag(0, e)} active={activeHandle === 0} resizeMode={resizeMode} />
        <div data-panel style={{ flex: `${settings.cols?.todo ?? 1} 1 0`, minWidth: 0, overflow: panelOverflow, height: rowH ? '100%' : undefined }}>
          <TodoCard userId={session.user.id} />
        </div>
        <PanelDragHandle onMouseDown={e => startDrag(1, e)} active={activeHandle === 1} resizeMode={resizeMode} />
        <div data-panel style={{ flex: `${settings.cols?.calendar ?? 1} 1 0`, minWidth: 0, overflow: panelOverflow, height: rowH ? '100%' : undefined }}>
          <CalendarCard userId={session.user.id} />
        </div>
      </div>

      {resizeMode && (
        <HeightDragHandle onMouseDown={startHeightDrag} active={heightDragActive} />
      )}

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

      <SettingsDrawer
        open={settingsOpen}
        onClose={() => setSettingsOpen(false)}
        settings={settings}
        onSettingsChange={handleSettingsChange}
        onResizeMode={() => { setSettingsOpen(false); setResizeMode(true) }}
      />

      {resizeMode && (
        <div style={{
          position: 'fixed', bottom: 24, left: '50%', transform: 'translateX(-50%)',
          zIndex: 500, background: 'var(--primary)', color: '#fff',
          padding: '10px 20px', borderRadius: 99, fontSize: 13, fontWeight: 600,
          boxShadow: 'var(--shadow-lg)', display: 'flex', alignItems: 'center', gap: 14,
          whiteSpace: 'nowrap',
        }}>
          <span>Потяните разделители (ширина) или нижнюю полоску (высота)</span>
          <button
            onClick={() => setResizeMode(false)}
            style={{
              background: 'rgba(255,255,255,0.2)', border: 'none', color: '#fff',
              padding: '5px 14px', borderRadius: 99, cursor: 'pointer',
              fontSize: 12, fontWeight: 700,
            }}
          >
            Готово
          </button>
        </div>
      )}
    </div>
  )
}
