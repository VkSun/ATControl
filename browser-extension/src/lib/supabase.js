import { createClient } from '@supabase/supabase-js'

// Свой инстанс: VITE_SUPABASE_URL / VITE_SUPABASE_ANON_KEY в .env
// (см. .env.example) или в переменных окружения сборки. Без них —
// значения основного инстанса.
const supabaseUrl =
  import.meta.env.VITE_SUPABASE_URL ||
  'https://gmekcuwebewdhupywyal.supabase.co'
const supabaseAnonKey =
  import.meta.env.VITE_SUPABASE_ANON_KEY ||
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdtZWtjdXdlYmV3ZGh1cHl3eWFsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzczOTU5NDMsImV4cCI6MjA5Mjk3MTk0M30.gqxIiHldZViI4f_sTrjuG3Bmr18jAZKfJNyLpO8l10s'

export const supabase = createClient(
  supabaseUrl,
  supabaseAnonKey,
  {
    auth: {
      persistSession: true,
      autoRefreshToken: true,
      detectSessionInUrl: false,
      storage: typeof window !== 'undefined' ? window.localStorage : undefined,
    },
    global: {
      fetch: (...args) => fetch(...args),
    },
  }
)
