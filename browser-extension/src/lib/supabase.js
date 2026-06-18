import { createClient } from '@supabase/supabase-js'

export const supabase = createClient(
  'https://gmekcuwebewdhupywyal.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdtZWtjdXdlYmV3ZGh1cHl3eWFsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzczOTU5NDMsImV4cCI6MjA5Mjk3MTk0M30.gqxIiHldZViI4f_sTrjuG3Bmr18jAZKfJNyLpO8l10s'
)
