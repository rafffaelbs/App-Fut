import 'package:flutter/material.dart';
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
    // 1. Map your real screens to the tabs!
    final List<Widget> screens = [
      // Tab 0: The Live Match
      MatchScreen(
        tournamentName: widget.tournamentName,
        tournamentId: widget.tournamentId,
        totalPlayers: widget.totalPlayers,
        groupId:
            widget.groupId, // We will update MatchScreen to accept this next!
      ),

      // Tab 1: Today's Ranking
      RankingScreen(
        groupId: widget.groupId,
        tournamentId: widget.tournamentId,
      ),

      // Tab 2: Today's Match History
      HistoryScreen(tournamentId: widget.tournamentId, groupId: widget.groupId),
    ];
    // IMPORTANT: We remove the AppBar from here, because MatchScreen,
    // RankingScreen, and HistoryScreen ALREADY have their own AppBars!
    // We just show the active screen and the bottom nav.
    return Scaffold(
      backgroundColor: AppColors.deepBlue,
      body: screens[_currentIndex], // Shows the active screen

      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: AppColors.headerBlue,
        selectedItemColor: AppColors.accentBlue,
        unselectedItemColor: Colors.white54,
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.sports_soccer),
            label: "Campo",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.leaderboard),
            label: "Ranking",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: "Histórico",
          ),
        ],
      ),
    );
  }
}
