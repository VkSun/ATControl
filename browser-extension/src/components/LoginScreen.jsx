import { useState } from 'react'
import { supabase } from '../lib/supabase'
import { I } from './Icons'

export default function LoginScreen() {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')

  const handleLogin = async (e) => {
    e.preventDefault()
    if (!email || !password) return
    setLoading(true)
    setError('')
    const { error: err } = await supabase.auth.signInWithPassword({ email, password })
    if (err) setError(err.message)
    setLoading(false)
  }

  return (
    <div style={{
      minHeight: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center',
      background: 'var(--bg)', padding: 20,
    }}>
      <div style={{
        width: '100%', maxWidth: 400,
        background: 'var(--surface)', borderRadius: 20, boxShadow: 'var(--shadow-lg)',
        padding: '40px 36px', border: '1px solid var(--line)',
      }}>
        {/* Logo */}
        <div style={{ textAlign: 'center', marginBottom: 32 }}>
          <div style={{
            width: 64, height: 64, borderRadius: 18, background: 'var(--primary)',
            display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 16px',
            boxShadow: '0 8px 24px rgba(67,94,190,.3)',
          }}>
            {I.atc({ size: 30, stroke: 2, style: { color: '#fff' } })}
          </div>
          <div style={{ fontFamily: 'Nunito', fontWeight: 800, fontSize: 26, color: 'var(--ink)' }}>ATControl</div>
          <div style={{ fontSize: 13, color: 'var(--muted)', marginTop: 4, fontWeight: 500 }}>Войдите в свой аккаунт</div>
        </div>

        {error && (
          <div style={{ marginBottom: 16, padding: '10px 14px', background: '#FCE6EA', color: 'var(--danger)', borderRadius: 10, fontSize: 13, fontWeight: 500 }}>{error}</div>
        )}

        <form onSubmit={handleLogin} style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
          <div>
            <label style={{ display: 'block', fontSize: 12, fontWeight: 700, color: 'var(--muted)', marginBottom: 6, textTransform: 'uppercase', letterSpacing: 0.5 }}>Email</label>
            <input type="email" value={email} onChange={e => setEmail(e.target.value)} required
              placeholder="your@email.com"
              style={{ width: '100%', padding: '11px 14px', border: '1.5px solid var(--line)', borderRadius: 10, fontSize: 14, fontFamily: 'Inter', outline: 'none', background: 'var(--surface-2)', color: 'var(--ink)', transition: 'border-color .15s' }}
              onFocus={e => e.target.style.borderColor = 'var(--primary)'}
              onBlur={e => e.target.style.borderColor = 'var(--line)'} />
          </div>
          <div>
            <label style={{ display: 'block', fontSize: 12, fontWeight: 700, color: 'var(--muted)', marginBottom: 6, textTransform: 'uppercase', letterSpacing: 0.5 }}>Пароль</label>
            <input type="password" value={password} onChange={e => setPassword(e.target.value)} required
              placeholder="••••••••"
              style={{ width: '100%', padding: '11px 14px', border: '1.5px solid var(--line)', borderRadius: 10, fontSize: 14, fontFamily: 'Inter', outline: 'none', background: 'var(--surface-2)', color: 'var(--ink)', transition: 'border-color .15s' }}
              onFocus={e => e.target.style.borderColor = 'var(--primary)'}
              onBlur={e => e.target.style.borderColor = 'var(--line)'} />
          </div>
          <button type="submit" disabled={loading} style={{
            marginTop: 6, padding: '13px', background: loading ? 'var(--primary-soft)' : 'var(--primary)',
            color: loading ? 'var(--primary)' : '#fff', border: 'none', borderRadius: 12,
            cursor: loading ? 'not-allowed' : 'pointer', fontSize: 15, fontWeight: 700,
            fontFamily: 'Nunito', transition: 'all .15s', boxShadow: loading ? 'none' : '0 4px 16px rgba(67,94,190,.3)',
          }}>
            {loading ? 'Вход...' : 'Войти'}
          </button>
        </form>

        <div style={{ marginTop: 24, textAlign: 'center', fontSize: 12, color: 'var(--muted)' }}>
          ATControl — Fleet Management System
        </div>
      </div>
    </div>
  )
}
