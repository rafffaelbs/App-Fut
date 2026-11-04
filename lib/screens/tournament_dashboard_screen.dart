import 'package:flutter/material.dart';
import 'package:app_do_fut/app/app_services.dart';
import '../constants/app_colors.dart';

// --- IMPORT YOUR ACTUAL SCREENS ---
import 'match_screen.dart';
import 'ranking_screen.dart';
import 'history_screen.dart';

class TournamentDashboardScreen extends StatefulWidget {
  final String groupId;
  final String tournamentId;
  final String tournamentName;
  final int totalPlayers;

  const TournamentDashboardScreen({
    super.key,
    required this.groupId,
    required this.tournamentId,
    required this.tournamentName,
    required this.totalPlayers,
  });

  @override
  State<TournamentDashboardScreen> createState() =>
      _TournamentDashboardScreenState();
}

class _TournamentDashboardScreenState extends State<TournamentDashboardScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isReadOnly = AppServices.instance.features.isReadOnly;

    final List<Widget> screens = [
      // Tab 0: The Live Match (não existe na web/somente leitura)
      if (!isReadOnly)
        MatchScreen(
          tournamentName: widget.tournamentName,
          tournamentId: widget.tournamentId,
          totalPlayers: widget.totalPlayers,
          groupId: widget.groupId,
        ),

      // Today's Ranking
      RankingScreen(
        groupId: widget.groupId,
        tournamentId: widget.tournamentId,
      ),

      // Today's Match History
      HistoryScreen(tournamentId: widget.tournamentId, groupId: widget.groupId),
    ];

    final List<BottomNavigationBarItem> navItems = [
      if (!isReadOnly)
        const BottomNavigationBarItem(
          icon: Icon(Icons.sports_soccer),
          label: "Campo",
        ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.leaderboard),
        label: "Ranking",
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.history),
        label: "Histórico",
      ),
    ];

    final safeIndex = _currentIndex.clamp(0, screens.length - 1);

    return Scaffold(
      backgroundColor: AppColors.deepBlue,
      body: screens[safeIndex],

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
          currentIndex: safeIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          items: navItems,
        ),
      ),
    );
  }
}
