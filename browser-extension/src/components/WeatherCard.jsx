import { useState } from 'react'
import { I } from './Icons'

const WEATHER_STATES = [
  { id: 'sun',   icon: 'sun',   label: 'Ясно',    temp: '+22', color: '#F5A623' },
  { id: 'cloud', icon: 'cloud', label: 'Облачно', temp: '+15', color: '#8896B3' },
  { id: 'rain',  icon: 'drop',  label: 'Дождь',   temp: '+10', color: '#3BAFDA' },
  { id: 'wind',  icon: 'wind',  label: 'Ветрено', temp: '+8',  color: '#20C997' },
]

export default function WeatherCard() {
  const [idx, setIdx] = useState(0)
  const w = WEATHER_STATES[idx]
  return (
    <div className="mz-card" style={{ textAlign: 'center', cursor: 'pointer', padding: '20px 16px' }} onClick={() => setIdx((idx + 1) % WEATHER_STATES.length)}>
      <div style={{ color: w.color, marginBottom: 4 }}>{I[w.icon]({ size: 32, stroke: 1.5, style: { color: w.color } })}</div>
      <div style={{ fontFamily: 'Nunito', fontWeight: 800, fontSize: 32, color: 'var(--ink)', lineHeight: 1 }}>{w.temp}°</div>
      <div style={{ marginTop: 4, fontWeight: 600, fontSize: 13, color: 'var(--muted)' }}>{w.label}</div>
      <div style={{ marginTop: 2, fontWeight: 500, fontSize: 11, color: 'var(--line-2)' }}>нажмите для смены</div>
    </div>
  )
}
