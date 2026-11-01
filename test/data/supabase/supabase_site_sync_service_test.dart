import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_do_fut/data/supabase/supabase_site_sync_service.dart';
import 'package:app_do_fut/domain/services/diagnostics_service.dart';

class FakeDiagnosticsService implements DiagnosticsService {
  int recordCloudSyncSuccessCount = 0;
  int recordCloudFetchSuccessCount = 0;
  int markDirtyCount = 0;

  @override
  Future<void> markDirty() async {
    markDirtyCount++;
  }

  @override
  Future<void> recordCloudSyncSuccess() async {
    recordCloudSyncSuccessCount++;
  }

  @override
  Future<void> recordCloudFetchSuccess() async {
    recordCloudFetchSuccessCount++;
  }

  @override
  Future<Map<String, dynamic>> testSupabaseConnection() async => {'connected': true};

  @override
  Future<CacheSyncStatus> getStatus() async => CacheSyncStatus(
        isSupabaseConnected: true,
        hasPendingChanges: false,
        localKeysCount: 0,
      );

  @override
  Future<Map<String, String>> getDebugStorageDump() async => {};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeDiagnosticsService fakeDiagnostics;
  late SupabaseSiteSyncService siteSync;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fakeDiagnostics = FakeDiagnosticsService();
    siteSync = SupabaseSiteSyncService(
      diagnosticsService: fakeDiagnostics,
    );
  });

  group('SupabaseSiteSyncService', () {
    test('getOrCreateSyncCode retorna código existente de my_sync_code se presente', () async {
      SharedPreferences.setMockInitialValues({
        'my_sync_code': 'SNC9999',
      });

      final code = await siteSync.getOrCreateSyncCode();

      expect(code, 'SNC9999');
    });

    test('getOrCreateSyncCode gera novo código SNC e salva no SharedPreferences', () async {
      final code = await siteSync.getOrCreateSyncCode();

      expect(code.startsWith('SNC'), isTrue);
      expect(code.length, 7);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('my_sync_code'), code);
    });

    test('getOrCreateSyncCode utiliza cache em memória após a primeira chamada', () async {
      final code1 = await siteSync.getOrCreateSyncCode();

      // Altera o SharedPreferences por fora para provar que usa o cache em memória
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('my_sync_code', 'SNC_OUTRO');

      final code2 = await siteSync.getOrCreateSyncCode();
      expect(code2, code1);
    });
  });
}
