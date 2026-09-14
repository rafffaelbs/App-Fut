import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import '../services/cache_sync_manager.dart';
import '../services/sync_service.dart';

class AdminDebugScreen extends StatefulWidget {
  final String groupId;

  const AdminDebugScreen({
    super.key,
    required this.groupId,
  });

  @override
  State<AdminDebugScreen> createState() => _AdminDebugScreenState();
}

class _AdminDebugScreenState extends State<AdminDebugScreen> {
  final CacheSyncManager _cacheSyncManager = CacheSyncManager();
  final SyncService _syncService = SyncService();

  bool _isLoading = true;
  bool _isActionRunning = false;
  CacheSyncStatus? _status;
  Map<String, String> _storageDump = {};
  String _syncCode = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final status = await _cacheSyncManager.getStatus();
    final dump = await _cacheSyncManager.getDebugStorageDump();
    final code = await _syncService.getOrCreateSyncCode();

    if (mounted) {
      setState(() {
        _status = status;
        _storageDump = dump;
        _syncCode = code;
        _isLoading = false;
      });
    }
  }

  Future<void> _forceUpload() async {
    setState(() => _isActionRunning = true);
    try {
      await _syncService.exportDataToSupabase(_syncCode);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cache local sincronizado com a nuvem (Supabase) com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao enviar dados para a nuvem: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      await _loadData();
      if (mounted) setState(() => _isActionRunning = false);
    }
  }

  Future<void> _forceDownload() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.headerBlue,
        title: const Text('Baixar dados da Nuvem', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Isso substituirá todos os dados do SharedPreferences local pelos dados salvos no Supabase. Deseja continuar?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.highlightGreen),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Baixar e Substituir', style: TextStyle(color: AppColors.deepBlue)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isActionRunning = true);
    try {
      await _syncService.importDataFromSupabase(_syncCode);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dados importados com sucesso da nuvem!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao baixar dados: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      await _loadData();
      if (mounted) setState(() => _isActionRunning = false);
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'Nunca sincronizado';
    final formatter = DateFormat('dd/MM/yyyy HH:mm:ss');
    return formatter.format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepBlue,
      appBar: AppBar(
        backgroundColor: AppColors.headerBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Admin & Debug de Cache',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Atualizar Status',
            onPressed: _isLoading || _isActionRunning ? null : _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.highlightGreen))
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSupabaseConnectionCard(),
                  const SizedBox(height: 16),
                  _buildCacheStatusCard(),
                  const SizedBox(height: 16),
                  _buildSyncActionsCard(),
                  const SizedBox(height: 16),
                  _buildStorageInspectorCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildSupabaseConnectionCard() {
    final isOnline = _status?.isSupabaseConnected ?? false;
    final ping = _status?.pingMs;
    final error = _status?.connectionError;

    return Card(
      color: AppColors.headerBlue.withOpacity(0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isOnline ? Colors.green.withOpacity(0.5) : Colors.red.withOpacity(0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isOnline ? Icons.cloud_done : Icons.cloud_off,
                  color: isOnline ? Colors.greenAccent : Colors.redAccent,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Conectividade Supabase',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isOnline ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isOnline ? 'ONLINE' : 'OFFLINE',
                    style: TextStyle(
                      color: isOnline ? Colors.greenAccent : Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Sync Code Ativo: $_syncCode',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            if (ping != null) ...[
              const SizedBox(height: 4),
              Text(
                'Latência (Ping): ${ping}ms',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
            if (error != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Erro de conexão: $error',
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCacheStatusCard() {
    final hasPending = _status?.hasPendingChanges ?? false;
    final lastSync = _status?.lastCloudSyncAt;
    final lastFetch = _status?.lastCloudFetchAt;
    final totalKeys = _status?.localKeysCount ?? 0;

    return Card(
      color: AppColors.headerBlue.withOpacity(0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.storage, color: AppColors.highlightGreen),
                const SizedBox(width: 8),
                const Text(
                  'Status do Cache (SharedPreferences)',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(color: Colors.white12, height: 24),
            Row(
              children: [
                Icon(
                  hasPending ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                  color: hasPending ? Colors.amberAccent : Colors.greenAccent,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasPending
                        ? 'Existem modificações locais não enviadas para a nuvem.'
                        : 'Cache local 100% atualizado com o Supabase.',
                    style: TextStyle(
                      color: hasPending ? Colors.amberAccent : Colors.greenAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Último envio para a nuvem (Push):', _formatDate(lastSync)),
            const SizedBox(height: 6),
            _buildInfoRow('Último download da nuvem (Pull):', _formatDate(lastFetch)),
            const SizedBox(height: 6),
            _buildInfoRow('Total de chaves no SharedPreferences:', '$totalKeys chaves salvas'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildSyncActionsCard() {
    return Card(
      color: AppColors.headerBlue.withOpacity(0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ações de Sincronização Manual',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.highlightGreen,
                      foregroundColor: AppColors.deepBlue,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: _isActionRunning
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.deepBlue),
                          )
                        : const Icon(Icons.cloud_upload),
                    label: const Text('Subir Cache', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: _isActionRunning ? null : _forceUpload,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white54),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.cloud_download),
                    label: const Text('Baixar Nuvem'),
                    onPressed: _isActionRunning ? null : _forceDownload,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStorageInspectorCard() {
    return Card(
      color: AppColors.headerBlue.withOpacity(0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        iconColor: AppColors.highlightGreen,
        collapsedIconColor: Colors.white70,
        title: Text(
          'Inspetor de Dados (${_storageDump.length} Chaves)',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: const Text(
          'Toque para inspecionar os valores salvos no SharedPreferences',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        children: [
          Container(
            constraints: const BoxConstraints(maxHeight: 350),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _storageDump.entries.length,
              separatorBuilder: (_, __) => const Divider(color: Colors.white10),
              itemBuilder: (context, index) {
                final entry = _storageDump.entries.elementAt(index);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.key,
                        style: const TextStyle(
                          color: AppColors.highlightGreen,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        entry.value,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
