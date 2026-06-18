import { useState } from 'react'
import { I } from './Icons'

const ENGINES = [
  { key: 'google',    label: 'Google',    url: 'https://www.google.com/search?q=', color: '#4285F4' },
  { key: 'yandex',   label: 'Яндекс',    url: 'https://yandex.ru/search/?text=', color: '#FC3F1D' },
  { key: 'ddg',      label: 'DuckDuckGo',url: 'https://duckduckgo.com/?q=',       color: '#DE5833' },
  { key: 'bing',     label: 'Bing',       url: 'https://www.bing.com/search?q=',  color: '#0078D7' },
]

export default function SearchCard({ greeting, userName }) {
  const [engine, setEngine] = useState('google')
  const [q, setQ] = useState('')

  const greetTime = () => {
    const h = new Date().getHours()
    if (h < 6) return 'Доброй ночи'
    if (h < 12) return 'Доброе утро'
    if (h < 18) return 'Добрый день'
    return 'Добрый вечер'
  }

  const handleSearch = (e) => {
    e.preventDefault()
    if (!q.trim()) return
    const eng = ENGINES.find(e => e.key === engine)
    window.location.href = eng.url + encodeURIComponent(q)
  }

  const handleMic = () => {
    if (!('webkitSpeechRecognition' in window)) return
    const rec = new window.webkitSpeechRecognition()
    rec.lang = 'ru-RU'
    rec.onresult = (e) => setQ(e.results[0][0].transcript)
    rec.start()
  }

  return (
    <div className="mz-card" style={{ padding: '20px 24px' }}>
      {greeting && (
        <div style={{ textAlign: 'center', marginBottom: 14 }}>
          <div style={{ fontFamily: 'Nunito', fontWeight: 800, fontSize: 22, color: 'var(--ink)' }}>
            {greetTime()}{userName ? `, ${userName}` : ''}!
          </div>
        </div>
      )}
      <div style={{ display: 'flex', gap: 8, marginBottom: 12, justifyContent: 'center' }}>
        {ENGINES.map(eng => (
          <button key={eng.key} onClick={() => setEngine(eng.key)} style={{
            padding: '4px 12px', borderRadius: 99, border: 'none', cursor: 'pointer', fontSize: 12, fontWeight: 600,
            background: engine === eng.key ? eng.color : 'var(--surface-2)',
            color: engine === eng.key ? '#fff' : 'var(--muted)',
            transition: 'all .15s',
          }}>{eng.label}</button>
        ))}
      </div>
      <form onSubmit={handleSearch} style={{ display: 'flex', gap: 8, alignItems: 'center', background: 'var(--surface-2)', borderRadius: 99, border: '1.5px solid var(--line)', padding: '8px 12px 8px 16px' }}>
        <span style={{ color: 'var(--muted)', flexShrink: 0 }}>{I.search({ size: 16 })}</span>
        <input value={q} onChange={e => setQ(e.target.value)} placeholder="Поиск..." style={{
          flex: 1, border: 'none', background: 'transparent', outline: 'none',
          fontFamily: 'Inter', fontWeight: 500, fontSize: 14, color: 'var(--ink)',
        }} />
        <button type="button" onClick={handleMic} style={{ border: 'none', background: 'transparent', cursor: 'pointer', color: 'var(--muted)', display: 'flex', alignItems: 'center' }}>
          {I.mic({ size: 16 })}
        </button>
      </form>
    </div>
  )
}
