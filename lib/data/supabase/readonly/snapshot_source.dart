import 'package:supabase_flutter/supabase_flutter.dart';

/// Fonte em memória do snapshot do grupo carregado via token.
///
/// Chama a RPC `get_group_snapshot(p_token)` uma vez, guarda os dados em
/// memória (sem SharedPreferences e sem CacheStore) e permite recarregamento
/// forçado (`refresh`).
class SnapshotSource {
  final SupabaseClient? client;
  final String token;
  final Future<Map<String, dynamic>> Function(String token)? rpcCaller;

  Map<String, dynamic>? _data;

  SnapshotSource({
    this.client,
    required this.token,
    Map<String, dynamic>? initialData,
    this.rpcCaller,
  }) : _data = initialData;

  Map<String, dynamic>? get data => _data;

  bool get hasData => _data != null;

  Map<String, dynamic>? get group =>
      _data?['group'] != null ? Map<String, dynamic>.from(_data!['group'] as Map) : null;

  List<dynamic> get seasons => (_data?['seasons'] as List?) ?? const [];

  List<dynamic> get sessions => (_data?['sessions'] as List?) ?? const [];

  List<dynamic> get players => (_data?['players'] as List?) ?? const [];

  List<dynamic> get members => (_data?['members'] as List?) ?? const [];

  List<dynamic> get matches => (_data?['matches'] as List?) ?? const [];

  List<dynamic> get lineups => (_data?['lineups'] as List?) ?? const [];

  List<dynamic> get events => (_data?['events'] as List?) ?? const [];

  /// Carrega o snapshot da nuvem. Se já carregado e [forceRefresh] for falso,
  /// devolve o mapa em memória.
  Future<Map<String, dynamic>> load({bool forceRefresh = false}) async {
    if (_data != null && !forceRefresh) {
      return _data!;
    }

    if (rpcCaller != null) {
      final res = await rpcCaller!(token);
      _data = Map<String, dynamic>.from(res);
      return _data!;
    }

    final c = client;
    if (c == null) {
      throw StateError('SupabaseClient não fornecido para SnapshotSource.');
    }

    final response = await c.rpc(
      'get_group_snapshot',
      params: {'p_token': token},
    );

    if (response == null) {
      throw StateError(
        'get_group_snapshot retornou null para o token fornecido.',
      );
    }

    if (response is Map) {
      _data = Map<String, dynamic>.from(response);
      return _data!;
    }

    throw FormatException(
      'get_group_snapshot retornou formato inesperado: ${response.runtimeType}',
    );
  }

  /// Recarrega os dados da nuvem sobrescrevendo o cache em memória (pull-to-refresh).
  Future<Map<String, dynamic>> refresh() => load(forceRefresh: true);
}
