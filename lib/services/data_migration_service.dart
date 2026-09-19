import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../config/supabase_config.dart';

/// Detailed result of running the data migration to Supabase.
class MigrationResult {
  final bool success;
  final int groupsCount;
  final int playersCount;
  final int seasonsCount;
  final int sessionsCount;
  final int matchesCount;
  final int lineupsCount;
  final int eventsCount;
  final int ratingsCount;
  final List<String> logs;
  final List<String> errors;

  MigrationResult({
    required this.success,
    this.groupsCount = 0,
    this.playersCount = 0,
    this.seasonsCount = 0,
    this.sessionsCount = 0,
    this.matchesCount = 0,
    this.lineupsCount = 0,
    this.eventsCount = 0,
    this.ratingsCount = 0,
    this.logs = const [],
    this.errors = const [],
  });

  @override
  String toString() {
    return 'MigrationResult(success: $success, grupos: $groupsCount, jogadores: $playersCount, temporadas: $seasonsCount, sessoes: $sessionsCount, partidas: $matchesCount, escalacoes: $lineupsCount, eventos: $eventsCount, ratings: $ratingsCount, erros: ${errors.length})';
  }
}

/// Service responsible for orchestrating the migration of local data (JSON/SharedPreferences)
/// into the relational tables of Supabase PostgreSQL.
class DataMigrationService {
  static const Uuid _uuid = Uuid();
  final SupabaseClient _client;

  DataMigrationService({SupabaseClient? client})
      : _client = client ?? SupabaseConfig.client;

