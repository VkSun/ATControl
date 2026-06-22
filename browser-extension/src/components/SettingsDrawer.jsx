import { I } from './Icons'
import { supabase } from '../lib/supabase'

const ACCENTS = [
  { key: 'blue',   primary: '#435EBE', primary2: '#5A75D9', soft: '#EDF0FB' },
  { key: 'violet', primary: '#7B3FB5', primary2: '#9B5FD5', soft: '#F4E9FB' },
  { key: 'green',  primary: '#0E8C68', primary2: '#20C997', soft: '#E6F8F1' },
  { key: 'orange', primary: '#E65100', primary2: '#F5A623', soft: '#FFF3E0' },
  { key: 'rose',   primary: '#C73548', primary2: '#E74C5E', soft: '#FCE6EA' },
]

export default function SettingsDrawer({ open, onClose, settings, onSettingsChange }) {
  const update = (key, val) => {
    const next = { ...settings, [key]: val }
    if (key === 'accent') {
      const acc = ACCENTS.find(a => a.key === val)
      if (acc) {
        document.documentElement.style.setProperty('--primary', acc.primary)
        document.documentElement.style.setProperty('--primary-2', acc.primary2)
        document.documentElement.style.setProperty('--primary-soft', acc.soft)
      }
    }
    onSettingsChange(next)
  }

  const handleLogout = async () => {
    await supabase.auth.signOut()
    onClose()
  }

  return (
    <>
      {open && <div onClick={onClose} style={{ position: 'fixed', inset: 0, background: 'rgba(37,57,111,.25)', backdropFilter: 'blur(2px)', zIndex: 99 }} />}
      <div style={{
        position: 'fixed', top: 0, right: 0, bottom: 0, width: 320,
        background: 'var(--surface)', boxShadow: 'var(--shadow-lg)', zIndex: 100,
        padding: '24px 20px', display: 'flex', flexDirection: 'column', gap: 20,
        transform: open ? 'translateX(0)' : 'translateX(100%)',
        transition: 'transform .25s cubic-bezier(.4,0,.2,1)',
        overflowY: 'auto',
      }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <div style={{ fontFamily: 'Nunito', fontWeight: 800, fontSize: 18, color: 'var(--ink)' }}>Настройки</div>
          <button onClick={onClose} style={{ width: 32, height: 32, borderRadius: 99, border: 'none', background: 'var(--surface-2)', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--muted)' }}>{I.close({ size: 16 })}</button>
        </div>

        <div>
          <div style={{ fontSize: 12, fontWeight: 700, color: 'var(--muted)', marginBottom: 10, textTransform: 'uppercase', letterSpacing: 0.5 }}>Цвет акцента</div>
          <div style={{ display: 'flex', gap: 10 }}>
            {ACCENTS.map(a => (
              <div key={a.key} onClick={() => update('accent', a.key)} style={{
                width: 32, height: 32, borderRadius: 10, background: a.primary, cursor: 'pointer',
                border: settings.accent === a.key ? '3px solid var(--ink)' : '3px solid transparent',
                boxShadow: '0 2px 8px rgba(0,0,0,.15)',
              }} />
            ))}
          </div>
        </div>

        <div>
          <div style={{ fontSize: 12, fontWeight: 700, color: 'var(--muted)', marginBottom: 10, textTransform: 'uppercase', letterSpacing: 0.5 }}>Поиск</div>
          <label style={{ display: 'flex', alignItems: 'center', gap: 10, cursor: 'pointer' }}>
            <div style={{
              width: 40, height: 22, borderRadius: 99, background: settings.greeting ? 'var(--primary)' : 'var(--line-2)',
              position: 'relative', transition: 'background .15s',
            }} onClick={() => update('greeting', !settings.greeting)}>
              <div style={{
                position: 'absolute', top: 3, left: settings.greeting ? 20 : 3,
                width: 16, height: 16, borderRadius: 99, background: '#fff',
                transition: 'left .15s', boxShadow: '0 1px 4px rgba(0,0,0,.2)',
              }} />
            </div>
            <span style={{ fontSize: 13, fontWeight: 600, color: 'var(--ink-2)' }}>Показывать приветствие</span>
          </label>
        </div>

        <div>
          <div style={{ fontSize: 12, fontWeight: 700, color: 'var(--muted)', marginBottom: 12, textTransform: 'uppercase', letterSpacing: 0.5 }}>Ширина карточек</div>
          {[['shortcuts', 'Закладки'], ['todo', 'Задачи'], ['calendar', 'Календарь']].map(([key, label]) => (
            <div key={key} style={{ marginBottom: 10 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 4 }}>
                <span style={{ fontSize: 12, fontWeight: 600, color: 'var(--ink-2)' }}>{label}</span>
                <span style={{ fontSize: 12, color: 'var(--muted)' }}>{((settings.cols?.[key]) ?? 1).toFixed(1)}</span>
              </div>
              <input type="range" min="0.5" max="3" step="0.1"
                value={(settings.cols?.[key]) ?? 1}
                onChange={e => update('cols', { ...(settings.cols || { shortcuts: 1.4, todo: 1, calendar: 1 }), [key]: parseFloat(e.target.value) })}
                style={{ width: '100%', accentColor: 'var(--primary)', cursor: 'pointer' }}
              />
            </div>
          ))}
        </div>

        <div style={{ marginTop: 'auto' }}>
          <button onClick={handleLogout} style={{
            width: '100%', padding: '11px', background: 'transparent', border: '1.5px solid var(--danger)',
            color: 'var(--danger)', borderRadius: 10, cursor: 'pointer', fontSize: 14, fontWeight: 600,
            display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
          }}>
            {I.logout({ size: 16 })} Выйти из аккаунта
          </button>
        </div>
      </div>
    </>
  )
}
