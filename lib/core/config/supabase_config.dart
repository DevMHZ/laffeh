import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/debug_log.dart';
import 'env_config.dart';

/// One-shot Supabase initialisation, called from `main()` before `runApp`.
///
/// Deliberately tolerant: if `.env` has no Supabase credentials the app still
/// boots (auth + location tracking simply stay disabled via
/// [EnvConfig.hasSupabase]). This keeps the local-first map planner usable
/// before a backend is wired up.
class SupabaseConfig {
  SupabaseConfig._();

  static bool _initialized = false;

  /// Whether a live Supabase client is available this session.
  static bool get isReady => _initialized;

  /// The shared client. Only touch this when [isReady] is true.
  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> init() async {
    if (_initialized) return;
    if (!EnvConfig.hasSupabase) {
      DebugLog.banner('Supabase NOT configured — auth/tracking disabled');
      return;
    }
    try {
      await Supabase.initialize(
        url: EnvConfig.supabaseUrl,
        // `publishableKey` is the current client key (both the legacy anon
        // JWT and the newer sb_publishable_… key are accepted here).
        publishableKey: EnvConfig.supabaseAnonKey,
      );
      _initialized = true;
      DebugLog.banner('Supabase ready');
    } catch (e) {
      // Never let a backend hiccup block startup of the offline planner.
      DebugLog.banner('Supabase init failed: $e');
    }
  }
}
