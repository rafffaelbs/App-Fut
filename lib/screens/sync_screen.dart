import 'package:flutter/material.dart';
import 'package:app_do_fut/constants/app_colors.dart';
import 'package:app_do_fut/services/sync_service.dart';

class SyncScreen extends StatefulWidget {
  const SyncScreen({Key? key}) : super(key: key);

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  final SyncService _syncService = SyncService();
  final TextEditingController _codeController = TextEditingController();

  String? _mySyncCode;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadMyCode();
  }

  Future<void> _loadMyCode() async {
    final code = await _syncService.getOrCreateSyncCode();
    setState(() {
      _mySyncCode = code;
    });
  }

  Future<void> _exportData() async {
    if (_mySyncCode == null) return;
    setState(() => _isLoading = true);
    
    try {
      await _syncService.exportDataToFirebase(_mySyncCode!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Backup realizado com sucesso na nuvem!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erro ao fazer backup: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _importData() async {
    final codeToImport = _codeController.text.trim();
    if (codeToImport.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Digite o código de sincronização"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Confirm dialog
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.headerBlue,
        title: const Text("Restaurar Dados?", style: TextStyle(color: Colors.white)),
        content: const Text(
          "Aviso: Isso apagará todos os seus dados locais e carregará os dados da nuvem. Deseja continuar?",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("CANCELAR", style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("RESTAURAR", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    setState(() => _isLoading = true);

    try {
      await _syncService.importDataFromFirebase(codeToImport);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Dados restaurados com sucesso! Feche e abra o app novamente se necessário."),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
        _codeController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erro ao restaurar: $e"),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepBlue,
      appBar: AppBar(
        title: const Text("Sincronização na Nuvem", style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.headerBlue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accentBlue))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.cloud_sync, size: 80, color: AppColors.accentBlue),
                  const SizedBox(height: 24),
                  
                  // Bloco de Backup
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.headerBlue,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.accentBlue.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          "FAZER BACKUP",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          "Seu Código de Sincronização:",
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          _mySyncCode ?? "Carregando...",
                          style: const TextStyle(
                            color: AppColors.accentBlue,
                            fontWeight: FontWeight.bold,
                            fontSize: 32,
                            letterSpacing: 4.0,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Anote este código. Você precisará dele para carregar seus dados em outro dispositivo.",
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _mySyncCode == null ? null : _exportData,
                          icon: const Icon(Icons.cloud_upload, color: Colors.white),
                          label: const Text("ENVIAR PARA NUVEM", style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentBlue,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Bloco de Restore
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.headerBlue,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          "RESTAURAR DA NUVEM",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          "Tem um código de outro dispositivo? Digite abaixo para baixar os dados para cá.",
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _codeController,
                          style: const TextStyle(
                            color: Colors.white, 
                            fontSize: 24, 
                            fontWeight: FontWeight.bold, 
                            letterSpacing: 2.0
                          ),
                          textAlign: TextAlign.center,
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            hintText: "SNC1234",
                            hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
                            filled: true,
                            fillColor: Colors.black12,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _importData,
                          icon: const Icon(Icons.cloud_download, color: Colors.white),
                          label: const Text("BAIXAR DA NUVEM", style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade700,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
