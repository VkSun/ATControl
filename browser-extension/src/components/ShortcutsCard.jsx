import { useState, useEffect } from 'react'
import { supabase } from '../lib/supabase'
import { I } from './Icons'

const DEFAULT_SHORTCUTS = [
  { label: 'Gmail',     url: 'https://mail.google.com', letter: 'G', color: '#EA4335', sort_order: 0 },
  { label: 'YouTube',   url: 'https://youtube.com',     letter: 'Y', color: '#FF0000', sort_order: 1 },
  { label: 'GitHub',    url: 'https://github.com',      letter: 'H', color: '#181717', sort_order: 2 },
  { label: 'Supabase',  url: 'https://supabase.com',    letter: 'S', color: '#3ECF8E', sort_order: 3 },
  { label: 'ATControl', url: 'https://atcontrol.app',   letter: 'A', color: '#435EBE', sort_order: 4 },
  { label: 'Figma',     url: 'https://figma.com',       letter: 'F', color: '#A259FF', sort_order: 5 },
]

const PALETTE = ['#435EBE','#E74C5E','#20C997','#F5A623','#3BAFDA','#A259FF','#181717','#EA4335']

export default function ShortcutsCard({ userId }) {
  const [shortcuts, setShortcuts] = useState([])
  const [adding, setAdding] = useState(false)
  const [form, setForm] = useState({ label: '', url: '', color: '#435EBE' })
  const [hovered, setHovered] = useState(null)

  useEffect(() => {
    if (!userId) return
    loadShortcuts()
  }, [userId])

  async function loadShortcuts() {
    const { data, error } = await supabase
      .from('newtab_shortcuts')
      .select('*')
      .eq('user_id', userId)
      .order('sort_order', { ascending: true })

    if (error) return

    if (data.length === 0) {
      const rows = DEFAULT_SHORTCUTS.map(s => ({ ...s, user_id: userId }))
      const { data: seeded } = await supabase.from('newtab_shortcuts').insert(rows).select()
      if (seeded) setShortcuts(seeded)
    } else {
      setShortcuts(data)
    }
  }

  const addShortcut = async () => {
    if (!form.label || !form.url) return
    const url = form.url.startsWith('http') ? form.url : 'https://' + form.url
    const letter = form.label[0].toUpperCase()
    const { data, error } = await supabase.from('newtab_shortcuts').insert({
      user_id: userId,
      label: form.label,
      url,
      letter,
      color: form.color,
      sort_order: shortcuts.length,
    }).select().single()
    if (!error && data) {
      setShortcuts(prev => [...prev, data])
      setForm({ label: '', url: '', color: '#435EBE' })
      setAdding(false)
    }
  }

  const removeShortcut = async (id) => {
    await supabase.from('newtab_shortcuts').delete().eq('id', id)
    setShortcuts(prev => prev.filter(s => s.id !== id))
  }

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
