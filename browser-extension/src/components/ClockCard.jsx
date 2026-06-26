import { useState, useEffect } from 'react'

const DAYS = ['Воскресенье','Понедельник','Вторник','Среда','Четверг','Пятница','Суббота']
const MONTHS = ['января','февраля','марта','апреля','мая','июня','июля','августа','сентября','октября','ноября','декабря']

export default function ClockCard() {
  const [now, setNow] = useState(new Date())
  useEffect(() => {
    const t = setInterval(() => setNow(new Date()), 1000)
    return () => clearInterval(t)
  }, [])

  const hh = String(now.getHours()).padStart(2, '0')
  const mm = String(now.getMinutes()).padStart(2, '0')
  const ss = String(now.getSeconds()).padStart(2, '0')
  const day = DAYS[now.getDay()]
  const date = `${now.getDate()} ${MONTHS[now.getMonth()]} ${now.getFullYear()}`

  return (
    <div className="mz-card" style={{ textAlign: 'center', padding: '20px 16px' }}>
      <div style={{ fontFamily: 'Nunito', fontWeight: 700, fontSize: 42, letterSpacing: -1, color: 'var(--ink)', lineHeight: 1 }}>
        {hh}:{mm}<span style={{ color: 'var(--primary)', fontSize: 28 }}>:{ss}</span>
      </div>
      <div style={{ marginTop: 6, fontWeight: 600, fontSize: 13, color: 'var(--muted)' }}>{day}</div>
      <div style={{ marginTop: 2, fontWeight: 500, fontSize: 12, color: 'var(--muted)' }}>{date}</div>
    </div>
  )
}
