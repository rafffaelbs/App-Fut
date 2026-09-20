import 'package:app_do_fut/constants/app_colors.dart';
import 'package:app_do_fut/screens/players_screen.dart';
import 'package:app_do_fut/screens/sessions_screen.dart';
import 'package:app_do_fut/screens/season_stats_screen.dart';
import 'package:app_do_fut/screens/manage_badges_screen.dart'; // <-- IMPORTANTE
import 'package:app_do_fut/screens/manage_seasons_screen.dart';
import 'package:app_do_fut/screens/manage_join_requests_screen.dart';
import 'package:app_do_fut/screens/admin_debug_screen.dart';
import 'package:app_do_fut/screens/player_detail.dart';
import 'package:app_do_fut/screens/manage_members_screen.dart';
import 'package:app_do_fut/repositories/supabase_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GroupDashboardScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupDashboardScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<GroupDashboardScreen> createState() => _GroupDashboardScreenState();
}

class _GroupDashboardScreenState extends State<GroupDashboardScreen> {
  int _currentIndex = 0;
  bool _isAdmin = false;
  bool _checkingAdmin = true;

  @override
  void initState() {
    super.initState();
    _checkAdmin();
  }

  Future<void> _checkAdmin() async {
    final isAdmin = await SupabaseService.instance.groupMembers.isCurrentUserAdmin(widget.groupId);
    if (mounted) setState(() {
      _isAdmin = isAdmin;
      _checkingAdmin = false;
    });
  }

  /// Abre a tela de perfil (a mesma usada no Elenco/Ranking) já com o
  /// jogador do usuário logado, sem precisar passar pela lista do Elenco.
  Future<void> _openMyProfile() async {
    final membership = await SupabaseService.instance.groupMembers.getMyMembership(widget.groupId);
    if (!mounted) return;

    if (membership == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não encontramos seu perfil de jogador neste grupo.')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlayerDetailScreen(
          groupId: widget.groupId,
          playerId: membership.playerId,
          initialPlayerName: membership.player?.name,
          playerIcon: membership.player?.avatarUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      SessionsScreen(groupId: widget.groupId), 
      PlayersScreen(groupId: widget.groupId),
      SeasonStatsScreen(groupId: widget.groupId),
    ];

    final List<String> titles = ["Peladas", "Elenco", "Estatísticas"];

    return Scaffold(
      backgroundColor: AppColors.deepBlue,
      appBar: AppBar(
        backgroundColor: AppColors.headerBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          titles[_currentIndex],
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle, color: Colors.white),
            tooltip: 'Meu Perfil',
            onPressed: _openMyProfile,
          ),
          // A checagem real de permissão é feita pelo RLS no Supabase; isso
          // here it just avoids showing admin buttons to a regular member.
          if (!_checkingAdmin && _isAdmin)
          PopupMenuButton<String>(
            icon: const Icon(Icons.settings, color: Colors.white),
            color: AppColors.headerBlue,
            onSelected: (value) async {
              if (value == 'requests') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ManageJoinRequestsScreen(groupId: widget.groupId)),
                );
              } else if (value == 'members') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ManageMembersScreen(groupId: widget.groupId)),
                );
              } else if (value == 'badges') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ManageBadgesScreen(groupId: widget.groupId)),
                );
              } else if (value == 'seasons') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ManageSeasonsScreen(groupId: widget.groupId)),
                );
              } else if (value == 'debug') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AdminDebugScreen(groupId: widget.groupId)),
                );
              } else if (value == 'settings') {
                showDialog(
                  context: context,
                  builder: (ctx) {
                    return FutureBuilder<SharedPreferences>(
                      future: SharedPreferences.getInstance(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                        final prefs = snapshot.data!;
                        bool showRadar = prefs.getBool('show_radar_chart') ?? true;
                        
                        return StatefulBuilder(
                          builder: (context, setDialogState) {
                            return AlertDialog(
                              backgroundColor: AppColors.headerBlue,
                              title: const Text('Configurações', style: TextStyle(color: Colors.white)),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SwitchListTile(
                                    title: const Text('Exibir Gráfico Radar', style: TextStyle(color: Colors.white)),
                                    subtitle: const Text('Mostra o gráfico no perfil e X1', style: TextStyle(color: Colors.white54, fontSize: 12)),
                                    activeColor: AppColors.accentBlue,
                                    value: showRadar,
                                    onChanged: (val) {
                                      prefs.setBool('show_radar_chart', val);
                                      setDialogState(() { showRadar = val; });
                                    },
                                  ),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Fechar', style: TextStyle(color: AppColors.accentBlue)),
                                ),
                              ],
                            );
                          }
                        );
                      }
                    );
                  }
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'requests',
                child: Row(children: [Icon(Icons.how_to_reg, color: AppColors.highlightGreen, size: 20), SizedBox(width: 8), Text('Solicitações de Entrada', style: TextStyle(color: Colors.white))]),
              ),
              const PopupMenuItem(
                value: 'members',
                child: Row(children: [Icon(Icons.admin_panel_settings, color: AppColors.highlightGreen, size: 20), SizedBox(width: 8), Text('Gerenciar Membros', style: TextStyle(color: Colors.white))]),
              ),
              const PopupMenuItem(
                value: 'badges',
                child: Row(children: [Icon(Icons.workspace_premium, color: Colors.amber, size: 20), SizedBox(width: 8), Text('Gerenciar Troféus', style: TextStyle(color: Colors.white))]),
              ),
              const PopupMenuItem(
                value: 'seasons',
                child: Row(children: [Icon(Icons.calendar_month, color: AppColors.accentBlue, size: 20), SizedBox(width: 8), Text('Gerenciar Temporadas', style: TextStyle(color: Colors.white))]),
              ),
              const PopupMenuItem(
                value: 'debug',
                child: Row(children: [Icon(Icons.terminal, color: AppColors.highlightGreen, size: 20), SizedBox(width: 8), Text('Admin & Debug Cache', style: TextStyle(color: Colors.white))]),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(children: [Icon(Icons.settings, color: Colors.grey, size: 20), SizedBox(width: 8), Text('Configurações', style: TextStyle(color: Colors.white))]),
              ),
            ],
          ),
        ],
      ),

      body: screens[_currentIndex], 

      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: AppColors.headerBlue,
        selectedItemColor: AppColors.accentBlue,
        unselectedItemColor: Colors.white54,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: "Peladas",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.groups), label: "Elenco"),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: "Estatísticas"),
        ],
      ),
    );
  }
}
