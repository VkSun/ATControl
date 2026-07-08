/// Конфигурация приложения. Значения задаются на этапе сборки:
///
///   flutter build <target> \
///     --dart-define=SUPABASE_URL=https://xxx.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=eyJ...
///
/// Без --dart-define (или с пустым значением, как в CI без секретов)
/// используются значения основного инстанса — исходники под свой
/// инстанс править не нужно.
class AppConfig {
  AppConfig._();

  static const _urlEnv = String.fromEnvironment('SUPABASE_URL');
  static const _anonKeyEnv = String.fromEnvironment('SUPABASE_ANON_KEY');

  static const supabaseUrl = _urlEnv != ''
      ? _urlEnv
      : 'https://gmekcuwebewdhupywyal.supabase.co';

  static const supabaseAnonKey = _anonKeyEnv != ''
      ? _anonKeyEnv
      : 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdtZWtjdXdlYmV3ZGh1cHl3eWFsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzczOTU5NDMsImV4cCI6MjA5Mjk3MTk0M30.gqxIiHldZViI4f_sTrjuG3Bmr18jAZKfJNyLpO8l10s';
}
