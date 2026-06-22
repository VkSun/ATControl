import { useState, useEffect } from 'react'
import { supabase } from '../lib/supabase'
import { I } from './Icons'

const DEFAULT_SHORTCUTS = [
  { label: 'Gmail',     url: 'https://mail.google.com', letter: 'G', color: '#EA4335', sort_order: 0, type: 'shortcut' },
  { label: 'YouTube',   url: 'https://youtube.com',     letter: 'Y', color: '#FF0000', sort_order: 1, type: 'shortcut' },
  { label: 'GitHub',    url: 'https://github.com',      letter: 'H', color: '#181717', sort_order: 2, type: 'shortcut' },
  { label: 'Supabase',  url: 'https://supabase.com',    letter: 'S', color: '#3ECF8E', sort_order: 3, type: 'shortcut' },
  { label: 'ATControl', url: 'https://atcontrol.app',   letter: 'A', color: '#435EBE', sort_order: 4, type: 'shortcut' },
  { label: 'Figma',     url: 'https://figma.com',       letter: 'F', color: '#A259FF', sort_order: 5, type: 'shortcut' },
]

const PALETTE = ['#435EBE','#E74C5E','#20C997','#F5A623','#3BAFDA','#A259FF','#181717','#EA4335']

const OVERLAY = {
  position: 'fixed', inset: 0,
  background: 'rgba(37,57,111,.35)', backdropFilter: 'blur(3px)',
  display: 'flex', alignItems: 'center', justifyContent: 'center',
}

