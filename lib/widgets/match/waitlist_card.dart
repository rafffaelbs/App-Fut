import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

class WaitlistCard extends StatelessWidget {
  final Map<String, dynamic> player;
  final int index;
  final int totalPlayers;
  final VoidCallback onTap;

  const WaitlistCard({
    super.key,
    required this.totalPlayers,
    required this.player,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    bool showHeader = (index % totalPlayers == 0);
    int teamNumber = (index ~/ totalPlayers) + 1;

    return Column(
      key: ValueKey(player['name']),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeader)
          Padding(
            padding: const EdgeInsets.only(top: 24, bottom: 8),
            child: Text(
              "GRUPO $teamNumber",
              style: const TextStyle(
                color: Colors.greenAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        Card(
          color: AppColors.headerBlue,
          margin: const EdgeInsets.only(bottom: 4),
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.drag_handle, color: Colors.white24),
            title: Text(
              player['name'],
              style: const TextStyle(color: AppColors.textWhite),
            ),
            trailing: const Icon(Icons.more_vert, color: AppColors.accentBlue),
            onTap: onTap,
          ),
        ),
      ],
    );
  }
}
