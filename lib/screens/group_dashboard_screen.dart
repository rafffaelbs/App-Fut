import 'package:app_do_fut/constants/app_colors.dart';
import 'package:app_do_fut/screens/players_screen.dart';
import 'package:app_do_fut/screens/sessions_screen.dart';
import 'package:app_do_fut/screens/season_stats_screen.dart';
import 'package:app_do_fut/screens/player_detail.dart';
import 'package:app_do_fut/screens/settings_screen.dart';
import 'package:app_do_fut/repositories/supabase_service.dart';
import 'package:app_do_fut/services/group_bootstrap.dart';
import 'package:flutter/material.dart';

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
    // Carga inicial: puxa elenco, peladas, histórico e calcula as notas uma
    // vez. Roda em segundo plano; a pelada usa esse snapshot local.
    GroupBootstrap.instance.prefetch(widget.groupId, force: true);
  }

  Future<void> _checkAdmin() async {
    // Fail-safe: qualquer erro na checagem = não é admin = sem engrenagem.
    bool isAdmin = false;
    try {
      isAdmin = await SupabaseService.permissions.isAdmin(widget.groupId);
    } catch (_) {
      isAdmin = false;
    }
    if (mounted) {
      setState(() {
        _isAdmin = isAdmin;
        _checkingAdmin = false;
      });
    }
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: ValueListenableBuilder<BootstrapStatus>(
            valueListenable: GroupBootstrap.instance.status,
            builder: (_, st, __) => st == BootstrapStatus.loading
                ? const LinearProgressIndicator(minHeight: 3)
                : st == BootstrapStatus.offline
                    ? Container(height: 3, color: Colors.orangeAccent)
                    : const SizedBox(height: 3),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle, color: Colors.white),
            tooltip: 'Meu Perfil',
            onPressed: _openMyProfile,
          ),
          // Engrenagem (Peladas / Elenco / Estatísticas): só admin vê.
          if (!_checkingAdmin && _isAdmin)
            IconButton(
              icon: const Icon(Icons.settings, color: Colors.white),
              tooltip: 'Configurações',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SettingsScreen(
                      groupId: widget.groupId,
                      isAdmin: _isAdmin,
                    ),
                  ),
                );
              },
            ),
        ],
      ),

      body: screens[_currentIndex], 

      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.headerBlue,
          border: Border(
            top: BorderSide(color: AppColors.borderSubtle, width: 1),
          ),
        ),
        child: BottomNavigationBar(
          backgroundColor: AppColors.headerBlue,
          elevation: 0,
          selectedItemColor: AppColors.accentBlue,
          unselectedItemColor: AppColors.textDim,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
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
      ),
    );
  }
}
