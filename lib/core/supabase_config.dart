/// Credenciais do Supabase, passadas na compilação com
/// `--dart-define-from-file=supabase.json`.
class SupabaseConfig {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
  static bool get configured => url.isNotEmpty && publishableKey.isNotEmpty;
}
