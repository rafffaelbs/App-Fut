import 'package:supabase_flutter/supabase_flutter.dart';

import '../repositories/supabase_service.dart';

/// Supabase configuration for the App-Fut project.
class SupabaseConfig {
  static const String projectId = 'hcjiqushursknfsdvavy';
  static const String url = 'https://hcjiqushursknfsdvavy.supabase.co';
  static const String anonKey = 'sb_publishable_6xkP9do8NMPFrVvtB-12dw_lAzrEf2s';

  /// Inicializa a SDK do Supabase no aplicativo.
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: url,
      anonKey: anonKey, // ignore: deprecated_member_use
    );
  }

  /// The active Supabase client instance.
  static SupabaseClient get client => Supabase.instance.client;

  /// The current authenticated user's ID (UUID), or null if not authenticated.
  static String? get currentUserId => SupabaseService.auth.currentUserId;
}

/// Convenience accessor for the Supabase client.
SupabaseClient get supabase => SupabaseConfig.client;
