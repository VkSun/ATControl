import { useState, useEffect } from 'react'
import { supabase } from '../lib/supabase'
import { I } from './Icons'

const MONTHS_RU = ['Январь','Февраль','Март','Апрель','Май','Июнь','Июль','Август','Сентябрь','Октябрь','Ноябрь','Декабрь']
const DAYS_RU = ['Пн','Вт','Ср','Чт','Пт','Сб','Вс']

function parseLocalDate(dateStr) {
  return new Date(dateStr + 'T00:00:00')
}

export default function CalendarCard({ userId }) {
  const today = new Date()
  const [cur, setCur] = useState(new Date(today.getFullYear(), today.getMonth(), 1))
  const [tasks, setTasks] = useState([])
  const [selectedDay, setSelectedDay] = useState(null)

  const year = cur.getFullYear()
  const month = cur.getMonth()

  useEffect(() => {
    if (!userId) return
    const from = new Date(year, month, 1).toISOString().split('T')[0]
    const to = new Date(year, month + 1, 0).toISOString().split('T')[0]
    supabase
      .from('tasks')
      .select('id, title, due_date, is_completed, type, priority')
      .or(`type.eq.expiry,user_id.eq.${userId}`)
      .not('due_date', 'is', null)
      .gte('due_date', from)
      .lte('due_date', to)
      .order('due_date', { ascending: true })
      .then(({ data }) => setTasks(data || []))
  }, [userId, year, month])

  const prevMonth = () => {
    setCur(new Date(cur.getFullYear(), cur.getMonth() - 1, 1))
    setSelectedDay(null)
  }
  const nextMonth = () => {
    setCur(new Date(cur.getFullYear(), cur.getMonth() + 1, 1))
    setSelectedDay(null)
  }

  const firstDay = (new Date(year, month, 1).getDay() + 6) % 7
  const daysInMonth = new Date(year, month + 1, 0).getDate()

  const cells = []
  for (let i = 0; i < firstDay; i++) cells.push(null)
  for (let d = 1; d <= daysInMonth; d++) cells.push(d)

  const isToday = (d) => d && today.getDate() === d && today.getMonth() === month && today.getFullYear() === year

  const tasksByDay = {}
  tasks.forEach(t => {
    const d = parseLocalDate(t.due_date)
    if (d.getMonth() === month && d.getFullYear() === year) {
      const day = d.getDate()
      if (!tasksByDay[day]) tasksByDay[day] = []
      tasksByDay[day].push(t)
    }
  })

  const displayTasks = selectedDay
    ? (tasksByDay[selectedDay] || [])
    : tasks.filter(t => !t.is_completed).slice(0, 4)

  const sectionLabel = selectedDay
    ? `${selectedDay} ${MONTHS_RU[month].toLowerCase()}`
    : 'Ближайшие задачи'

  return (
    <div className="mz-card">
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 14 }}>
        <div style={{ fontFamily: 'Nunito', fontWeight: 700, fontSize: 15, color: 'var(--ink)' }}>
          {MONTHS_RU[month]} {year}
        </div>
        <div style={{ display: 'flex', gap: 4 }}>
          <button onClick={prevMonth} style={{ width: 26, height: 26, borderRadius: 8, border: 'none', background: 'var(--surface-2)', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--muted)' }}>{I.chevL({ size: 14 })}</button>
          <button onClick={nextMonth} style={{ width: 26, height: 26, borderRadius: 8, border: 'none', background: 'var(--surface-2)', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--muted)' }}>{I.chevR({ size: 14 })}</button>
        </div>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)', gap: 2, marginBottom: 4 }}>
        {DAYS_RU.map(d => (
          <div key={d} style={{ textAlign: 'center', fontSize: 11, fontWeight: 700, color: 'var(--muted)', padding: '4px 0' }}>{d}</div>
        ))}
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)', gap: 2 }}>
        {cells.map((d, i) => {
          const dayTasks = d ? (tasksByDay[d] || []) : []
          const hasActive = dayTasks.some(t => !t.is_completed)
          const hasDone = dayTasks.length > 0 && !hasActive
          const isSelected = d === selectedDay
          return (
            <div key={i}
              onClick={() => d && setSelectedDay(d === selectedDay ? null : d)}
              style={{
                textAlign: 'center', paddingTop: 5, paddingBottom: 3, borderRadius: 8, fontSize: 12,
                fontWeight: isToday(d) ? 700 : 500,
                background: isToday(d) ? 'var(--primary)' : isSelected ? 'var(--primary-soft)' : 'transparent',
                color: isToday(d) ? '#fff' : d ? 'var(--ink-2)' : 'transparent',
                cursor: d ? 'pointer' : 'default',
              }}>
              {d || ''}
              {d > 0 && dayTasks.length > 0 && (
                <div style={{
                  width: 4, height: 4, borderRadius: 99, margin: '2px auto 0',
                  background: isToday(d) ? 'rgba(255,255,255,.8)' : hasActive ? 'var(--primary)' : 'var(--success)',
                }} />
              )}
            </div>
          )
        })}
      </div>

      {displayTasks.length > 0 && (
        <div style={{ marginTop: 14 }}>
          <div style={{ fontSize: 11, fontWeight: 700, color: 'var(--muted)', textTransform: 'uppercase', letterSpacing: 0.5, marginBottom: 8 }}>
            {sectionLabel}
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
            {displayTasks.map(t => {
              const isExpiry = t.type === 'expiry'
              const isHigh = t.priority === 'high'
              const dotColor = isExpiry ? 'var(--warning)' : isHigh ? 'var(--danger)' : 'var(--primary)'
              return (
                <div key={t.id} style={{
                  display: 'flex', alignItems: 'center', gap: 8, padding: '7px 10px',
                  background: 'var(--surface-2)', borderRadius: 8, border: '1px solid var(--line)',
                  opacity: t.is_completed ? 0.55 : 1,
                }}>
                  <div style={{ width: 3, height: 24, borderRadius: 99, background: dotColor, flexShrink: 0 }} />
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ fontSize: 12, fontWeight: 600, color: 'var(--ink-2)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', textDecoration: t.is_completed ? 'line-through' : 'none' }}>
                      {t.title}
                    </div>
                  </div>
                  {t.due_date && (
                    <div style={{ fontSize: 11, color: 'var(--muted)', flexShrink: 0 }}>
                      {parseLocalDate(t.due_date).toLocaleDateString('ru-RU', { day: 'numeric', month: 'short' })}
                    </div>
                  )}
                </div>
              )
            })}
          </div>
        </div>
      )}

      {displayTasks.length === 0 && selectedDay && (
        <div style={{ marginTop: 14, textAlign: 'center', fontSize: 12, color: 'var(--muted)', padding: '8px 0' }}>
          Нет задач на {selectedDay} {MONTHS_RU[month].toLowerCase()}
        </div>
      )}
    </div>
  )
}
