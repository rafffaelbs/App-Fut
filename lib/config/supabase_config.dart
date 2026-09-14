import 'package:supabase_flutter/supabase_flutter.dart';

/// Configurações do Supabase para o projeto App-Fut.
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

  /// Instância do cliente Supabase ativo.
  static SupabaseClient get client => Supabase.instance.client;

  /// Usuário autenticado atual do Supabase Auth.
  static User? get currentUser => client.auth.currentUser;

  /// ID do usuário autenticado atual (UUID) ou nulo se não autenticado.
  static String? get currentUserId => client.auth.currentUser?.id;
}

/// Acesso de conveniência ao cliente Supabase.
SupabaseClient get supabase => SupabaseConfig.client;
