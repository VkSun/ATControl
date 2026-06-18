import { useState } from 'react'
import { I } from './Icons'

const MONTHS_RU = ['Январь','Февраль','Март','Апрель','Май','Июнь','Июль','Август','Сентябрь','Октябрь','Ноябрь','Декабрь']
const DAYS_RU = ['Пн','Вт','Ср','Чт','Пт','Сб','Вс']

const STATIC_EVENTS = [
  { day: 20, label: 'Встреча команды', color: 'var(--primary)' },
  { day: 25, label: 'Дедлайн отчёта', color: 'var(--danger)' },
]

export default function CalendarCard() {
  const today = new Date()
  const [cur, setCur] = useState(new Date(today.getFullYear(), today.getMonth(), 1))

  const prevMonth = () => setCur(new Date(cur.getFullYear(), cur.getMonth() - 1, 1))
  const nextMonth = () => setCur(new Date(cur.getFullYear(), cur.getMonth() + 1, 1))

  const year = cur.getFullYear()
  const month = cur.getMonth()
  const firstDay = (new Date(year, month, 1).getDay() + 6) % 7 // Mon=0
  const daysInMonth = new Date(year, month + 1, 0).getDate()

  const cells = []
  for (let i = 0; i < firstDay; i++) cells.push(null)
  for (let d = 1; d <= daysInMonth; d++) cells.push(d)

  const isToday = (d) => d && today.getDate() === d && today.getMonth() === month && today.getFullYear() === year

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
        {cells.map((d, i) => (
          <div key={i} style={{
            textAlign: 'center', padding: '5px 0', borderRadius: 8, fontSize: 12, fontWeight: isToday(d) ? 700 : 500,
            background: isToday(d) ? 'var(--primary)' : 'transparent',
            color: isToday(d) ? '#fff' : d ? 'var(--ink-2)' : 'transparent',
            cursor: d ? 'pointer' : 'default',
          }}>{d || ''}</div>
        ))}
      </div>

      {STATIC_EVENTS.length > 0 && (
        <div style={{ marginTop: 14, display: 'flex', flexDirection: 'column', gap: 6 }}>
          <div style={{ fontSize: 11, fontWeight: 700, color: 'var(--muted)', textTransform: 'uppercase', letterSpacing: 0.5 }}>События</div>
          {STATIC_EVENTS.map((ev, i) => (
            <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '7px 10px', background: 'var(--surface-2)', borderRadius: 8, border: '1px solid var(--line)' }}>
              <div style={{ width: 3, height: 24, borderRadius: 99, background: ev.color, flexShrink: 0 }} />
              <div style={{ fontSize: 12, fontWeight: 600, color: 'var(--ink-2)' }}>{ev.label}</div>
              <div style={{ marginLeft: 'auto', fontSize: 11, color: 'var(--muted)' }}>{ev.day} {MONTHS_RU[month].slice(0,3).toLowerCase()}</div>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
