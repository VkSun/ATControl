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
  const [city, setCity] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const cached = getCache()
    if (cached) {
      setWeather({ temp: cached.temp, code: cached.code })
      setCity(cached.city || '')
      setLoading(false)
      return
    }

    if (!navigator.geolocation) {
      setError('Геолокация недоступна')
      setLoading(false)
      return
    }

    navigator.geolocation.getCurrentPosition(
      async ({ coords: { latitude: lat, longitude: lon } }) => {
        try {
          const [wRes, gRes] = await Promise.all([
            fetch(`https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&current=temperature_2m,weathercode&timezone=auto`),
            fetch(`https://nominatim.openstreetmap.org/reverse?lat=${lat}&lon=${lon}&format=json`, {
              headers: { 'Accept-Language': 'ru,en' }
            }),
          ])
          const wData = await wRes.json()
          const gData = await gRes.json()

          const temp = Math.round(wData.current.temperature_2m)
          const code = wData.current.weathercode
          const cityName = gData.address?.city || gData.address?.town || gData.address?.village || gData.address?.county || ''

          setWeather({ temp, code })
          setCity(cityName)
          setCache({ temp, code, city: cityName })
        } catch {
          setError('Ошибка загрузки погоды')
        } finally {
          setLoading(false)
        }
      },
      () => {
        setError('Нет доступа к геолокации')
        setLoading(false)
      },
      { timeout: 8000 }
    )
  }, [])

  if (loading) {
    return (
      <div className="mz-card" style={{ textAlign: 'center', padding: '20px 16px' }}>
        <div style={{ color: 'var(--muted)', fontSize: 13, fontWeight: 500 }}>Определяем погоду...</div>
      </div>
    )
  }

  if (error || !weather) {
    return (
      <div className="mz-card" style={{ textAlign: 'center', padding: '20px 16px' }}>
        <div style={{ color: 'var(--muted)', fontSize: 12, fontWeight: 500, lineHeight: 1.4 }}>{error || 'Нет данных о погоде'}</div>
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
      {city && <div style={{ marginTop: 3, fontWeight: 500, fontSize: 11, color: 'var(--line-2)' }}>{city}</div>}
    </div>
  )
}
