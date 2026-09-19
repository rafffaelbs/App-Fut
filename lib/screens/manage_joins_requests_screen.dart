import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/player_model.dart';
import '../repositories/supabase_service.dart';

class ManageJoinRequestsScreen extends StatefulWidget {
  final String groupId;

  const ManageJoinRequestsScreen({super.key, required this.groupId});

  @override
  State<ManageJoinRequestsScreen> createState() => _ManageJoinRequestsScreenState();
}

class _ManageJoinRequestsScreenState extends State<ManageJoinRequestsScreen> {
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final data = await SupabaseService.instance.groupMembers.listPendingRequests(widget.groupId);
      if (mounted) setState(() => _requests = data);
    } catch (e) {
      debugPrint('Error loading join requests: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Aprova a solicitação. Se [existingPlayerId] for informado, a conta do
  /// solicitante é vinculada a esse jogador já existente (ex: um jogador
  /// "fantasma" cadastrado manualmente antes de ele ter login) em vez de
  /// criar um jogador novo do zero.
  Future<void> _approve(Map<String, dynamic> request, {String? existingPlayerId}) async {
    try {
      await SupabaseService.instance.groupMembers.approveRequest(
        request['id'].toString(),
        existingPlayerId: existingPlayerId,
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${request['requested_name']} agora faz parte do grupo.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _reject(Map<String, dynamic> request) async {
    try {
      await SupabaseService.instance.groupMembers.rejectRequest(request['id'].toString());
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  /// Pergunta ao admin se quer criar um perfil novo pro solicitante ou
  /// vincular a solicitação a um jogador já existente no grupo (sem login).
  Future<void> _openApproveOptions(Map<String, dynamic> request) async {
    List<PlayerModel> ghostPlayers = [];
    try {
      final allPlayers = await SupabaseService.instance.players.getPlayersByGroup(widget.groupId);
      ghostPlayers = allPlayers.where((p) => p.isGhost).toList();
    } catch (e) {
      debugPrint('Error loading players for linking: $e');
    }

    if (!mounted) return;

    final requestedName = (request['requested_name'] ?? '').toString();

    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.headerBlue,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aprovar "$requestedName"',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Crie um perfil novo ou vincule a um jogador que já existe no elenco (sem login), pra não perder o histórico e as estatísticas dele.',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.accentBlue,
                    child: Icon(Icons.person_add, color: Colors.white),
                  ),
                  title: const Text('Criar perfil novo', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _approve(request);
                  },
                ),
                if (ghostPlayers.isNotEmpty) ...[
                  const Divider(color: Colors.white24, height: 24),
                  const Text(
                    'Ou vincular a um jogador existente:',
                    style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 260),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: ghostPlayers.length,
                      itemBuilder: (context, index) {
                        final player = ghostPlayers[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(
                            backgroundColor: AppColors.highlightGreen,
                            child: Icon(Icons.groups, color: AppColors.deepBlue),
                          ),
                          title: Text(player.displayName, style: const TextStyle(color: Colors.white)),
                          subtitle: const Text('Jogador sem login (fantasma)', style: TextStyle(color: Colors.white38, fontSize: 11)),
                          onTap: () {
                            Navigator.pop(sheetContext);
                            _approve(request, existingPlayerId: player.id);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepBlue,
      appBar: AppBar(
        backgroundColor: AppColors.headerBlue,
        title: const Text('Solicitações de entrada', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accentBlue))
          : _requests.isEmpty
              ? const Center(
                  child: Text('Nenhuma solicitação pendente.', style: TextStyle(color: Colors.white54)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _requests.length,
                  itemBuilder: (context, index) {
                    final req = _requests[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.headerBlue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: AppColors.accentBlue,
                            child: Icon(Icons.person, color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              (req['requested_name'] ?? '').toString(),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.check_circle, color: AppColors.highlightGreen),
                            tooltip: 'Aprovar',
                            onPressed: () => _openApproveOptions(req),
                          ),
                          IconButton(
                            icon: const Icon(Icons.cancel, color: Colors.redAccent),
                            tooltip: 'Rejeitar',
                            onPressed: () => _reject(req),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
