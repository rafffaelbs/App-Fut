import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../config/supabase_config.dart';

/// Resultado detalhado da execução da migração de dados para o Supabase.
class MigrationResult {
  final bool success;
  final int groupsCount;
  final int playersCount;
  final int seasonsCount;
  final int sessionsCount;
  final int matchesCount;
  final int escalacoesCount;
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
    this.escalacoesCount = 0,
    this.eventsCount = 0,
    this.ratingsCount = 0,
    this.logs = const [],
    this.errors = const [],
  });

  @override
  String toString() {
    return 'MigrationResult(success: $success, grupos: $groupsCount, jogadores: $playersCount, temporadas: $seasonsCount, sessoes: $sessionsCount, partidas: $matchesCount, escalacoes: $escalacoesCount, eventos: $eventsCount, ratings: $ratingsCount, erros: ${errors.length})';
  }
}

/// Serviço responsável por orquestrar a migração dos dados locais (JSON/SharedPreferences)
/// para as tabelas relacionais do Supabase PostgreSQL.
class DataMigrationService {
  static const Uuid _uuid = Uuid();
  final SupabaseClient _client;

  DataMigrationService({SupabaseClient? client})
      : _client = client ?? SupabaseConfig.client;

  /// Função principal de migração.
  ///
  /// Pode receber [jsonContent] explicitamente (como string do backup), ou buscar do arquivo
  /// `pelada_backup_1789226662128.json` local ou das chaves do [SharedPreferences].
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
    int totalEscalacoes = 0;
    int totalEvents = 0;
    int totalRatings = 0;

