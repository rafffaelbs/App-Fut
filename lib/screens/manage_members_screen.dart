import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/group_member_model.dart';
import '../repositories/supabase_service.dart';

/// Tela para o admin ver todos os membros do grupo e promover/rebaixar
/// entre "admin" e "member". A validação de permissão real é feita pelo
/// RLS no Supabase (ver GroupMembersRepository.promoteToAdmin/demoteToMember);
/// esta tela só evita mostrar os controles pra quem não é admin.
class ManageMembersScreen extends StatefulWidget {
  final String groupId;

  const ManageMembersScreen({super.key, required this.groupId});

  @override
  State<ManageMembersScreen> createState() => _ManageMembersScreenState();
}

class _ManageMembersScreenState extends State<ManageMembersScreen> {
  List<GroupMemberModel> _members = [];
  bool _isLoading = true;
  String? _currentUserPlayerId;
  final Set<String> _updating = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final members = await SupabaseService.instance.groupMembers.getMembers(widget.groupId);
      final myMembership = await SupabaseService.instance.groupMembers.getMyMembership(widget.groupId);
      if (mounted) {
        setState(() {
          _members = members;
          _currentUserPlayerId = myMembership?.playerId;
        });
      }
    } catch (e) {
      debugPrint('Error loading members: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar membros: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleAdmin(GroupMemberModel member) async {
    setState(() => _updating.add(member.playerId));
    try {
      if (member.isAdmin) {
        await SupabaseService.instance.groupMembers.demoteToMember(
          groupId: widget.groupId,
          playerId: member.playerId,
        );
      } else {
        await SupabaseService.instance.groupMembers.promoteToAdmin(
          groupId: widget.groupId,
          playerId: member.playerId,
        );
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _updating.remove(member.playerId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepBlue,
      appBar: AppBar(
        backgroundColor: AppColors.headerBlue,
        title: const Text('Gerenciar Membros', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accentBlue))
          : _members.isEmpty
              ? const Center(
                  child: Text('Nenhum membro encontrado.', style: TextStyle(color: Colors.white54)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _members.length,
                  itemBuilder: (context, index) {
                    final member = _members[index];
                    final isSelf = member.playerId == _currentUserPlayerId;
                    final isUpdating = _updating.contains(member.playerId);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.headerBlue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: member.isAdmin ? AppColors.highlightGreen : AppColors.accentBlue,
                            child: Icon(
                              member.isAdmin ? Icons.shield : Icons.person,
                              color: member.isAdmin ? AppColors.deepBlue : Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  member.player?.name ?? 'Jogador',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  member.isAdmin ? 'Admin' : 'Membro',
                                  style: TextStyle(
                                    color: member.isAdmin ? AppColors.highlightGreen : Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelf)
                            const Padding(
                              padding: EdgeInsets.only(right: 8),
                              child: Text('(você)', style: TextStyle(color: Colors.white38, fontSize: 12)),
                            ),
                          if (isUpdating)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentBlue),
                            )
                          else
                            Switch(
                              value: member.isAdmin,
                              activeColor: AppColors.highlightGreen,
                              onChanged: isSelf ? null : (_) => _toggleAdmin(member),
                            ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
