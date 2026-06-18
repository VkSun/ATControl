import { useState, useEffect } from 'react'
import { I } from './Icons'

const WMO = {
  0:  { icon: 'sun',   label: 'Ясно',             color: '#F5A623' },
  1:  { icon: 'sun',   label: 'Преим. ясно',       color: '#F5A623' },
  2:  { icon: 'cloud', label: 'Переменная облачность', color: '#8896B3' },
  3:  { icon: 'cloud', label: 'Пасмурно',          color: '#8896B3' },
  45: { icon: 'cloud', label: 'Туман',             color: '#8896B3' },
  48: { icon: 'cloud', label: 'Гололёд',           color: '#8896B3' },
  51: { icon: 'drop',  label: 'Лёгкая морось',     color: '#3BAFDA' },
  53: { icon: 'drop',  label: 'Морось',            color: '#3BAFDA' },
  55: { icon: 'drop',  label: 'Сильная морось',    color: '#3BAFDA' },
  61: { icon: 'drop',  label: 'Лёгкий дождь',      color: '#3BAFDA' },
  63: { icon: 'drop',  label: 'Дождь',             color: '#3BAFDA' },
  65: { icon: 'drop',  label: 'Сильный дождь',     color: '#3BAFDA' },
  71: { icon: 'wind',  label: 'Лёгкий снег',       color: '#8896B3' },
  73: { icon: 'wind',  label: 'Снег',              color: '#8896B3' },
  75: { icon: 'wind',  label: 'Сильный снег',      color: '#8896B3' },
  77: { icon: 'wind',  label: 'Снежная крупа',     color: '#8896B3' },
  80: { icon: 'drop',  label: 'Ливень',            color: '#3BAFDA' },
  81: { icon: 'drop',  label: 'Ливень',            color: '#3BAFDA' },
  82: { icon: 'drop',  label: 'Сильный ливень',    color: '#3BAFDA' },
  85: { icon: 'wind',  label: 'Снегопад',          color: '#8896B3' },
  86: { icon: 'wind',  label: 'Сильный снегопад',  color: '#8896B3' },
  95: { icon: 'wind',  label: 'Гроза',             color: '#435EBE' },
  96: { icon: 'wind',  label: 'Гроза с градом',    color: '#435EBE' },
  99: { icon: 'wind',  label: 'Гроза с градом',    color: '#435EBE' },
}

const LAT = 53.9045
const LON = 27.5615
const CITY = 'Минск'

const CACHE_KEY = 'atc_weather_cache'
const CACHE_TTL = 30 * 60 * 1000

function getCache() {
  try {
    const c = JSON.parse(localStorage.getItem(CACHE_KEY))
    if (c && Date.now() - c.ts < CACHE_TTL) return c
  } catch {}
  return null
}

function setCache(data) {
  localStorage.setItem(CACHE_KEY, JSON.stringify({ ...data, ts: Date.now() }))
}

export default function WeatherCard() {
  const [weather, setWeather] = useState(null)
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const cached = getCache()
    if (cached) {
      setWeather({ temp: cached.temp, code: cached.code })
      setLoading(false)
      return
    }

    fetch(`https://api.open-meteo.com/v1/forecast?latitude=${LAT}&longitude=${LON}&current=temperature_2m,weathercode&timezone=auto`)
      .then(r => r.json())
      .then(data => {
        const temp = Math.round(data.current.temperature_2m)
        const code = data.current.weathercode
        setWeather({ temp, code })
        setCache({ temp, code })
      })
      .catch(() => setError('Ошибка загрузки погоды'))
      .finally(() => setLoading(false))
  }, [])

  if (loading) {
    return (
      <div className="mz-card" style={{ textAlign: 'center', padding: '20px 16px' }}>
        <div style={{ color: 'var(--muted)', fontSize: 13, fontWeight: 500 }}>Загрузка погоды...</div>
      </div>
    )
  }

  if (error || !weather) {
    return (
      <div className="mz-card" style={{ textAlign: 'center', padding: '20px 16px' }}>
        <div style={{ color: 'var(--muted)', fontSize: 12, fontWeight: 500, lineHeight: 1.4 }}>{error || 'Нет данных'}</div>
      </div>
    )
  }

  const info = WMO[weather.code] || { icon: 'cloud', label: 'Облачно', color: '#8896B3' }

  return (
    <div className="mz-card" style={{ textAlign: 'center', padding: '20px 16px' }}>
      <div style={{ marginBottom: 4 }}>{I[info.icon]({ size: 32, stroke: 1.5, style: { color: info.color } })}</div>
      <div style={{ fontFamily: 'Nunito', fontWeight: 800, fontSize: 32, color: 'var(--ink)', lineHeight: 1 }}>
        {weather.temp > 0 ? '+' : ''}{weather.temp}°
      </div>
      <div style={{ marginTop: 4, fontWeight: 600, fontSize: 13, color: 'var(--muted)' }}>{info.label}</div>
      <div style={{ marginTop: 3, fontWeight: 500, fontSize: 11, color: 'var(--line-2)' }}>{CITY}</div>
    </div>
  )
}
