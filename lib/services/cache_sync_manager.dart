import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class CacheSyncStatus {
  final bool isSupabaseConnected;
  final int? pingMs;
  final String? connectionError;
  final bool hasPendingChanges;
  final DateTime? lastCloudSyncAt;
  final DateTime? lastCloudFetchAt;
  final int localKeysCount;

  CacheSyncStatus({
    required this.isSupabaseConnected,
    this.pingMs,
    this.connectionError,
    required this.hasPendingChanges,
    this.lastCloudSyncAt,
    this.lastCloudFetchAt,
    required this.localKeysCount,
  });
}

class CacheSyncManager {
  static final CacheSyncManager _instance = CacheSyncManager._internal();
  factory CacheSyncManager() => _instance;
  CacheSyncManager._internal();

  static const String keyHasPendingChanges = 'cache_has_pending_cloud_sync';
  static const String keyLastCloudSyncAt = 'cache_last_cloud_sync_at';
  static const String keyLastCloudFetchAt = 'cache_last_cloud_fetch_at';

  final SupabaseClient _supabase = SupabaseConfig.client;

  /// Marks that there are local changes pending upload to Supabase
  Future<void> markDirty() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyHasPendingChanges, true);
  }

  /// Records that the sync to the cloud completed successfully
  Future<void> recordCloudSyncSuccess() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyHasPendingChanges, false);
    await prefs.setString(keyLastCloudSyncAt, DateTime.now().toIso8601String());
  }

  /// Registra que os dados foram baixados da nuvem com sucesso
  Future<void> recordCloudFetchSuccess() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyHasPendingChanges, false);
    await prefs.setString(keyLastCloudFetchAt, DateTime.now().toIso8601String());
  }

  /// Tests connectivity with Supabase and measures latency
  Future<Map<String, dynamic>> testSupabaseConnection() async {
    final stopwatch = Stopwatch()..start();
    try {
      // Teste leve consultando tabela sync_data ou groups
      await _supabase.from('sync_data').select('sync_code').limit(1);
      stopwatch.stop();
      return {
        'connected': true,
        'ping': stopwatch.elapsedMilliseconds,
        'error': null,
      };
    } catch (e) {
      stopwatch.stop();
      return {
        'connected': false,
        'ping': null,
        'error': e.toString(),
      };
    }
  }

  /// Gets the full connection and cache status
  Future<CacheSyncStatus> getStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final connectionTest = await testSupabaseConnection();

    final hasPending = prefs.getBool(keyHasPendingChanges) ?? false;
    final lastSyncStr = prefs.getString(keyLastCloudSyncAt);
    final lastFetchStr = prefs.getString(keyLastCloudFetchAt);

    return CacheSyncStatus(
      isSupabaseConnected: connectionTest['connected'] as bool,
      pingMs: connectionTest['ping'] as int?,
      connectionError: connectionTest['error'] as String?,
      hasPendingChanges: hasPending,
      lastCloudSyncAt: lastSyncStr != null ? DateTime.tryParse(lastSyncStr) : null,
      lastCloudFetchAt: lastFetchStr != null ? DateTime.tryParse(lastFetchStr) : null,
      localKeysCount: prefs.getKeys().length,
    );
  }

  /// Retorna todas as chaves e resumos para o painel de debug
  Future<Map<String, String>> getDebugStorageDump() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    final Map<String, String> dump = {};

    for (String key in keys) {
      final val = prefs.get(key);
      if (val is String && val.length > 120) {
        dump[key] = '${val.substring(0, 120)}... (${val.length} caracteres)';
      } else {
        dump[key] = val.toString();
      }
    }
    return dump;
  }
}
