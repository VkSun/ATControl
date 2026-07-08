import { useState, useEffect } from 'react'
import { supabase } from '../lib/supabase'
import { I } from './Icons'

const TAG_COLORS = {
  work:   { bg: '#EDF0FB', fg: '#435EBE', label: 'Работа' },
  home:   { bg: '#FEF3E7', fg: '#C77D1A', label: 'Дом' },
  health: { bg: '#E6F8F1', fg: '#0E8C68', label: 'Здоровье' },
  study:  { bg: '#F4E9FB', fg: '#7B3FB5', label: 'Учёба' },
  urgent: { bg: '#FCE6EA', fg: '#C73548', label: 'Срочно' },
  expiry: { bg: '#FFF3E0', fg: '#E65100', label: 'Истечение' },
  none:   { bg: '#F1F3F8', fg: '#5C6BAC', label: 'Без тега' },
}

const FILTERS = [
  { key: 'all',    label: 'Все' },
  { key: 'active', label: 'Активные' },
  { key: 'done',   label: 'Готовые' },
]

function formatDueDate(dateStr) {
  if (!dateStr) return ''
  const today = new Date(); today.setHours(0, 0, 0, 0)
  const d = new Date(dateStr + 'T00:00:00')
  const diff = Math.round((d - today) / 86400000)
  if (diff === 0) return 'сегодня'
  if (diff === 1) return 'завтра'
  if (diff === -1) return 'вчера'
  if (diff < 0) return `${Math.abs(diff)}д назад`
  return d.toLocaleDateString('ru-RU', { day: 'numeric', month: 'short' })
}

function taskToDisplay(t) {
  return {
    id: t.id,
    text: t.title,
    done: t.is_completed,
    tag: t.type === 'expiry' ? 'expiry' : (t.priority === 'high' ? 'urgent' : 'work'),
    due: t.due_date ? formatDueDate(t.due_date) : '',
    type: t.type,
  }
}

