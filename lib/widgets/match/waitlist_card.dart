import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

class WaitlistCard extends StatelessWidget {
  final Map<String, dynamic> player;
  final int index;
  final int totalPlayers;
  final VoidCallback onTap;

  const WaitlistCard({
    super.key,
    required this.player,
    required this.index,
    required this.totalPlayers,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isNextTeam = index < (totalPlayers * 2); 
    final iconPath = player['icon'] as String?;
    final rating = player['rating'] != null ? (player['rating'] as num).toDouble() : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.headerBlue,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isNextTeam ? AppColors.accentBlue.withOpacity(0.5) : Colors.transparent,
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isNextTeam ? AppColors.accentBlue.withOpacity(0.2) : Colors.white10,
          backgroundImage: iconPath != null ? AssetImage(iconPath) : null,
          child: iconPath == null ? Text("${index + 1}º", style: const TextStyle(color: Colors.white)) : null,
        ),
        title: Text(
          player['name'],
          style: const TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold),
        ),
        subtitle: isNextTeam 
            ? const Text("Próximo Time", style: TextStyle(color: AppColors.accentBlue, fontSize: 12)) 
            : null,
        trailing: rating > 0 
            ? Text(rating.toStringAsFixed(1), style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold))
            : const Icon(Icons.more_vert, color: Colors.white24),
        onTap: onTap,
      ),
    );
  }
}