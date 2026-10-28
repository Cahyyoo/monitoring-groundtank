/// Build-time configuration, supplied with
/// `flutter run --dart-define-from-file=env.json` (see `env.example.json`).
///
/// Compile-time constants rather than a bundled file or a settings field:
/// nothing to ship by accident in an asset, nothing for a user to mistype,
/// and they are just as available inside the WorkManager isolate.
abstract final class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  /// The project's publishable key (`sb_publishable_…`) or its legacy anon
  /// key. Either is safe in a client: what it may read is decided by the
  /// row-level-security policies in `supabase/setup.sql`.
  static const supabaseKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: String.fromEnvironment('SUPABASE_ANON_KEY'),
  );

  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;
}
