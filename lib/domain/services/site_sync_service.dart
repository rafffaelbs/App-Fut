/// Interface para o serviço de envio do "pacote do site" para a tabela sync_data.
abstract class SiteSyncService {
  Future<String> getOrCreateSyncCode();
  Future<void> exportDataToSupabase(String syncCode);
}
