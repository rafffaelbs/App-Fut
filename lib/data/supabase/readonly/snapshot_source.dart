import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/group_model.dart';
import '../../../models/match_model.dart';
import '../../../models/player_model.dart';

/// Exceção lançada quando o link de compartilhamento é inválido, inexistente ou desativado.
class InvalidLinkException implements Exception {
  final String message;
  const InvalidLinkException([this.message = 'Link inválido ou desativado.']);

  @override
  String toString() => 'InvalidLinkException: $message';
}

/// Fonte em memória do snapshot do grupo carregado via token.
///
/// Chama a RPC `get_group_snapshot(p_token)` uma vez, guarda os dados e modelos
/// convertidos em memória (sem SharedPreferences e sem CacheStore) e permite
/// recarregamento forçado (`refresh`).
class SnapshotSource {
  final SupabaseClient? client;
  final String token;
  final Future<Map<String, dynamic>> Function(String token)? rpcCaller;

  static const Set<String> _sensitiveKeys = {
    'email',
    'creator_id',
    'invite_code',
    'sync_code',
    'goal_sound_url',
  };

  Map<String, dynamic>? _data;
  GroupModel? _cachedGroup;
  List<PlayerModel> _cachedPlayers = const [];
  List<MatchModel> _cachedMatches = const [];

  SnapshotSource({
    this.client,
    required this.token,
    Map<String, dynamic>? initialData,
    this.rpcCaller,
  }) : _data = initialData != null ? _sanitizeData(initialData) : null {
    if (_data != null) {
      _populateCachedModels();
    }
  }

  Map<String, dynamic>? get data => _data;

  bool get hasData => _data != null;

  Map<String, dynamic>? get group =>
      _data?['group'] != null ? Map<String, dynamic>.from(_data!['group'] as Map) : null;

  GroupModel? get cachedGroup => _cachedGroup;

  List<dynamic> get seasons => (_data?['seasons'] as List?) ?? const [];

  List<dynamic> get sessions => (_data?['sessions'] as List?) ?? const [];

  List<dynamic> get players => (_data?['players'] as List?) ?? const [];

  List<PlayerModel> get cachedPlayers => _cachedPlayers;

  List<dynamic> get members => (_data?['members'] as List?) ?? const [];

  List<dynamic> get matches => (_data?['matches'] as List?) ?? const [];

  List<MatchModel> get cachedMatches => _cachedMatches;

  List<dynamic> get lineups => (_data?['lineups'] as List?) ?? const [];

  List<dynamic> get events => (_data?['events'] as List?) ?? const [];

  /// Helper único que sanitiza dados brutos, removendo recursivamente chaves
  /// sensíveis antes de qualquer conversão para modelos.
  static Map<String, dynamic> _sanitizeData(Map<dynamic, dynamic> input) {
    final sanitized = <String, dynamic>{};
    for (final entry in input.entries) {
      final key = entry.key.toString();
      if (_sensitiveKeys.contains(key)) continue;
      final val = entry.value;
      if (val is Map) {
        sanitized[key] = _sanitizeData(val);
      } else if (val is List) {
        sanitized[key] = val.map((item) {
          if (item is Map) {
            return _sanitizeData(item);
          }
          return item;
        }).toList();
      } else {
        sanitized[key] = val;
      }
    }
    return sanitized;
  }

  void _populateCachedModels() {
    if (_data == null) {
      _cachedGroup = null;
      _cachedPlayers = const [];
      _cachedMatches = const [];
      return;
    }

    final g = group;
    _cachedGroup = g != null ? GroupModel.fromMap(g) : null;

    final rawPlayers = players;
    _cachedPlayers = rawPlayers
        .whereType<Map>()
        .map((m) => PlayerModel.fromMap(Map<String, dynamic>.from(m)))
        .toList(growable: false);

    final Map<String, Map<String, dynamic>> playersById = {
      for (final p in rawPlayers.whereType<Map>())
        if (p['id'] != null) p['id'].toString(): Map<String, dynamic>.from(p),
    };

    final Map<String, List<Map<String, dynamic>>> lineupsByMatch = {};
    for (final raw in lineups.whereType<Map>()) {
      final mId = raw['match_id']?.toString();
      if (mId == null) continue;
      final map = Map<String, dynamic>.from(raw);
      if (map['players'] == null && map['jogadores'] == null) {
        final pId = map['player_id']?.toString() ?? map['jogador_id']?.toString();
        if (pId != null && playersById.containsKey(pId)) {
          map['players'] = playersById[pId];
        }
      }
      lineupsByMatch.putIfAbsent(mId, () => []).add(map);
    }

    final Map<String, List<Map<String, dynamic>>> eventsByMatch = {};
    for (final raw in events.whereType<Map>()) {
      final mId = raw['match_id']?.toString();
      if (mId == null) continue;
      final map = Map<String, dynamic>.from(raw);
      if (map['players'] == null && map['player'] == null && map['jogador'] == null) {
        final pId = map['player_id']?.toString() ?? map['jogador_id']?.toString();
        if (pId != null && playersById.containsKey(pId)) {
          map['players'] = playersById[pId];
        }
      }
      if (map['assist_player'] == null && map['assist_jogador'] == null) {
        final aId =
            map['assist_player_id']?.toString() ?? map['assist_jogador_id']?.toString();
        if (aId != null && playersById.containsKey(aId)) {
          map['assist_player'] = playersById[aId];
        }
      }
      eventsByMatch.putIfAbsent(mId, () => []).add(map);
    }

    final List<MatchModel> matchModels = [];
    for (final raw in matches.whereType<Map>()) {
      final mId = raw['id']?.toString() ?? '';
      final matchMap = Map<String, dynamic>.from(raw);

      if (matchMap['match_lineups'] == null && matchMap['escalacao_partida'] == null) {
        matchMap['match_lineups'] = lineupsByMatch[mId] ?? const [];
      }
      if (matchMap['match_events'] == null && matchMap['eventos_partida'] == null) {
        matchMap['match_events'] = eventsByMatch[mId] ?? const [];
      }

      matchModels.add(MatchModel.fromMap(matchMap));
    }
    _cachedMatches = List.unmodifiable(matchModels);
  }

  /// Carrega o snapshot da nuvem. Se já carregado e [forceRefresh] for falso,
  /// devolve o mapa em memória.
  Future<Map<String, dynamic>> load({bool forceRefresh = false}) async {
    if (_data != null && !forceRefresh) {
      return _data!;
    }

    try {
      Map<dynamic, dynamic>? rawResponse;
      if (rpcCaller != null) {
        rawResponse = await rpcCaller!(token);
      } else {
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

        if (response is! Map) {
          throw FormatException(
            'get_group_snapshot retornou formato inesperado: ${response.runtimeType}',
          );
        }
        rawResponse = response;
      }

      _data = _sanitizeData(rawResponse);
      _populateCachedModels();
      return _data!;
    } on PostgrestException catch (e) {
      if (e.code == 'P0001' || e.message.contains('invalid_link')) {
        throw const InvalidLinkException();
      }
      rethrow;
    }
  }

  /// Recarrega os dados da nuvem sobrescrevendo o cache em memória (pull-to-refresh).
  Future<Map<String, dynamic>> refresh() => load(forceRefresh: true);
}