export default function TodoCard({ userId }) {
  const [tasks, setTasks] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [filter, setFilter] = useState('active')
  const [newText, setNewText] = useState('')
  const [newTag, setNewTag] = useState('work')
  const [showAdd, setShowAdd] = useState(false)

  useEffect(() => {
    if (!userId) return
    fetchTasks()
  }, [userId])

  async function fetchTasks() {
    setLoading(true)
    setError('')
    try {
      // Общая с Flutter-приложением видимость задач живёт в БД (см. README)
      const { data, error: err } = await supabase.rpc('get_my_tasks')
      if (err) throw err
      setTasks((data || []).map(taskToDisplay))
    } catch (e) {
      setError('Ошибка загрузки задач: ' + e.message)
    } finally {
      setLoading(false)
    }
  }

  async function addTask() {
    if (!newText.trim()) return
    const today = new Date().toISOString().split('T')[0]
    const { data, error: err } = await supabase.from('tasks').insert({
      title: newText.trim(),
      due_date: today,
      is_completed: false,
      priority: newTag === 'urgent' ? 'high' : 'normal',
      type: 'manual',
      user_id: userId,
    }).select().single()
    if (!err && data) {
      setTasks(prev => [taskToDisplay(data), ...prev])
      setNewText('')
      setShowAdd(false)
    }
  }

  async function toggleTask(id, done) {
    await supabase.from('tasks').update({ is_completed: !done }).eq('id', id)
    setTasks(prev => prev.map(t => t.id === id ? { ...t, done: !t.done } : t))
  }

  async function deleteTask(id, type) {
    if (type === 'expiry') return
    await supabase.from('tasks').delete().eq('id', id)
    setTasks(prev => prev.filter(t => t.id !== id))
  }

  const filtered = tasks.filter(t => {
    if (filter === 'active') return !t.done
    if (filter === 'done') return t.done
    return true
  })

  const activeCount = tasks.filter(t => !t.done && t.type !== 'expiry').length

  const todayStr = new Date().toLocaleDateString('ru-RU', { day: 'numeric', month: 'long' })
  const dayStr = ['воскресенье','понедельник','вторник','среда','четверг','пятница','суббота'][new Date().getDay()]

  return (
    <div className="mz-card" style={{ display: 'flex', flexDirection: 'column', gap: 0 }}>
      {/* Header */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 14 }}>
        <div>
          <div style={{ fontFamily: 'Nunito', fontWeight: 700, fontSize: 15, color: 'var(--ink)' }}>Задачи</div>
          <div style={{ fontSize: 11, color: 'var(--muted)', marginTop: 2 }}>{todayStr}, {dayStr}</div>
        </div>
        <div style={{ display: 'flex', gap: 6, alignItems: 'center' }}>
          {activeCount > 0 && (
            <span style={{ background: 'var(--primary)', color: '#fff', borderRadius: 99, fontSize: 11, fontWeight: 700, padding: '2px 8px' }}>{activeCount}</span>
          )}
          <button onClick={() => setShowAdd(!showAdd)} style={{
            width: 28, height: 28, borderRadius: 99, border: 'none', cursor: 'pointer',
            background: 'var(--primary-soft)', color: 'var(--primary)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>{I.plus({ size: 16 })}</button>
          <button onClick={fetchTasks} title="Обновить" style={{
            width: 28, height: 28, borderRadius: 99, border: 'none', cursor: 'pointer',
            background: 'var(--surface-2)', color: 'var(--muted)',
            display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 14,
          }}>↻</button>
        </div>
      </div>

      {/* Add form */}
      {showAdd && (
        <div style={{ marginBottom: 14, padding: 12, background: 'var(--surface-2)', borderRadius: 'var(--radius-sm)', border: '1px solid var(--line)' }}>
          <input value={newText} onChange={e => setNewText(e.target.value)}
            onKeyDown={e => e.key === 'Enter' && addTask()}
            placeholder="Название задачи..." autoFocus
            style={{ width: '100%', padding: '7px 10px', border: '1px solid var(--line)', borderRadius: 8, fontSize: 13, fontFamily: 'Inter', outline: 'none', background: 'var(--surface)', marginBottom: 8 }} />
          <div style={{ display: 'flex', gap: 6, marginBottom: 8, flexWrap: 'wrap' }}>
            {['work','urgent','none'].map(t => (
              <button key={t} onClick={() => setNewTag(t)} style={{
                padding: '3px 10px', borderRadius: 99, border: 'none', cursor: 'pointer', fontSize: 11, fontWeight: 600,
                background: newTag === t ? TAG_COLORS[t].fg : TAG_COLORS[t].bg,
                color: newTag === t ? '#fff' : TAG_COLORS[t].fg,
              }}>{TAG_COLORS[t].label}</button>
            ))}
          </div>
          <div style={{ display: 'flex', gap: 8 }}>
            <button onClick={addTask} style={{ flex: 1, padding: '7px', background: 'var(--primary)', color: '#fff', border: 'none', borderRadius: 8, cursor: 'pointer', fontSize: 13, fontWeight: 600 }}>Добавить</button>
            <button onClick={() => { setShowAdd(false); setNewText('') }} style={{ flex: 1, padding: '7px', background: 'var(--surface)', color: 'var(--muted)', border: '1px solid var(--line)', borderRadius: 8, cursor: 'pointer', fontSize: 13, fontWeight: 600 }}>Отмена</button>
          </div>
        </div>
      )}

      {/* Filters */}
      <div style={{ display: 'flex', gap: 4, marginBottom: 12 }}>
        {FILTERS.map(f => (
          <button key={f.key} onClick={() => setFilter(f.key)} style={{
            padding: '4px 12px', borderRadius: 99, border: 'none', cursor: 'pointer', fontSize: 12, fontWeight: 600,
            background: filter === f.key ? 'var(--primary)' : 'var(--surface-2)',
            color: filter === f.key ? '#fff' : 'var(--muted)',
            transition: 'all .15s',
          }}>{f.label}</button>
        ))}
      </div>

      {/* Task list */}
      <div style={{ display: 'flex', flexDirection: 'column', gap: 8, maxHeight: 320, overflowY: 'auto' }}>
        {loading && (
          <div style={{ textAlign: 'center', padding: '24px 0', color: 'var(--muted)', fontSize: 13 }}>
            Загрузка...
          </div>
        )}
        {error && (
          <div style={{ color: 'var(--danger)', fontSize: 12, padding: '8px 12px', background: '#FCE6EA', borderRadius: 8 }}>{error}</div>
        )}
        {!loading && !error && filtered.length === 0 && (
          <div style={{ textAlign: 'center', padding: '24px 0', color: 'var(--muted)', fontSize: 13 }}>
            {filter === 'done' ? 'Нет выполненных задач' : filter === 'active' ? 'Все задачи выполнены!' : 'Нет задач'}
          </div>
        )}
        {!loading && filtered.map(task => {
          const tc = TAG_COLORS[task.tag] || TAG_COLORS.none
          return (
            <div key={task.id} style={{
              display: 'flex', alignItems: 'flex-start', gap: 10, padding: '10px 12px',
              background: task.done ? 'var(--surface-2)' : 'var(--surface)',
              borderRadius: 'var(--radius-sm)', border: '1px solid var(--line)',
              transition: 'all .15s', opacity: task.done ? 0.65 : 1,
            }}>
              <button onClick={() => toggleTask(task.id, task.done)} style={{
                flexShrink: 0, width: 20, height: 20, borderRadius: 6, marginTop: 1,
                border: `2px solid ${task.done ? 'var(--success)' : 'var(--line-2)'}`,
                background: task.done ? 'var(--success)' : 'transparent',
                cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center',
                color: '#fff',
              }}>
                {task.done && I.check({ size: 12, stroke: 2.5 })}
              </button>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: 13, fontWeight: 600, color: task.done ? 'var(--muted)' : 'var(--ink-2)', textDecoration: task.done ? 'line-through' : 'none', wordBreak: 'break-word' }}>
                  {task.text}
                </div>
                <div style={{ display: 'flex', gap: 6, marginTop: 5, alignItems: 'center', flexWrap: 'wrap' }}>
                  <span style={{ fontSize: 10, fontWeight: 700, padding: '2px 7px', borderRadius: 99, background: tc.bg, color: tc.fg }}>{tc.label}</span>
                  {task.due && (
                    <span style={{ fontSize: 11, color: 'var(--muted)', fontWeight: 500 }}>{task.due}</span>
                  )}
                </div>
              </div>
              {task.type !== 'expiry' && (
                <button onClick={() => deleteTask(task.id, task.type)} style={{
                  flexShrink: 0, width: 24, height: 24, borderRadius: 6, border: 'none', cursor: 'pointer',
                  background: 'transparent', color: 'var(--muted)', display: 'flex', alignItems: 'center', justifyContent: 'center',
                  transition: 'all .15s',
                }} onMouseEnter={e => e.currentTarget.style.color = 'var(--danger)'} onMouseLeave={e => e.currentTarget.style.color = 'var(--muted)'}>
                  {I.trash({ size: 14 })}
                </button>
              )}
            </div>
          )
        })}
      </div>
    </div>
  )
}
