import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../utils/overall_calculator.dart';
import '../shared/player_name_text.dart';

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
    final rating = playerOverallOf(player);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.headerBlue,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isNextTeam ? AppColors.accentBlue : AppColors.borderSubtle,
          width: isNextTeam ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isNextTeam
              ? AppColors.accentBlue.withValues(alpha: 0.20)
              : AppColors.surfaceSubtle,
          backgroundImage: iconPath != null ? AssetImage(iconPath) : null,
          child: iconPath == null
              ? Text("${index + 1}º", style: const TextStyle(color: AppColors.textWhite))
              : null,
        ),
        title: PlayerNameText(
          name: player['name'].toString(),
          nameEffect: player['name_effect']?.toString(),
          style: const TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold),
        ),
        subtitle: isNextTeam 
            ? const Text(
                "Próximo Time",
                style: TextStyle(
                  color: AppColors.accentBlueLight,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ) 
            : null,
        trailing: rating > 0 
            ? Text(
                rating.round().toString(),
                style: TextStyle(
                  color: overallColor(rating),
                  fontWeight: FontWeight.bold,
                ),
              )
            : const Icon(Icons.more_vert, color: AppColors.textDim),
        onTap: onTap,
      ),
    );
  }
}