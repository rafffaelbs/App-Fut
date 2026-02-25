import 'package:app_do_fut/constants/app_colors.dart';
import 'package:app_do_fut/screens/history_screen.dart';
import 'package:app_do_fut/screens/match_screen.dart';
import 'package:app_do_fut/screens/players_screen.dart';
import 'package:flutter/material.dart';
import 'package:app_do_fut/screens/blank_screen.dart'; // Import your BlankScreen

class TournamentScreen extends StatelessWidget {
  final String tournamentName;
  final String tournamentId;

  const TournamentScreen({
    super.key,
    required this.tournamentId,
    required this.tournamentName,
  });

  @override
  Widget build(BuildContext context) {
    // The 4 Menu Options
    final List<Map<String, dynamic>> menuOptions = [
      {
        'title': 'Jogadores',
        'icon': Icons.groups,
        'subtitle': 'Gerenciar lista de amigos',
        'color': Colors.lightBlueAccent,
      },
      {
        'title': 'Partidas',
        'icon': Icons.sports_soccer,
        'subtitle': 'Histórico e novos jogos',
        'color': Colors.greenAccent,
      },
      {
        'title': 'Estatísticas',
        'icon': Icons.bar_chart,
        'subtitle': 'Artilharia e rankings',
        'color': Colors.purpleAccent,
      },
      {
        'title': 'Configurações',
        'icon': Icons.settings,
        'subtitle': 'Regras e detalhes',
        'color': Colors.grey,
      },
    ];

    return Scaffold(
      backgroundColor: AppColors.deepBlue,

      // 1. App Bar with the Tournament Name
      appBar: AppBar(
        backgroundColor: AppColors.headerBlue,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textWhite),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          tournamentName, // Dynamic Title
          style: TextStyle(
            color: AppColors.textWhite,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        centerTitle: true,
      ),

      // 2. The List of 4 Cards
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: menuOptions.length,
        itemBuilder: (context, index) {
          final item = menuOptions[index];

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            child: Material(
              color: AppColors.headerBlue,
              borderRadius: BorderRadius.circular(16),
              elevation: 4,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  if (item['title'] == 'Jogadores') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (c) => const PlayersScreen()),
                    );
                  } else if (item['title'] == 'Partidas') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (c) =>
                            MatchScreen(tournamentName: tournamentName, tournamentId: tournamentId,),
                      ),
                    );
                  }
                  // LINK THE HISTORY SCREEN HERE:
                  else if (item['title'] == 'Estatísticas') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (c) => const HistoryScreen()),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (c) => const BlankScreen()),
                    );
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    // Colorful Icon Box
                    leading: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: item['color'].withOpacity(
                          0.1,
                        ), // Light background
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        item['icon'],
                        color: item['color'], // Specific color for each option
                        size: 28,
                      ),
                    ),
                    title: Text(
                      item['title'],
                      style: TextStyle(
                        color: AppColors.textWhite,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        item['subtitle'],
                        style: TextStyle(color: Colors.white54, fontSize: 14),
                      ),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.white24,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
