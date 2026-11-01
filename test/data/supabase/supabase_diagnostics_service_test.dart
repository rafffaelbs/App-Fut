import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_do_fut/data/supabase/supabase_diagnostics_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SupabaseDiagnosticsService diagnostics;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    diagnostics = SupabaseDiagnosticsService();
  });

  group('SupabaseDiagnosticsService', () {
    test('markDirty define flag cache_has_pending_cloud_sync como true', () async {
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(SupabaseDiagnosticsService.keyHasPendingChanges), isNull);

      await diagnostics.markDirty();

      expect(prefs.getBool(SupabaseDiagnosticsService.keyHasPendingChanges), isTrue);
    });

    test('recordCloudSyncSuccess define flag como false e atualiza timestamp de sync', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(SupabaseDiagnosticsService.keyHasPendingChanges, true);

      await diagnostics.recordCloudSyncSuccess();

      expect(prefs.getBool(SupabaseDiagnosticsService.keyHasPendingChanges), isFalse);
      expect(prefs.getString(SupabaseDiagnosticsService.keyLastCloudSyncAt), isNotNull);
    });

    test('recordCloudFetchSuccess define flag como false e atualiza timestamp de fetch', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(SupabaseDiagnosticsService.keyHasPendingChanges, true);

      await diagnostics.recordCloudFetchSuccess();

      expect(prefs.getBool(SupabaseDiagnosticsService.keyHasPendingChanges), isFalse);
      expect(prefs.getString(SupabaseDiagnosticsService.keyLastCloudFetchAt), isNotNull);
    });

    test('getDebugStorageDump retorna todas as chaves com valores truncados quando > 120 caracteres', () async {
      final longValue = 'a' * 150;
      SharedPreferences.setMockInitialValues({
        'short_key': 'small_value',
        'long_key': longValue,
      });

      final dump = await diagnostics.getDebugStorageDump();

      expect(dump['short_key'], 'small_value');
      expect(dump['long_key'], contains('... (150 caracteres)'));
      expect(dump['long_key']!.length, lessThan(160));
    });

    test('getStatus retorna contagem correta e datas parseadas', () async {
      final nowStr = DateTime.now().toIso8601String();
      SharedPreferences.setMockInitialValues({
        SupabaseDiagnosticsService.keyHasPendingChanges: true,
        SupabaseDiagnosticsService.keyLastCloudSyncAt: nowStr,
        SupabaseDiagnosticsService.keyLastCloudFetchAt: nowStr,
        'extra_key': '123',
      });

      final status = await diagnostics.getStatus();

      expect(status.hasPendingChanges, isTrue);
      expect(status.lastCloudSyncAt, isNotNull);
      expect(status.lastCloudFetchAt, isNotNull);
      expect(status.localKeysCount, 4);
    });

    test('testSupabaseConnection trata erro sem crashar quando não há conexão ativa', () async {
      final result = await diagnostics.testSupabaseConnection();

      expect(result['connected'], isFalse);
      expect(result['ping'], isNull);
      expect(result['error'], isNotNull);
    });
  });
}
