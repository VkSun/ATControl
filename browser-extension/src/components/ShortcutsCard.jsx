import { useState } from 'react'
import { I } from './Icons'

const DEFAULT_SHORTCUTS = [
  { id: 1, label: 'Gmail',      url: 'https://mail.google.com',    letter: 'G', color: '#EA4335' },
  { id: 2, label: 'YouTube',    url: 'https://youtube.com',        letter: 'Y', color: '#FF0000' },
  { id: 3, label: 'GitHub',     url: 'https://github.com',         letter: 'H', color: '#181717' },
  { id: 4, label: 'Supabase',   url: 'https://supabase.com',       letter: 'S', color: '#3ECF8E' },
  { id: 5, label: 'ATControl',  url: 'https://atcontrol.app',      letter: 'A', color: '#435EBE' },
  { id: 6, label: 'Figma',      url: 'https://figma.com',          letter: 'F', color: '#A259FF' },
]

const PALETTE = ['#435EBE','#E74C5E','#20C997','#F5A623','#3BAFDA','#A259FF','#181717','#EA4335']

function load() {
  try { return JSON.parse(localStorage.getItem('atc_shortcuts')) || DEFAULT_SHORTCUTS } catch { return DEFAULT_SHORTCUTS }
}

export default function ShortcutsCard() {
  const [shortcuts, setShortcuts] = useState(load)
  const [adding, setAdding] = useState(false)
  const [form, setForm] = useState({ label: '', url: '', color: '#435EBE' })
  const [hovered, setHovered] = useState(null)

  const save = (arr) => { setShortcuts(arr); localStorage.setItem('atc_shortcuts', JSON.stringify(arr)) }

  const addShortcut = () => {
    if (!form.label || !form.url) return
    const url = form.url.startsWith('http') ? form.url : 'https://' + form.url
    const letter = form.label[0].toUpperCase()
    const newS = { id: Date.now(), label: form.label, url, letter, color: form.color }
    save([...shortcuts, newS])
    setForm({ label: '', url: '', color: '#435EBE' })
    setAdding(false)
  }

  const removeShortcut = (id) => save(shortcuts.filter(s => s.id !== id))

  return (
    <div className="mz-card">
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
        <div style={{ fontFamily: 'Nunito', fontWeight: 700, fontSize: 15, color: 'var(--ink)' }}>Закладки</div>
        <button onClick={() => setAdding(!adding)} style={{
          display: 'flex', alignItems: 'center', gap: 4, padding: '5px 12px',
          background: 'var(--primary-soft)', color: 'var(--primary)', border: 'none',
          borderRadius: 99, cursor: 'pointer', fontSize: 12, fontWeight: 600,
        }}>{I.plus({ size: 14 })} Добавить</button>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(6, 1fr)', gap: 12 }}>
        {shortcuts.map(s => (
          <div key={s.id} onMouseEnter={() => setHovered(s.id)} onMouseLeave={() => setHovered(null)}
            style={{ position: 'relative', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6, cursor: 'pointer' }}
            onClick={(e) => { if (e.target.closest('.del-btn')) return; window.location.href = s.url }}>
            <div style={{
              width: 44, height: 44, borderRadius: 12, background: s.color,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              fontFamily: 'Nunito', fontWeight: 800, fontSize: 18, color: '#fff',
              boxShadow: '0 2px 8px rgba(0,0,0,.15)',
            }}>{s.letter}</div>
            <div style={{ fontSize: 11, fontWeight: 600, color: 'var(--ink-2)', textAlign: 'center', width: '100%', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{s.label}</div>
            {hovered === s.id && (
              <button className="del-btn" onClick={(e) => { e.stopPropagation(); removeShortcut(s.id) }}
                style={{ position: 'absolute', top: -6, right: -2, width: 18, height: 18, borderRadius: 99, background: 'var(--danger)', border: 'none', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#fff' }}>
                {I.close({ size: 10 })}
              </button>
            )}
          </div>
        ))}
      </div>

      {adding && (
        <div style={{ marginTop: 16, padding: 14, background: 'var(--surface-2)', borderRadius: 'var(--radius-sm)', border: '1px solid var(--line)' }}>
          <div style={{ display: 'flex', gap: 8, marginBottom: 8 }}>
            <input value={form.label} onChange={e => setForm(f => ({ ...f, label: e.target.value }))} placeholder="Название"
              style={{ flex: 1, padding: '7px 10px', border: '1px solid var(--line)', borderRadius: 8, fontSize: 13, fontFamily: 'Inter', outline: 'none', background: 'var(--surface)' }} />
            <input value={form.url} onChange={e => setForm(f => ({ ...f, url: e.target.value }))} placeholder="URL"
              style={{ flex: 2, padding: '7px 10px', border: '1px solid var(--line)', borderRadius: 8, fontSize: 13, fontFamily: 'Inter', outline: 'none', background: 'var(--surface)' }} />
          </div>
          <div style={{ display: 'flex', gap: 6, marginBottom: 10 }}>
            {PALETTE.map(c => (
              <div key={c} onClick={() => setForm(f => ({ ...f, color: c }))}
                style={{ width: 22, height: 22, borderRadius: 6, background: c, cursor: 'pointer', border: form.color === c ? '2.5px solid var(--ink)' : '2px solid transparent' }} />
            ))}
          </div>
          <div style={{ display: 'flex', gap: 8 }}>
            <button onClick={addShortcut} style={{ flex: 1, padding: '7px', background: 'var(--primary)', color: '#fff', border: 'none', borderRadius: 8, cursor: 'pointer', fontSize: 13, fontWeight: 600 }}>Добавить</button>
            <button onClick={() => setAdding(false)} style={{ flex: 1, padding: '7px', background: 'var(--surface)', color: 'var(--muted)', border: '1px solid var(--line)', borderRadius: 8, cursor: 'pointer', fontSize: 13, fontWeight: 600 }}>Отмена</button>
          </div>
        </div>
      )}
    </div>
  )
}
