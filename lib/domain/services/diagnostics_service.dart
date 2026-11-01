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

/// Interface para diagnóstico de conectividade e monitoramento de cache.
abstract class DiagnosticsService {
  Future<void> markDirty();
  Future<void> recordCloudSyncSuccess();
  Future<void> recordCloudFetchSuccess();
  Future<Map<String, dynamic>> testSupabaseConnection();
  Future<CacheSyncStatus> getStatus();
  Future<Map<String, String>> getDebugStorageDump();
}