    try {
      // 1. Obtenção do Map de dados
      Map<String, dynamic> rawData = {};
      if (jsonContent != null && jsonContent.trim().isNotEmpty) {
        rawData = jsonDecode(jsonContent);
        log('Dados carregados a partir da string JSON fornecida.');
      } else {
        // Tenta ler o arquivo de backup local no disco
        final backupFile = File('pelada_backup_1789226662128.json');
        if (await backupFile.exists()) {
          final content = await backupFile.readAsString();
          rawData = jsonDecode(content);
          log('Dados carregados do arquivo local pelada_backup_1789226662128.json.');
        } else {
          // Fallback para SharedPreferences
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

      // 2. Extração de Grupos
      List<dynamic> groupsList = [];
      if (rawData.containsKey('app_groups')) {
        final gData = rawData['app_groups'];
        groupsList = gData is String ? jsonDecode(gData) : gData;
      }

      if (groupsList.isEmpty) {
        // Fallback: Grupo padrão
        groupsList = [
          {
            'id': 'grupo_1773427387405',
            'name': 'Fut do INF',
            'createdAt': DateTime.now().toIso8601String(),
          }
        ];
      }

      log('Encontrados ${groupsList.length} grupo(s) para migração.');

      // Map para converter legacyGroupId -> newGroupUuid
      final Map<String, String> groupMapping = {};

      for (final g in groupsList) {
        final String legacyId = g['id']?.toString() ?? 'grupo_padrao';
        final String groupName = g['name']?.toString().trim() ?? 'Meu Grupo';
        final String groupUuid = _uuid.v4();
        groupMapping[legacyId] = groupUuid;

        log('Inserindo grupo: "$groupName" com UUID: $groupUuid');
        await _client.from('grupos').insert({
          'id': groupUuid,
          'nome': groupName,
          'criador_id': null,
          'created_at': g['createdAt'] ?? DateTime.now().toIso8601String(),
        });
        totalGroups++;
      }

      // Grupo primário para associar dados caso não haja chave específica
      final String primaryGroupUuid = groupMapping.values.first;

      // 3. Extração e Inserção de Jogadores
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
              'user_id': null,
              'nome': (p['name']?.toString().trim() ?? 'Jogador').isNotEmpty
                  ? p['name'].toString().trim()
                  : 'Jogador',
              'avatar_url': p['icon']?.toString(),
              'badges': p['manual_badges'] ?? [],
            });

            membersToInsert.add({
              'id': _uuid.v4(),
              'grupo_id': targetGroupUuid,
              'jogador_id': pId,
              'papel': 'membro',
            });
          }
        }
      }

      // 4. Varrer Partidas para identificar jogadores não listados na lista base (para evitar quebra de FK)
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

      // Adiciona jogadores recuperados das partidas
      for (final entry in missingPlayerNames.entries) {
        if (!registeredPlayerIds.contains(entry.key)) {
          registeredPlayerIds.add(entry.key);
          playersToInsert.add({
            'id': entry.key,
            'user_id': null,
            'nome': entry.value,
            'avatar_url': null,
            'badges': [],
          });
          membersToInsert.add({
            'id': _uuid.v4(),
            'grupo_id': primaryGroupUuid,
            'jogador_id': entry.key,
            'papel': 'membro',
          });
          log('Jogador recuperado de partidas: "${entry.value}" (${entry.key})');
        }
      }

      // Inserção em lote de jogadores
      if (playersToInsert.isNotEmpty) {
        log('Inserindo ${playersToInsert.length} jogadores em lote na tabela "jogadores"...');
        await _insertInBatches('jogadores', playersToInsert);
        totalPlayers = playersToInsert.length;
      }

      // Inserção em lote de membros_grupo
      if (membersToInsert.isNotEmpty) {
        log('Inserindo ${membersToInsert.length} registros em "membros_grupo"...');
        await _insertInBatches('membros_grupo', membersToInsert);
      }

      // 5. Extração e Inserção de Temporadas
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
              'grupo_id': targetGroupUuid,
              'nome': sName,
              'data_inicio': startStr != null ? DateTime.tryParse(startStr)?.toIso8601String().substring(0, 10) : null,
              'data_fim': endStr != null ? DateTime.tryParse(endStr)?.toIso8601String().substring(0, 10) : null,
              'is_atual': sName.contains('2026.2'),
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
        // Cria temporada padrão caso não haja no backup
        final defaultSeasonId = _uuid.v4();
        seasonsToInsert.add({
          'id': defaultSeasonId,
          'grupo_id': primaryGroupUuid,
          'nome': 'Temporada 1',
          'data_inicio': '2026-01-01',
          'data_fim': '2026-12-31',
          'is_atual': true,
        });
        parsedSeasons.add({
          'id': defaultSeasonId,
          'name': 'Temporada 1',
          'start': DateTime(2026, 1, 1),
          'end': DateTime(2026, 12, 31),
        });
      }

      log('Inserindo ${seasonsToInsert.length} temporadas em lote...');
      await _insertInBatches('temporadas', seasonsToInsert);
      totalSeasons = seasonsToInsert.length;

      // 6. Extração e Inserção de Sessões (Peladas)
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

            // Determina a data e a temporada correspondente
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
              'temporada_id': matchedSeasonId,
              'titulo': sess['title']?.toString() ?? 'Pelada',
              'timestamp': sessDate.toIso8601String(),
              'status': 'finalizada',
              'duracao_minutos': int.tryParse(sess['duration']?.toString() ?? '8') ?? 8,
              'win_limit': int.tryParse(sess['win_limit']?.toString() ?? '3') ?? 3,
            });
          }
        }
      }

      log('Inserindo ${sessionsToInsert.length} sessões de pelada em lote...');
      await _insertInBatches('sessoes', sessionsToInsert);
      totalSessions = sessionsToInsert.length;

      // 7. Extração e Inserção de Partidas, Escalações, Eventos e Histórico de Ratings
      final List<Map<String, dynamic>> matchesToInsert = [];
      final List<Map<String, dynamic>> escalacoesToInsert = [];
      final List<Map<String, dynamic>> eventosToInsert = [];
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

            int duracaoSeg = 480;
            if (m['match_duration'] != null) {
              final parts = m['match_duration'].toString().split(':');
              if (parts.length == 2) {
                final min = int.tryParse(parts[0]) ?? 8;
                final sec = int.tryParse(parts[1]) ?? 0;
                duracaoSeg = min * 60 + sec;
              }
            }

            matchesToInsert.add({
              'id': matchUuid,
              'sessao_id': newSessUuid,
              'timestamp': matchDate.toIso8601String(),
              'score_red': int.tryParse(m['scoreRed']?.toString() ?? '0') ?? 0,
              'score_white': int.tryParse(m['scoreWhite']?.toString() ?? '0') ?? 0,
              'duracao_segundos': duracaoSeg,
            });

            // Escalação e Ratings
            final pObj = m['players'] as Map<String, dynamic>? ?? {};

            void processTeamPlayers(String side, bool isGk, dynamic playerOrList) {
              if (playerOrList == null) return;
              final list = playerOrList is List ? playerOrList : [playerOrList];
              for (final pl in list) {
                if (pl is Map) {
                  final pId = pl['id']?.toString();
                  if (pId != null && registeredPlayerIds.contains(pId)) {
                    final double rating = double.tryParse(pl['rating']?.toString() ?? '6.0') ?? 6.0;

                    escalacoesToInsert.add({
                      'partida_id': matchUuid,
                      'jogador_id': pId,
                      'time': side,
                      'is_goleiro': isGk,
                      'nota_partida': rating,
                    });

                    ratingsToInsert.add({
                      'jogador_id': pId,
                      'partida_id': matchUuid,
                      'temporada_id': seasonId,
                      'rating_resultante': rating,
                      'is_goleiro': isGk,
                      'timestamp': matchDate.toIso8601String(),
                    });
                  }
                }
              }
            }

            processTeamPlayers('red', false, pObj['red']);
            processTeamPlayers('white', false, pObj['white']);
            processTeamPlayers('red', true, pObj['gk_red']);
            processTeamPlayers('white', true, pObj['gk_white']);

            // Eventos
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

                  eventosToInsert.add({
                    'partida_id': matchUuid,
                    'jogador_id': pId,
                    'assist_jogador_id': astId,
                    'tipo': ev['type']?.toString() ?? 'goal',
                    'time': side,
                    'tempo': ev['time']?.toString(), // ex: "08:25"
                  });
                }
              }
            }
          }
        }
      }

      // Inserção em lote de Partidas
      log('Inserindo ${matchesToInsert.length} partidas...');
      await _insertInBatches('partidas', matchesToInsert);
      totalMatches = matchesToInsert.length;

      // Inserção em lote de Escalações
      log('Inserindo ${escalacoesToInsert.length} escalações de atletas...');
      await _insertInBatches('escalacao_partida', escalacoesToInsert);
      totalEscalacoes = escalacoesToInsert.length;

      // Inserção em lote de Eventos
      log('Inserindo ${eventosToInsert.length} eventos de partida (gols, assistências, cartões)...');
      await _insertInBatches('eventos_partida', eventosToInsert);
      totalEvents = eventosToInsert.length;

      // Inserção em lote de Histórico de Ratings
      log('Inserindo ${ratingsToInsert.length} registros no histórico de ratings...');
      await _insertInBatches('historico_ratings', ratingsToInsert);
      totalRatings = ratingsToInsert.length;

      log('✅ Migração concluída com sucesso!');

      return MigrationResult(
        success: true,
        groupsCount: totalGroups,
        playersCount: totalPlayers,
        seasonsCount: totalSeasons,
        sessionsCount: totalSessions,
        matchesCount: totalMatches,
        escalacoesCount: totalEscalacoes,
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
        escalacoesCount: totalEscalacoes,
        eventsCount: totalEvents,
        ratingsCount: totalRatings,
        logs: logs,
        errors: errors,
      );
    }
  }

  /// Insere registros em lote respeitando limites de tamanho de requisição.
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
