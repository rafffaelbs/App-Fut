import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../domain/services/diagnostics_service.dart';
import '../../domain/services/site_sync_service.dart';
import '../../utils/player_identity.dart';
import 'site_data_generator.dart';
import 'supabase_config.dart';

class SupabaseSiteSyncService implements SiteSyncService {
  final SupabaseClient? _customClient;
  final DiagnosticsService? _diagnosticsService;
  static const Uuid _uuid = Uuid();

  SupabaseSiteSyncService({
    SupabaseClient? client,
    DiagnosticsService? diagnosticsService,
  })  : _customClient = client,
        _diagnosticsService = diagnosticsService;

  SupabaseClient get _supabase => _customClient ?? SupabaseConfig.client;

  String? _cachedCode;

  /// Faz o backup de todos os dados locais (SharedPreferences) para o Supabase.
  @override
  Future<void> exportDataToSupabase(String syncCode) async {
    final prefs = await SharedPreferences.getInstance();
    await _normalizeUuidData(prefs);
    await _normalizeSessionIds(prefs);
    final keys = prefs.getKeys();

    final Map<String, dynamic> data = {};
    for (final String key in keys) {
      data[key] = prefs.get(key);
    }

    final siteData = await SiteDataGenerator.generate(prefs);

    // Salvar o json completo no Supabase
    await _supabase.from('sync_data').upsert({
      'sync_code': syncCode,
      'data': data,
      'site_data': siteData,
      'last_updated': DateTime.now().toIso8601String(),
    });

    await _diagnosticsService?.recordCloudSyncSuccess();
  }

  /// Gera ou recupera o sync code ativo
  @override
  Future<String> getOrCreateSyncCode() async {
    if (_cachedCode != null) return _cachedCode!;

    final prefs = await SharedPreferences.getInstance();
    final String? existingCode = prefs.getString('my_sync_code');

    if (existingCode != null && existingCode.isNotEmpty) {
      _cachedCode = existingCode;
      return existingCode;
    }

    final String timeStr = DateTime.now().millisecondsSinceEpoch.toString();
    final String newCode = "SNC${timeStr.substring(timeStr.length - 4)}"; // e.g. SNC1234

    await prefs.setString('my_sync_code', newCode);
    _cachedCode = newCode;
    return newCode;
  }

  Future<void> _normalizeUuidData(SharedPreferences prefs) async {
    final Map<String, String> nameToId = {};

    final playerKeys = prefs
        .getKeys()
        .where((k) => k.startsWith('players_'))
        .toList();

    for (final key in playerKeys) {
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) continue;
      final loaded = List<Map<String, dynamic>>.from(jsonDecode(raw));
      final List<Map<String, dynamic>> normalized = [];
      for (final player in ensurePlayerIds(loaded)) {
        final map = Map<String, dynamic>.from(player);
        String id = (map['id'] ?? '').toString();
        final name = (map['name'] ?? '').toString();
        if (id.isEmpty || id == name) {
          id = _uuid.v4();
          map['id'] = id;
        }
        if (name.isNotEmpty) {
          nameToId[name.toLowerCase()] = id;
        }
        normalized.add(map);
      }
      await prefs.setString(key, jsonEncode(normalized));
    }

    Future<void> normalizePlayerListKey(String key) async {
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return;
      final loaded = List<Map<String, dynamic>>.from(jsonDecode(raw));
      final normalized = loaded.map((player) {
        final map = Map<String, dynamic>.from(player);
        final name = (map['name'] ?? '').toString();
        if (name.isNotEmpty) {
          final inferred = nameToId[name.toLowerCase()];
          if (inferred != null) {
            map['id'] = inferred;
          } else if ((map['id'] ?? '').toString().isEmpty) {
            map['id'] = _uuid.v4();
          }
        }
        return map;
      }).toList();
      await prefs.setString(key, jsonEncode(normalized));
    }

    for (final key in prefs.getKeys().where((k) => k.startsWith('present_players_'))) {
      await normalizePlayerListKey(key);
    }
    for (final key in prefs.getKeys().where((k) => k.startsWith('team_red_'))) {
      await normalizePlayerListKey(key);
    }
    for (final key in prefs.getKeys().where((k) => k.startsWith('team_white_'))) {
      await normalizePlayerListKey(key);
    }

    for (final key in prefs.getKeys().where((k) => k.startsWith('match_history_'))) {
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) continue;
      final history = List<dynamic>.from(jsonDecode(raw));
      for (final match in history) {
        final players = Map<String, dynamic>.from(match['players'] ?? {});
        for (final side in ['red', 'white']) {
          final list = List<dynamic>.from(players[side] ?? []);
          for (final p in list) {
            final id = playerIdFromObject(p);
            final name = (p['name'] ?? '').toString();
            if ((id.isEmpty || id == name) && nameToId.containsKey(name.toLowerCase())) {
              p['id'] = nameToId[name.toLowerCase()];
            } else if ((id.isEmpty || id == name) && name.isNotEmpty) {
              p['id'] = _uuid.v4();
            }
          }
        }

        final events = List<dynamic>.from(match['events'] ?? []);
        for (final event in events) {
          final playerName = (event['player'] ?? '').toString();
          final assistName = (event['assist'] ?? '').toString();
          if ((eventPlayerId(event, 'player').isEmpty || eventPlayerId(event, 'player') == playerName) &&
              playerName.isNotEmpty) {
            event['playerId'] =
                nameToId[playerName.toLowerCase()] ?? _uuid.v4();
          }
          if (assistName.isNotEmpty &&
              (eventPlayerId(event, 'assist').isEmpty ||
                  eventPlayerId(event, 'assist') == assistName)) {
            event['assistId'] =
                nameToId[assistName.toLowerCase()] ?? _uuid.v4();
          }
        }
      }
      await prefs.setString(key, jsonEncode(history));
    }
  }

  Future<void> _normalizeSessionIds(SharedPreferences prefs) async {
    final sessionKeys =
        prefs.getKeys().where((k) => k.startsWith('sessions_')).toList();

    for (final key in sessionKeys) {
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) continue;

      final List<dynamic> sessions = jsonDecode(raw);
      bool changed = false;

      for (int i = 0; i < sessions.length; i++) {
        final session = sessions[i];
        final String oldId = session['id'].toString();

        // Regex to detect the old format: session_ followed by many digits (timestamp)
        final oldFormat = RegExp(r'^session_\d{10,13}$');
        if (oldFormat.hasMatch(oldId)) {
          final String name = (session['title'] ?? 'pelada')
              .toString()
              .toLowerCase()
              .replaceAll(RegExp(r'[^a-z0-9]'), '_');
          final String random = const Uuid().v4().substring(0, 4);
          final String newId = 'session_${name}_$random';

          // Renames the match history key if it exists
          final oldHistoryKey = 'match_history_$oldId';
          final newHistoryKey = 'match_history_$newId';

          if (prefs.containsKey(oldHistoryKey)) {
            final historyData = prefs.getString(oldHistoryKey);
            if (historyData != null) {
              await prefs.setString(newHistoryKey, historyData);
              await prefs.remove(oldHistoryKey);
            }
          }

          session['id'] = newId;
          changed = true;
        }
      }

      if (changed) {
        await prefs.setString(key, jsonEncode(sessions));
      }
    }
  }
}
