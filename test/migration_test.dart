import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_do_fut/config/supabase_config.dart';
import 'package:app_do_fut/services/data_migration_service.dart';

class _RealHttpOverrides extends HttpOverrides {}

void main() {
  test('Migração completa do pelada_backup_1789226662128.json para o Supabase', () async {
    HttpOverrides.global = _RealHttpOverrides();
    final client = SupabaseClient(SupabaseConfig.url, SupabaseConfig.anonKey);
    final service = DataMigrationService(client: client);

    final backupFile = File('pelada_backup_1789226662128.json');
    expect(await backupFile.exists(), isTrue, reason: 'Arquivo de backup deve existir');

    final jsonContent = await backupFile.readAsString();

    final result = await service.migrateJsonToSupabase(
      jsonContent: jsonContent,
      onProgress: (msg) => print(msg),
    );

    print('\n==========================================');
    print('RESULTADO DA MIGRAÇÃO:');
    print('Sucesso: ${result.success}');
    print('Grupos inseridos: ${result.groupsCount}');
    print('Jogadores inseridos: ${result.playersCount}');
    print('Temporadas inseridas: ${result.seasonsCount}');
    print('Sessões inseridas: ${result.sessionsCount}');
    print('Partidas inseridas: ${result.matchesCount}');
    print('Escalações inseridas: ${result.escalacoesCount}');
    print('Eventos inseridos: ${result.eventsCount}');
    print('Ratings inseridos: ${result.ratingsCount}');
    print('Total de erros: ${result.errors.length}');
    if (result.errors.isNotEmpty) {
      print('Erros: ${result.errors}');
    }
    print('==========================================\n');

    expect(result.success, isTrue, reason: 'A migração deve ser concluída sem erros');
    expect(result.groupsCount, greaterThan(0));
    expect(result.playersCount, greaterThan(50));
    expect(result.seasonsCount, greaterThan(0));
    expect(result.sessionsCount, equals(24));
    expect(result.matchesCount, greaterThan(400));
    expect(result.escalacoesCount, greaterThan(1000));
    expect(result.eventsCount, greaterThan(500));
    expect(result.ratingsCount, greaterThan(1000));
  }, timeout: const Timeout(Duration(minutes: 5)));
}
