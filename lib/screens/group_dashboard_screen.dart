import 'package:flutter/material.dart';
import 'package:app_do_fut/constants/app_colors.dart';
import 'package:app_do_fut/screens/players_screen.dart';
import 'package:app_do_fut/screens/web/home_dashboard_screen.dart';
import 'package:app_do_fut/screens/sessions_screen.dart';
import 'package:app_do_fut/screens/season_stats_screen.dart';
import 'package:app_do_fut/screens/player_detail.dart';
import 'package:app_do_fut/screens/settings_screen.dart';
import 'package:app_do_fut/app/app_services.dart';
import 'package:app_do_fut/services/group_bootstrap.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_do_fut/services/dashboard_store.dart';
import 'package:app_do_fut/widgets/shared/notifications_sheet.dart';

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
  String? _myPlayerId;
  String? _myPlayerName;
  int _unreadNotifs = 0;

  @override
  void initState() {
    super.initState();
    _checkAdmin();
    _loadUserProfileAndNotifs();
    DashboardStore.instance.status.addListener(_onDashboardStatusChange);
    // Carga inicial: puxa elenco, peladas, histórico e calcula as notas uma
    // vez. Roda em segundo plano; a pelada usa esse snapshot local.
    GroupBootstrap.instance.prefetch(widget.groupId, force: true);
  }

  @override
  void dispose() {
    DashboardStore.instance.status.removeListener(_onDashboardStatusChange);
    super.dispose();
  }

  void _onDashboardStatusChange() {
    if (DashboardStore.instance.status.value == DashboardStatus.ready) {
      _updateUnreadCount();
    }
  }

  Future<void> _loadUserProfileAndNotifs() async {
    if (kIsWeb || !AppServices.instance.features.hasAuth) return;
    try {
      final membership =
          await AppServices.instance.members.getMyMembership(widget.groupId);
      if (membership != null && mounted) {
        setState(() {
          _myPlayerId = membership.playerId;
          _myPlayerName =
              membership.player?.name ?? membership.player?.displayName;
        });
        await _updateUnreadCount();
      }
    } catch (_) {}
  }

  Future<void> _updateUnreadCount() async {
    if (_myPlayerId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSeenStr =
          prefs.getString('last_seen_notif_${widget.groupId}_$_myPlayerId');
      final lastSeen =
          lastSeenStr != null ? DateTime.tryParse(lastSeenStr) : null;
      final updates = DashboardStore.instance.data?.updates ?? [];
      final myUpdates =
          updates.where((u) => u.playerId == _myPlayerId).toList();
      int unread = 0;
      for (final u in myUpdates) {
        if (lastSeen == null || u.date.isAfter(lastSeen)) {
          unread++;
        }
      }
      if (mounted) {
        setState(() => _unreadNotifs = unread);
      }
    } catch (_) {}
  }

  void _openNotifications() {
    if (_myPlayerId == null) return;
    final updates = DashboardStore.instance.data?.updates ?? [];
    final myUpdates =
        updates.where((u) => u.playerId == _myPlayerId).toList();
    NotificationsSheet.show(
      context: context,
      groupId: widget.groupId,
      myPlayerId: _myPlayerId!,
      playerName: _myPlayerName ?? 'Você',
      myUpdates: myUpdates,
      onCleared: () {
        if (mounted) setState(() => _unreadNotifs = 0);
      },
    );
  }

  Future<void> _checkAdmin() async {
    // Fail-safe: qualquer erro na checagem = não é admin = sem engrenagem.
    bool isAdmin = false;
    try {
      isAdmin = await AppServices.instance.permissions.isAdmin(widget.groupId);
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
    final membership = await AppServices.instance.members.getMyMembership(widget.groupId);
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
    // A aba "Início" é a primeira (site e app). Fica viva (Offstage) para não
    // ser recriada ao trocar de aba.
    final List<Widget> screens = [
      const SizedBox.shrink(),
      SessionsScreen(groupId: widget.groupId), 
      PlayersScreen(groupId: widget.groupId),
      SeasonStatsScreen(groupId: widget.groupId),
    ];

    final List<String> titles = ["Início", "Peladas", "Elenco", "Estatísticas"];

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
            builder: (context, st, child) => st == BootstrapStatus.loading
                ? const LinearProgressIndicator(minHeight: 3)
                : st == BootstrapStatus.offline
                    ? Container(height: 3, color: Colors.orangeAccent)
                    : const SizedBox(height: 3),
          ),
        ),
        actions: [
          if (!kIsWeb && AppServices.instance.features.hasAuth && _myPlayerId != null)
            IconButton(
              icon: Badge(
                isLabelVisible: _unreadNotifs > 0,
                label: Text('$_unreadNotifs', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                backgroundColor: Colors.redAccent,
                child: const Icon(Icons.notifications_outlined, color: Colors.white),
              ),
              tooltip: 'Notificações',
              onPressed: _openNotifications,
            ),
          if (AppServices.instance.features.hasAuth)
            IconButton(
              icon: const Icon(Icons.account_circle, color: Colors.white),
              tooltip: 'Meu Perfil',
              onPressed: _openMyProfile,
            ),
          // Engrenagem (Peladas / Elenco / Estatísticas): só admin vê (se features permitir).
          if (!_checkingAdmin && AppServices.instance.features.canAdminister(_isAdmin))
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

      body: Stack(
        fit: StackFit.expand,
        children: [
          Offstage(
            offstage: _currentIndex != 0,
            child: HomeDashboardScreen(
              groupId: widget.groupId,
              groupName: widget.groupName,
            ),
          ),
          if (_currentIndex != 0) screens[_currentIndex],
        ],
      ),

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
            BottomNavigationBarItem(icon: Icon(Icons.home), label: "Início"),
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
