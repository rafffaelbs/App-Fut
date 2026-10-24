import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../utils/overall_calculator.dart';
import '../shared/player_name_text.dart';

class PlayerFieldSlot extends StatelessWidget {
  final Map<String, dynamic>? player;
  final bool isRed;
  final VoidCallback onTap;

  const PlayerFieldSlot({
    super.key,
    required this.player,
    required this.isRed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasPlayer = player != null;
    final iconPath = hasPlayer ? player!['icon'] as String? : null;
    final rating = hasPlayer ? playerOverallOf(player!) : 0.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: hasPlayer
              ? (isRed
                    ? AppColors.surfaceSubtle.withValues(alpha: 0.90)
                    : AppColors.surfaceElevated.withValues(alpha: 0.90))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: hasPlayer
                ? (isRed ? AppColors.redTeam.withValues(alpha: 0.5) : Colors.white24)
                : Colors.white12,
            style: hasPlayer ? BorderStyle.solid : BorderStyle.none,
          ),
        ),
        child: Row(
          children: [
            // --- PLAYER ICON / AVATAR ---
            CircleAvatar(
              radius: 18,
              backgroundColor: hasPlayer
                  ? (isRed ? AppColors.redTeam.withValues(alpha: 0.25) : Colors.white12)
                  : Colors.black12,
              backgroundImage: iconPath != null ? AssetImage(iconPath) : null,
              child: !hasPlayer
                  ? const Icon(Icons.add, color: Colors.white24)
                  : (iconPath == null
                        ? Icon(
                            Icons.person,
                            color: isRed ? AppColors.redTeam : Colors.white,
                          )
                        : null),
            ),
            const SizedBox(width: 8),

            // --- NAME AND RATING ---
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PlayerNameText(
                    name: hasPlayer ? player!['name'].toString() : "Vazio",
                    player: player,
                    style: TextStyle(
                      color: hasPlayer ? AppColors.textWhite : Colors.white38,
                      fontWeight: hasPlayer
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (hasPlayer && rating > 0)
                    Text(
                      "OVR: ${rating.round()}",
                      style: TextStyle(
                        color: overallColor(rating),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