function Tile({ item, hovered, onMouseEnter, onMouseLeave, onClick, onDelete, onEdit, badge }) {
  const isFolder = item.type === 'folder'
  return (
    <div
      onMouseEnter={onMouseEnter}
      onMouseLeave={onMouseLeave}
      onClick={(e) => { if (e.target.closest('.del-btn') || e.target.closest('.edit-btn')) return; onClick() }}
      style={{ position: 'relative', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6, cursor: 'pointer' }}
    >
      <div style={{
        width: 44, height: 44, borderRadius: 12, background: item.color,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        fontFamily: 'Nunito', fontWeight: 800, fontSize: 18, color: '#fff',
        boxShadow: '0 2px 8px rgba(0,0,0,.15)', position: 'relative',
      }}>
        {isFolder
          ? I.folder({ size: 22, stroke: 1.8, style: { color: '#fff' } })
          : item.letter}
        {isFolder && badge > 0 && (
          <div style={{
            position: 'absolute', top: -5, right: -5, minWidth: 16, height: 16,
            background: '#fff', color: item.color, borderRadius: 99,
            fontSize: 9, fontWeight: 800, lineHeight: '16px', textAlign: 'center',
            padding: '0 3px', boxShadow: '0 1px 4px rgba(0,0,0,.2)',
          }}>{badge}</div>
        )}
      </div>
      <div style={{ fontSize: 11, fontWeight: 600, color: 'var(--ink-2)', textAlign: 'center', width: '100%', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
        {item.label}
      </div>
      {hovered && (
        <button className="del-btn" onClick={(e) => { e.stopPropagation(); onDelete() }}
          style={{ position: 'absolute', top: -6, right: -2, width: 18, height: 18, borderRadius: 99, background: 'var(--danger)', border: 'none', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#fff' }}>
          {I.close({ size: 10 })}
        </button>
      )}
      {hovered && onEdit && (
        <button className="edit-btn" onClick={(e) => { e.stopPropagation(); onEdit() }}
          style={{ position: 'absolute', top: -6, left: -2, width: 18, height: 18, borderRadius: 99, background: 'var(--primary)', border: 'none', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#fff' }}>
          {I.edit({ size: 10 })}
        </button>
      )}
    </div>
  )
}

function AddForm({ form, setForm, onSubmit, onCancel, showTypeToggle = true }) {
  return (
    <div style={{ marginTop: 16, padding: 14, background: 'var(--surface-2)', borderRadius: 'var(--radius-sm)', border: '1px solid var(--line)' }}>
      {showTypeToggle && (
        <div style={{ display: 'flex', gap: 6, marginBottom: 10 }}>
          {[['shortcut', 'Ссылка'], ['folder', 'Папка']].map(([t, l]) => (
            <button key={t} onClick={() => setForm(f => ({ ...f, type: t }))} style={{
              padding: '4px 12px', borderRadius: 99, cursor: 'pointer', fontSize: 12, fontWeight: 600,
              background: form.type === t ? 'var(--primary)' : 'var(--surface)',
              color: form.type === t ? '#fff' : 'var(--muted)',
              border: form.type === t ? '1px solid transparent' : '1px solid var(--line)',
            }}>{l}</button>
          ))}
        </div>
      )}
      <div style={{ display: 'flex', gap: 8, marginBottom: 8 }}>
        <input value={form.label} onChange={e => setForm(f => ({ ...f, label: e.target.value }))}
          onKeyDown={e => e.key === 'Enter' && onSubmit()}
          placeholder="Название" autoFocus
          style={{ flex: 1, padding: '7px 10px', border: '1px solid var(--line)', borderRadius: 8, fontSize: 13, fontFamily: 'Inter', outline: 'none', background: 'var(--surface)' }} />
        {form.type === 'shortcut' && (
          <input value={form.url} onChange={e => setForm(f => ({ ...f, url: e.target.value }))}
            onKeyDown={e => e.key === 'Enter' && onSubmit()}
            placeholder="URL"
            style={{ flex: 2, padding: '7px 10px', border: '1px solid var(--line)', borderRadius: 8, fontSize: 13, fontFamily: 'Inter', outline: 'none', background: 'var(--surface)' }} />
        )}
      </div>
      <div style={{ display: 'flex', gap: 6, marginBottom: 10 }}>
        {PALETTE.map(c => (
          <div key={c} onClick={() => setForm(f => ({ ...f, color: c }))}
            style={{ width: 22, height: 22, borderRadius: 6, background: c, cursor: 'pointer', border: form.color === c ? '2.5px solid var(--ink)' : '2px solid transparent' }} />
        ))}
      </div>
      <div style={{ display: 'flex', gap: 8 }}>
        <button onClick={onSubmit} style={{ flex: 1, padding: '7px', background: 'var(--primary)', color: '#fff', border: 'none', borderRadius: 8, cursor: 'pointer', fontSize: 13, fontWeight: 600 }}>Добавить</button>
        <button onClick={onCancel} style={{ flex: 1, padding: '7px', background: 'var(--surface)', color: 'var(--muted)', border: '1px solid var(--line)', borderRadius: 8, cursor: 'pointer', fontSize: 13, fontWeight: 600 }}>Отмена</button>
      </div>
    </div>
  )
}

const EMPTY_FORM = { label: '', url: '', color: '#435EBE', type: 'shortcut', letter: '' }

export default function ShortcutsCard({ userId }) {
  const [items, setItems] = useState([])
  const [folderCounts, setFolderCounts] = useState({})
  const [openFolder, setOpenFolder] = useState(null)
  const [folderItems, setFolderItems] = useState([])
  const [adding, setAdding] = useState(false)
  const [addingInFolder, setAddingInFolder] = useState(false)
  const [form, setForm] = useState(EMPTY_FORM)
  const [hovered, setHovered] = useState(null)
  const [confirmDelete, setConfirmDelete] = useState(null)
  const [editingItem, setEditingItem] = useState(null)
  const [editForm, setEditForm] = useState(EMPTY_FORM)

  useEffect(() => { if (userId) loadItems() }, [userId])

  useEffect(() => {
    if (openFolder) loadFolderItems(openFolder.id)
  }, [openFolder?.id])

  async function loadItems() {
    const { data, error } = await supabase
      .from('newtab_shortcuts')
      .select('*')
      .eq('user_id', userId)
      .is('folder_id', null)
      .order('sort_order', { ascending: true })
    if (error) return
    if (data.length === 0) { await seedDefaults(); return }
    setItems(data)
    refreshFolderCounts(data)
  }

  async function refreshFolderCounts(data) {
    const folderIds = data.filter(d => d.type === 'folder').map(d => d.id)
    if (folderIds.length === 0) return
    const { data: rows } = await supabase
      .from('newtab_shortcuts')
      .select('folder_id')
      .in('folder_id', folderIds)
    if (!rows) return
    const counts = {}
    rows.forEach(r => { counts[r.folder_id] = (counts[r.folder_id] || 0) + 1 })
    setFolderCounts(counts)
  }

  async function loadFolderItems(folderId) {
    const { data } = await supabase
      .from('newtab_shortcuts')
      .select('*')
      .eq('folder_id', folderId)
      .order('sort_order', { ascending: true })
    setFolderItems(data || [])
  }

  async function seedDefaults() {
    const rows = DEFAULT_SHORTCUTS.map(s => ({ ...s, user_id: userId }))
    const { data } = await supabase.from('newtab_shortcuts').insert(rows).select()
    if (data) setItems(data)
  }

  const addItem = async (folderId = null) => {
    if (!form.label) return
    if (form.type === 'shortcut' && !form.url) return
    const url = form.type === 'shortcut'
      ? (form.url.startsWith('http') ? form.url : 'https://' + form.url)
      : null
    const list = folderId ? folderItems : items
    const { data, error } = await supabase.from('newtab_shortcuts').insert({
      user_id: userId,
      label: form.label,
      url,
      letter: form.label[0].toUpperCase(),
      color: form.color,
      type: form.type,
      folder_id: folderId || null,
      sort_order: list.length,
    }).select().single()
    if (error || !data) return
    if (folderId) {
      setFolderItems(prev => [...prev, data])
      setFolderCounts(prev => ({ ...prev, [folderId]: (prev[folderId] || 0) + 1 }))
      setAddingInFolder(false)
    } else {
      setItems(prev => [...prev, data])
    }
    setAdding(false)
    setForm(EMPTY_FORM)
  }

  const doDelete = async () => {
    if (!confirmDelete) return
    await supabase.from('newtab_shortcuts').delete().eq('id', confirmDelete.id)
    if (confirmDelete.context === 'folder') {
      setFolderItems(prev => prev.filter(s => s.id !== confirmDelete.id))
      setFolderCounts(prev => ({ ...prev, [openFolder.id]: Math.max(0, (prev[openFolder.id] || 1) - 1) }))
    } else {
      setItems(prev => prev.filter(s => s.id !== confirmDelete.id))
      if (confirmDelete.type === 'folder') {
        setFolderCounts(prev => { const n = { ...prev }; delete n[confirmDelete.id]; return n })
      }
    }
    setConfirmDelete(null)
  }

  const openEdit = (item, context) => {
    setEditingItem({ item, context })
    setEditForm({ label: item.label, url: item.url || '', color: item.color, letter: item.letter, type: item.type })
  }

  const updateItem = async () => {
    if (!editingItem || !editForm.label) return
    const url = editForm.type === 'shortcut'
      ? (editForm.url.startsWith('http') ? editForm.url : 'https://' + editForm.url)
      : null
    const updates = {
      label: editForm.label,
      url,
      color: editForm.color,
      letter: editForm.letter || editForm.label[0].toUpperCase(),
    }
    const { data, error } = await supabase.from('newtab_shortcuts').update(updates).eq('id', editingItem.item.id).select().single()
    if (error || !data) return
    if (editingItem.context === 'folder') {
      setFolderItems(prev => prev.map(s => s.id === data.id ? data : s))
    } else {
      setItems(prev => prev.map(s => s.id === data.id ? data : s))
    }
    setEditingItem(null)
  }

  const closeFolderModal = () => {
    setOpenFolder(null)
    setAddingInFolder(false)
    setForm(EMPTY_FORM)
  }

  return (
    <>
      {/* ── Main card ── */}
      <div className="mz-card">
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
          <div style={{ fontFamily: 'Nunito', fontWeight: 700, fontSize: 15, color: 'var(--ink)' }}>Закладки</div>
          <button onClick={() => { setAdding(v => !v); setForm(EMPTY_FORM) }} style={{
            display: 'flex', alignItems: 'center', gap: 4, padding: '5px 12px',
            background: 'var(--primary-soft)', color: 'var(--primary)', border: 'none',
            borderRadius: 99, cursor: 'pointer', fontSize: 12, fontWeight: 600,
          }}>{I.plus({ size: 14 })} Добавить</button>
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(6, 1fr)', gap: 12 }}>
          {items.map(s => (
            <Tile key={s.id} item={s}
              badge={folderCounts[s.id] || 0}
              hovered={hovered === s.id}
              onMouseEnter={() => setHovered(s.id)}
              onMouseLeave={() => setHovered(null)}
              onClick={() => s.type === 'folder' ? setOpenFolder(s) : (window.location.href = s.url)}
              onDelete={() => setConfirmDelete({ ...s, context: 'top' })}
              onEdit={() => openEdit(s, 'top')}
            />
          ))}
        </div>

        {adding && (
          <AddForm form={form} setForm={setForm}
            onSubmit={() => addItem(null)}
            onCancel={() => { setAdding(false); setForm(EMPTY_FORM) }}
            showTypeToggle={true}
          />
        )}
      </div>

      {/* ── Folder modal ── */}
      {openFolder && (
        <div style={{ ...OVERLAY, zIndex: 200 }} onClick={closeFolderModal}>
          <div onClick={e => e.stopPropagation()} style={{
            background: 'var(--surface)', borderRadius: 'var(--radius)', boxShadow: 'var(--shadow-lg)',
            border: '1px solid var(--line)', padding: 24, width: '90vw', maxWidth: 460,
          }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 20 }}>
              <div style={{ width: 36, height: 36, borderRadius: 10, background: openFolder.color, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                {I.folder({ size: 18, stroke: 1.8, style: { color: '#fff' } })}
              </div>
              <div style={{ fontFamily: 'Nunito', fontWeight: 700, fontSize: 16, color: 'var(--ink)', flex: 1 }}>{openFolder.label}</div>
              <button onClick={() => { setAddingInFolder(v => !v); setForm(EMPTY_FORM) }} style={{
                display: 'flex', alignItems: 'center', gap: 4, padding: '5px 10px',
                background: 'var(--primary-soft)', color: 'var(--primary)', border: 'none',
                borderRadius: 99, cursor: 'pointer', fontSize: 12, fontWeight: 600,
              }}>{I.plus({ size: 12 })} Добавить</button>
              <button onClick={closeFolderModal} style={{ width: 30, height: 30, borderRadius: 99, border: 'none', background: 'var(--surface-2)', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--muted)' }}>
                {I.close({ size: 14 })}
              </button>
            </div>

            {folderItems.length > 0 ? (
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(6, 1fr)', gap: 12, marginBottom: addingInFolder ? 0 : 0 }}>
                {folderItems.map(s => (
                  <Tile key={s.id} item={s}
                    hovered={hovered === s.id}
                    onMouseEnter={() => setHovered(s.id)}
                    onMouseLeave={() => setHovered(null)}
                    onClick={() => window.location.href = s.url}
                    onDelete={() => setConfirmDelete({ ...s, context: 'folder' })}
                    onEdit={() => openEdit(s, 'folder')}
                  />
                ))}
              </div>
            ) : !addingInFolder && (
              <div style={{ textAlign: 'center', padding: '20px 0', color: 'var(--muted)', fontSize: 13 }}>Папка пуста</div>
            )}

            {addingInFolder && (
              <AddForm form={form} setForm={setForm}
                onSubmit={() => addItem(openFolder.id)}
                onCancel={() => { setAddingInFolder(false); setForm(EMPTY_FORM) }}
                showTypeToggle={false}
              />
            )}
          </div>
        </div>
      )}

      {/* ── Delete confirmation ── */}
      {confirmDelete && (
        <div style={{ ...OVERLAY, zIndex: 300 }} onClick={() => setConfirmDelete(null)}>
          <div onClick={e => e.stopPropagation()} style={{
            background: 'var(--surface)', borderRadius: 'var(--radius)', boxShadow: 'var(--shadow-lg)',
            border: '1px solid var(--line)', padding: '28px 24px', maxWidth: 320, width: '90vw', textAlign: 'center',
          }}>
            <div style={{ width: 48, height: 48, borderRadius: 14, background: '#FCE6EA', display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 14px' }}>
              {I.trash({ size: 22, style: { color: 'var(--danger)' } })}
            </div>
            <div style={{ fontFamily: 'Nunito', fontWeight: 700, fontSize: 16, color: 'var(--ink)', marginBottom: 6 }}>
              Удалить {confirmDelete.type === 'folder' ? 'папку' : 'закладку'}?
            </div>
            <div style={{ fontSize: 13, color: 'var(--muted)', marginBottom: confirmDelete.type === 'folder' ? 10 : 20 }}>«{confirmDelete.label}»</div>
            {confirmDelete.type === 'folder' && (
              <div style={{ fontSize: 12, color: 'var(--danger)', marginBottom: 20, background: '#FCE6EA', borderRadius: 8, padding: '8px 12px' }}>
                Все ссылки внутри папки будут удалены
              </div>
            )}
            <div style={{ display: 'flex', gap: 10 }}>
              <button onClick={() => setConfirmDelete(null)} style={{ flex: 1, padding: '9px', background: 'var(--surface-2)', color: 'var(--ink-2)', border: '1px solid var(--line)', borderRadius: 10, cursor: 'pointer', fontSize: 13, fontWeight: 600 }}>Отмена</button>
              <button onClick={doDelete} style={{ flex: 1, padding: '9px', background: 'var(--danger)', color: '#fff', border: 'none', borderRadius: 10, cursor: 'pointer', fontSize: 13, fontWeight: 600 }}>Удалить</button>
            </div>
          </div>
        </div>
      )}

      {/* ── Edit modal ── */}
      {editingItem && (
        <div style={{ ...OVERLAY, zIndex: 250 }} onClick={() => setEditingItem(null)}>
          <div onClick={e => e.stopPropagation()} style={{
            background: 'var(--surface)', borderRadius: 'var(--radius)', boxShadow: 'var(--shadow-lg)',
            border: '1px solid var(--line)', padding: '24px', width: '90vw', maxWidth: 400,
          }}>
            <div style={{ fontFamily: 'Nunito', fontWeight: 700, fontSize: 15, marginBottom: 16, color: 'var(--ink)' }}>
              Редактировать {editingItem.item.type === 'folder' ? 'папку' : 'закладку'}
            </div>
            <div style={{ display: 'flex', gap: 8, marginBottom: 8 }}>
              <input value={editForm.label} onChange={e => setEditForm(f => ({ ...f, label: e.target.value }))}
                placeholder="Название" autoFocus
                style={{ flex: 2, padding: '7px 10px', border: '1px solid var(--line)', borderRadius: 8, fontSize: 13, fontFamily: 'Inter', outline: 'none', background: 'var(--surface)' }} />
              <input value={editForm.letter} onChange={e => setEditForm(f => ({ ...f, letter: e.target.value.slice(-1).toUpperCase() }))}
                placeholder="A"
                style={{ width: 44, padding: '7px', border: '1px solid var(--line)', borderRadius: 8, fontSize: 16, fontWeight: 700, textAlign: 'center', fontFamily: 'Nunito', outline: 'none', background: 'var(--surface)' }} />
            </div>
            {editingItem.item.type === 'shortcut' && (
              <input value={editForm.url} onChange={e => setEditForm(f => ({ ...f, url: e.target.value }))}
                placeholder="URL"
                style={{ width: '100%', padding: '7px 10px', border: '1px solid var(--line)', borderRadius: 8, fontSize: 13, fontFamily: 'Inter', outline: 'none', background: 'var(--surface)', marginBottom: 8, boxSizing: 'border-box' }} />
            )}
            <div style={{ display: 'flex', gap: 6, marginBottom: 16, marginTop: editingItem.item.type === 'shortcut' ? 0 : 8 }}>
              {PALETTE.map(c => (
                <div key={c} onClick={() => setEditForm(f => ({ ...f, color: c }))}
                  style={{ width: 22, height: 22, borderRadius: 6, background: c, cursor: 'pointer', border: editForm.color === c ? '2.5px solid var(--ink)' : '2px solid transparent' }} />
              ))}
            </div>
            <div style={{ display: 'flex', gap: 8 }}>
              <button onClick={updateItem} style={{ flex: 1, padding: '8px', background: 'var(--primary)', color: '#fff', border: 'none', borderRadius: 8, cursor: 'pointer', fontSize: 13, fontWeight: 600 }}>Сохранить</button>
              <button onClick={() => setEditingItem(null)} style={{ flex: 1, padding: '8px', background: 'var(--surface)', color: 'var(--muted)', border: '1px solid var(--line)', borderRadius: 8, cursor: 'pointer', fontSize: 13, fontWeight: 600 }}>Отмена</button>
            </div>
          </div>
        </div>
      )}
    </>
  )
}