  /// Main migration function.
  ///
  /// Can receive [jsonContent] explicitly (as a backup string), or read it from the local
  /// `pelada_backup_1789226662128.json` file, or from the [SharedPreferences] keys.
  Future<MigrationResult> migrateJsonToSupabase({
    String? jsonContent,
    void Function(String message)? onProgress,
  }) async {
    final List<String> logs = [];
    final List<String> errors = [];

    void log(String msg) {
      debugPrint('[MIGRATION] $msg');
      logs.add(msg);
      onProgress?.call(msg);
    }

    log('Iniciando processo de migração para o Supabase...');

    int totalGroups = 0;
    int totalPlayers = 0;
    int totalSeasons = 0;
    int totalSessions = 0;
    int totalMatches = 0;
    int totalLineups = 0;
    int totalEvents = 0;
    int totalRatings = 0;

    try {
      // 1. Retrieve the data Map
      Map<String, dynamic> rawData = {};
      if (jsonContent != null && jsonContent.trim().isNotEmpty) {
        rawData = jsonDecode(jsonContent);
        log('Dados carregados a partir da string JSON fornecida.');
      } else {
        // Try to read the local backup file from disk
        final backupFile = File('pelada_backup_1789226662128.json');
        if (await backupFile.exists()) {
          final content = await backupFile.readAsString();
          rawData = jsonDecode(content);
          log('Dados carregados do arquivo local pelada_backup_1789226662128.json.');
        } else {
          // Fallback to SharedPreferences
          log('Arquivo local não encontrado. Carregando dados do SharedPreferences...');
          final prefs = await SharedPreferences.getInstance();
          for (final key in prefs.getKeys()) {
            final val = prefs.get(key);
            if (val != null) {
              rawData[key] = val;
            }
          }
        }
      }

      if (rawData.isEmpty) {
        throw Exception('Nenhum dado encontrado para migrar (backup vazio).');
      }

      // 2. Extract Groups
      List<dynamic> groupsList = [];
      if (rawData.containsKey('app_groups')) {
        final gData = rawData['app_groups'];
        groupsList = gData is String ? jsonDecode(gData) : gData;
      }

      if (groupsList.isEmpty) {
        // Fallback: default group
        groupsList = [
          {
            'id': 'grupo_1773427387405',
            'name': 'Fut do INF',
            'createdAt': DateTime.now().toIso8601String(),
          }
        ];
      }

      log('Encontrados ${groupsList.length} grupo(s) para migração.');

      // Map to convert legacyGroupId -> newGroupUuid
      final Map<String, String> groupMapping = {};

      for (final g in groupsList) {
        final String legacyId = g['id']?.toString() ?? 'grupo_padrao';
        final String groupName = g['name']?.toString().trim() ?? 'Meu Grupo';
        final String groupUuid = _uuid.v4();
        groupMapping[legacyId] = groupUuid;

        log('Inserindo grupo: "$groupName" com UUID: $groupUuid');
        await _client.from('groups').insert({
          'id': groupUuid,
          'name': groupName,
          'creator_id': null,
          'created_at': g['createdAt'] ?? DateTime.now().toIso8601String(),
        });
        totalGroups++;
      }

      // Primary group to associate data with when there's no specific key
      final String primaryGroupUuid = groupMapping.values.first;

      // 3. Extract and Insert Players
      final Set<String> registeredPlayerIds = {};
      final List<Map<String, dynamic>> playersToInsert = [];
      final List<Map<String, dynamic>> membersToInsert = [];

      for (final key in rawData.keys) {
        if (key.startsWith('players_')) {
          final String legacyGId = key.replaceFirst('players_', '');
          final String targetGroupUuid = groupMapping[legacyGId] ?? primaryGroupUuid;

          final pData = rawData[key];
          final List<dynamic> pList = pData is String ? jsonDecode(pData) : pData;

          for (final p in pList) {
            final String? pId = p['id']?.toString();
            if (pId == null || pId.isEmpty) continue;
            if (registeredPlayerIds.contains(pId)) continue;

            registeredPlayerIds.add(pId);
            playersToInsert.add({
              'id': pId,
              'creator_id': null,
              'name': (p['name']?.toString().trim() ?? 'Jogador').isNotEmpty
                  ? p['name'].toString().trim()
                  : 'Jogador',
              'icon': p['icon']?.toString(),
              'badges': p['manual_badges'] ?? [],
            });

            membersToInsert.add({
              'id': _uuid.v4(),
              'group_id': targetGroupUuid,
              'player_id': pId,
              'role': 'member',
            });
          }
        }
      }

      // 4. Scan Matches to identify players not listed in the base list (to avoid breaking FKs)
      final Set<String> matchPlayerIds = {};
      final Map<String, String> missingPlayerNames = {};

      for (final key in rawData.keys) {
        if (key.startsWith('match_history_')) {
          final mData = rawData[key];
          final List<dynamic> matches = mData is String ? jsonDecode(mData) : mData;

          for (final m in matches) {
            final pObj = m['players'] as Map<String, dynamic>? ?? {};
            for (final side in ['red', 'white']) {
              final teamList = pObj[side] as List<dynamic>? ?? [];
              for (final pl in teamList) {
                if (pl is Map) {
                  final id = pl['id']?.toString();
                  if (id != null && id.isNotEmpty) {
                    matchPlayerIds.add(id);
                    if (!registeredPlayerIds.contains(id)) {
                      missingPlayerNames[id] = pl['name']?.toString() ?? 'Convidado';
                    }
                  }
                }
              }
            }
            for (final gkKey in ['gk_red', 'gk_white']) {
              final gk = pObj[gkKey];
              if (gk is Map) {
                final id = gk['id']?.toString();
                if (id != null && id.isNotEmpty) {
                  matchPlayerIds.add(id);
                  if (!registeredPlayerIds.contains(id)) {
                    missingPlayerNames[id] = gk['name']?.toString() ?? 'Goleiro';
                  }
                }
              }
            }
            final events = m['events'] as List<dynamic>? ?? [];
            for (final ev in events) {
              if (ev is Map) {
                final pId = ev['playerId']?.toString();
                if (pId != null && pId.isNotEmpty) {
                  matchPlayerIds.add(pId);
                  if (!registeredPlayerIds.contains(pId)) {
                    missingPlayerNames[pId] = ev['player']?.toString() ?? 'Peladeiro';
                  }
                }
                final aId = ev['assistId']?.toString();
                if (aId != null && aId.isNotEmpty) {
                  matchPlayerIds.add(aId);
                  if (!registeredPlayerIds.contains(aId)) {
                    missingPlayerNames[aId] = ev['assist']?.toString() ?? 'Peladeiro';
                  }
                }
              }
            }
          }
        }
      }

      // Add players recovered from matches
      for (final entry in missingPlayerNames.entries) {
        if (!registeredPlayerIds.contains(entry.key)) {
          registeredPlayerIds.add(entry.key);
          playersToInsert.add({
            'id': entry.key,
            'creator_id': null,
            'name': entry.value,
            'icon': null,
            'badges': [],
          });
          membersToInsert.add({
            'id': _uuid.v4(),
            'group_id': primaryGroupUuid,
            'player_id': entry.key,
            'role': 'member',
          });
          log('Jogador recuperado de partidas: "${entry.value}" (${entry.key})');
        }
      }

      // Batch insert of players
      if (playersToInsert.isNotEmpty) {
        log('Inserindo ${playersToInsert.length} jogadores em lote na tabela "players"...');
        await _insertInBatches('players', playersToInsert);
        totalPlayers = playersToInsert.length;
      }

      // Batch insert of group_members
      if (membersToInsert.isNotEmpty) {
        log('Inserindo ${membersToInsert.length} registros em "group_members"...');
        await _insertInBatches('group_members', membersToInsert);
      }

      // 5. Extract and Insert Seasons
      final List<Map<String, dynamic>> seasonsToInsert = [];
      final List<Map<String, dynamic>> parsedSeasons = [];

      for (final key in rawData.keys) {
        if (key.startsWith('seasons_')) {
          final String legacyGId = key.replaceFirst('seasons_', '');
          final String targetGroupUuid = groupMapping[legacyGId] ?? primaryGroupUuid;

          final sData = rawData[key];
          final List<dynamic> sList = sData is String ? jsonDecode(sData) : sData;

          for (final s in sList) {
            final String? sId = s['id']?.toString();
            if (sId == null || sId.isEmpty) continue;

            final String sName = s['name']?.toString().trim() ?? 'Temporada';
            final String? startStr = s['startDate']?.toString();
            final String? endStr = s['endDate']?.toString();

            final seasonMap = {
              'id': sId,
              'group_id': targetGroupUuid,
              'name': sName,
              'start_date': startStr != null ? DateTime.tryParse(startStr)?.toIso8601String().substring(0, 10) : null,
              'end_date': endStr != null ? DateTime.tryParse(endStr)?.toIso8601String().substring(0, 10) : null,
              'is_active': sName.contains('2026.2'),
            };

            seasonsToInsert.add(seasonMap);
            parsedSeasons.add({
              'id': sId,
              'name': sName,
              'start': startStr != null ? DateTime.tryParse(startStr) : null,
              'end': endStr != null ? DateTime.tryParse(endStr) : null,
            });
          }
        }
      }

      if (seasonsToInsert.isEmpty) {
        // Create a default season in case the backup has none
        final defaultSeasonId = _uuid.v4();
        seasonsToInsert.add({
          'id': defaultSeasonId,
          'group_id': primaryGroupUuid,
          'name': 'Temporada 1',
          'start_date': '2026-01-01',
          'end_date': '2026-12-31',
          'is_active': true,
        });
        parsedSeasons.add({
          'id': defaultSeasonId,
          'name': 'Temporada 1',
          'start': DateTime(2026, 1, 1),
          'end': DateTime(2026, 12, 31),
        });
      }

      log('Inserindo ${seasonsToInsert.length} temporadas em lote...');
      await _insertInBatches('seasons', seasonsToInsert);
      totalSeasons = seasonsToInsert.length;

      // 6. Extract and Insert Sessions (pickup games)
      final Map<String, String> sessionMapping = {}; // legacySessionId -> newSessionUuid
      final Map<String, String> sessionSeasonMap = {}; // legacySessionId -> seasonId
      final List<Map<String, dynamic>> sessionsToInsert = [];

      for (final key in rawData.keys) {
        if (key.startsWith('sessions_')) {
          final sData = rawData[key];
          final List<dynamic> sessList = sData is String ? jsonDecode(sData) : sData;

          for (final sess in sessList) {
            final String legacySessId = sess['id']?.toString() ?? '';
            if (legacySessId.isEmpty) continue;

            final String newSessUuid = _uuid.v4();
            sessionMapping[legacySessId] = newSessUuid;

            // Determine the date and the matching season
            DateTime? sessDate;
            if (sess['timestamp'] != null) {
              sessDate = DateTime.tryParse(sess['timestamp'].toString());
            }
            if (sessDate == null && sess['date'] != null) {
              final parts = sess['date'].toString().split('/');
              if (parts.length == 3) {
                sessDate = DateTime.tryParse('${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}');
              }
            }
            sessDate ??= DateTime.now();

            String? matchedSeasonId;
            for (final season in parsedSeasons) {
              final DateTime? start = season['start'];
              final DateTime? end = season['end'];
              if (start != null && end != null) {
                final endWithDay = end.add(const Duration(days: 1));
                if (sessDate.isAfter(start.subtract(const Duration(seconds: 1))) &&
                    sessDate.isBefore(endWithDay)) {
                  matchedSeasonId = season['id'];
                  break;
                }
              }
            }
            matchedSeasonId ??= parsedSeasons.first['id'];
            sessionSeasonMap[legacySessId] = matchedSeasonId!;

            sessionsToInsert.add({
              'id': newSessUuid,
              'season_id': matchedSeasonId,
              'title': sess['title']?.toString() ?? 'Pelada',
              'timestamp': sessDate.toIso8601String(),
              'status': 'finalizada',
              'duration_minutes': int.tryParse(sess['duration']?.toString() ?? '8') ?? 8,
              'win_limit': int.tryParse(sess['win_limit']?.toString() ?? '3') ?? 3,
            });
          }
        }
      }

      log('Inserindo ${sessionsToInsert.length} sessões de pelada em lote...');
      await _insertInBatches('sessions', sessionsToInsert);
      totalSessions = sessionsToInsert.length;

      // 7. Extract and Insert Matches, Lineups, Events and Rating History
      final List<Map<String, dynamic>> matchesToInsert = [];
      final List<Map<String, dynamic>> lineupsToInsert = [];
      final List<Map<String, dynamic>> eventsToInsert = [];
      final List<Map<String, dynamic>> ratingsToInsert = [];

      for (final key in rawData.keys) {
        if (key.startsWith('match_history_')) {
          final String legacySessId = key.replaceFirst('match_history_', '');
          final String? newSessUuid = sessionMapping[legacySessId];
          final String seasonId = sessionSeasonMap[legacySessId] ?? parsedSeasons.first['id'];

          if (newSessUuid == null) {
            log('Aviso: Histórico de partidas encontrado para sessão não mapeada: $legacySessId');
            continue;
          }

          final mData = rawData[key];
          final List<dynamic> matches = mData is String ? jsonDecode(mData) : mData;

          for (final m in matches) {
            final String matchUuid = _uuid.v4();
            final DateTime matchDate = m['date'] != null
                ? DateTime.tryParse(m['date'].toString()) ?? DateTime.now()
                : DateTime.now();

            int durationSec = 480;
            if (m['match_duration'] != null) {
              final parts = m['match_duration'].toString().split(':');
              if (parts.length == 2) {
                final min = int.tryParse(parts[0]) ?? 8;
                final sec = int.tryParse(parts[1]) ?? 0;
                durationSec = min * 60 + sec;
              }
            }

            matchesToInsert.add({
              'id': matchUuid,
              'session_id': newSessUuid,
              'start_time': matchDate.toIso8601String(),
              'team_a_score': int.tryParse(m['scoreRed']?.toString() ?? '0') ?? 0,
              'team_b_score': int.tryParse(m['scoreWhite']?.toString() ?? '0') ?? 0,
              'duration_seconds': durationSec,
            });

            // Lineup and Ratings
            final pObj = m['players'] as Map<String, dynamic>? ?? {};

            void processTeamPlayers(String side, bool isGk, dynamic playerOrList) {
              if (playerOrList == null) return;
              final list = playerOrList is List ? playerOrList : [playerOrList];
              for (final pl in list) {
                if (pl is Map) {
                  final pId = pl['id']?.toString();
                  if (pId != null && registeredPlayerIds.contains(pId)) {
                    final double rating = double.tryParse(pl['rating']?.toString() ?? '6.0') ?? 6.0;

                    lineupsToInsert.add({
                      'match_id': matchUuid,
                      'player_id': pId,
                      'time': side,
                      'is_goalkeeper': isGk,
                      'rating': rating,
                    });

                    ratingsToInsert.add({
                      'player_id': pId,
                      'match_id': matchUuid,
                      'season_id': seasonId,
                      'new_rating': rating,
                      'is_goalkeeper': isGk,
                      'created_at': matchDate.toIso8601String(),
                    });
                  }
                }
              }
            }

            processTeamPlayers('red', false, pObj['red']);
            processTeamPlayers('white', false, pObj['white']);
            processTeamPlayers('red', true, pObj['gk_red']);
            processTeamPlayers('white', true, pObj['gk_white']);

            // Events
            final events = m['events'] as List<dynamic>? ?? [];
            for (final ev in events) {
              if (ev is Map) {
                final pId = ev['playerId']?.toString();
                if (pId != null && registeredPlayerIds.contains(pId)) {
                  final rawTeam = ev['team']?.toString().toLowerCase() ?? '';
                  final side = rawTeam.contains('verm') || rawTeam.contains('red') ? 'red' : 'white';

                  String? astId = ev['assistId']?.toString();
                  if (astId != null && !registeredPlayerIds.contains(astId)) {
                    astId = null;
                  }

                  eventsToInsert.add({
                    'match_id': matchUuid,
                    'player_id': pId,
                    'assist_player_id': astId,
                    'event_type': ev['type']?.toString() ?? 'goal',
                    'time': side,
                    'minute': ev['time']?.toString(), // ex: "08:25"
                  });
                }
              }
            }
          }
        }
      }

      // Batch insert of Matches
      log('Inserindo ${matchesToInsert.length} partidas...');
      await _insertInBatches('matches', matchesToInsert);
      totalMatches = matchesToInsert.length;

      // Batch insert of Lineups
      log('Inserindo ${lineupsToInsert.length} escalações de atletas...');
      await _insertInBatches('match_lineups', lineupsToInsert);
      totalLineups = lineupsToInsert.length;

      // Batch insert of Events
      log('Inserindo ${eventsToInsert.length} eventos de partida (gols, assistências, cartões)...');
      await _insertInBatches('match_events', eventsToInsert);
      totalEvents = eventsToInsert.length;

      // Batch insert of Rating History
      log('Inserindo ${ratingsToInsert.length} registros no histórico de ratings...');
      await _insertInBatches('rating_history', ratingsToInsert);
      totalRatings = ratingsToInsert.length;

      log('✅ Migração concluída com sucesso!');

      return MigrationResult(
        success: true,
        groupsCount: totalGroups,
        playersCount: totalPlayers,
        seasonsCount: totalSeasons,
        sessionsCount: totalSessions,
        matchesCount: totalMatches,
        lineupsCount: totalLineups,
        eventsCount: totalEvents,
        ratingsCount: totalRatings,
        logs: logs,
        errors: errors,
      );
    } catch (e, stack) {
      final errorMsg = 'Erro crítico na migração: $e';
      log('❌ $errorMsg');
      debugPrint(stack.toString());
      errors.add(errorMsg);

      return MigrationResult(
        success: false,
        groupsCount: totalGroups,
        playersCount: totalPlayers,
        seasonsCount: totalSeasons,
        sessionsCount: totalSessions,
        matchesCount: totalMatches,
        lineupsCount: totalLineups,
        eventsCount: totalEvents,
        ratingsCount: totalRatings,
        logs: logs,
        errors: errors,
      );
    }
  }

  /// Inserts records in batches, respecting request size limits.
  Future<void> _insertInBatches(
    String table,
    List<Map<String, dynamic>> items, {
    int batchSize = 250,
  }) async {
    for (int i = 0; i < items.length; i += batchSize) {
      final end = (i + batchSize < items.length) ? i + batchSize : items.length;
      final batch = items.sublist(i, end);
      await _client.from(table).insert(batch);
    }
  }
}
