class AppConfig {
  const AppConfig._();

  static const environment = String.fromEnvironment('APP_ENV', defaultValue: 'development');
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get hasSupabaseConfig => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
  static bool get isProduction => environment == 'production';
}
