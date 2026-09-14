import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

/// Serviço pontual para corrigir o campo `tempo` nos eventos
/// já migrados para o Supabase que estavam sem o horário do evento.
class FixEventTimesService {
  final SupabaseClient _client;

  FixEventTimesService({SupabaseClient? client})
      : _client = client ?? SupabaseConfig.client;

  Future<Map<String, dynamic>> run({
    required String backupJsonPath,
    void Function(String)? onProgress,
  }) async {
    int updated = 0;
    int skipped = 0;
    final List<String> errors = [];

    void log(String msg) {
      debugPrint('[FIX_TEMPO] \$msg');
      onProgress?.call(msg);
    }

    try {
      log('Lendo arquivo de backup...');
      final file = File(backupJsonPath);
      if (!await file.exists()) {
        throw Exception('Arquivo não encontrado: \$backupJsonPath');
      }

      final Map<String, dynamic> rawData = jsonDecode(await file.readAsString());
      log('Backup carregado.');

      // Monta índice: timestamp (yyyy-MM-ddTHH:mm) -> lista de eventos do backup
      final Map<String, List<Map<String, dynamic>>> backupEventsByDate = {};

      for (final key in rawData.keys) {
        if (!key.startsWith('match_history_')) continue;
        final mData = rawData[key];
        final List<dynamic> matches = mData is String ? jsonDecode(mData) : mData;

        for (final m in matches) {
          final String? rawDate = m['date']?.toString();
          if (rawDate == null) continue;
          final DateTime? dt = DateTime.tryParse(rawDate);
          if (dt == null) continue;

          final tsKey = dt.toIso8601String().substring(0, 16);
          final events = (m['events'] as List<dynamic>? ?? [])
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          if (events.isNotEmpty) {
            backupEventsByDate[tsKey] = events;
          }
        }
      }

      log('Índice de \${backupEventsByDate.length} partidas do backup montado.');

      // Busca todas as partidas com seus eventos
      log('Buscando partidas no Supabase...');
      final response = await _client
          .from('partidas')
          .select('id, timestamp, eventos_partida(id, tipo, time, jogador_id, tempo)');

      final List<dynamic> partidas = response as List;
      log('\${partidas.length} partidas encontradas no Supabase.');

      for (final partida in partidas) {
        final String partidaId = partida['id']?.toString() ?? '';
        final String? rawTs = partida['timestamp']?.toString();
        if (rawTs == null) continue;

        final DateTime? dt = DateTime.tryParse(rawTs);
        if (dt == null) continue;

        final String tsKey = dt.toIso8601String().substring(0, 16);
        final List<Map<String, dynamic>>? backupEvents = backupEventsByDate[tsKey];

        if (backupEvents == null || backupEvents.isEmpty) {
          skipped++;
          continue;
        }

        final List<dynamic> supabaseEvents = partida['eventos_partida'] as List? ?? [];
        final eventsWithoutTempo = supabaseEvents
            .whereType<Map>()
            .where((e) => e['tempo'] == null || e['tempo'].toString().isEmpty)
            .toList();

        if (eventsWithoutTempo.isEmpty) {
          skipped++;
          continue;
        }

        // Indexadores por tipo para casar eventos na ordem certa
        final Map<String, int> redIdx = {};
        final Map<String, int> whiteIdx = {};

        final redBackup = backupEvents.where((e) {
          final t = e['team']?.toString().toLowerCase() ?? '';
          return t.contains('verm') || t == 'red';
        }).toList();
        final whiteBackup = backupEvents.where((e) {
          final t = e['team']?.toString().toLowerCase() ?? '';
          return !t.contains('verm') && t != 'red';
        }).toList();

        for (final ev in eventsWithoutTempo) {
          final String evId = ev['id']?.toString() ?? '';
          final String evTipo = ev['tipo']?.toString() ?? '';
          final bool isRed = ev['time']?.toString() == 'red';

          final pool = isRed ? redBackup : whiteBackup;
          final idxMap = isRed ? redIdx : whiteIdx;

          int start = idxMap[evTipo] ?? 0;
          String? matchedTime;

          for (int i = start; i < pool.length; i++) {
            if (pool[i]['type']?.toString() == evTipo) {
              matchedTime = pool[i]['time']?.toString();
              idxMap[evTipo] = i + 1;
              break;
            }
          }

          if (matchedTime != null && matchedTime.isNotEmpty) {
            try {
              await _client
                  .from('eventos_partida')
                  .update({'tempo': matchedTime})
                  .eq('id', int.parse(evId));
              updated++;
              log('Evento \$evId atualizado: tempo=\$matchedTime');
            } catch (e) {
              errors.add('Erro ao atualizar evento \$evId: \$e');
            }
          }
        }
      }

      log('✅ Concluído! \$updated eventos atualizados, \$skipped partidas sem alteração.');
    } catch (e, stack) {
      final msg = 'Erro: \$e';
      log('❌ \$msg');
      debugPrint(stack.toString());
      errors.add(msg);
    }

    return {'updated': updated, 'skipped': skipped, 'errors': errors};
  }
}
