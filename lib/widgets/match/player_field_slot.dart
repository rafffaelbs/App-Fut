import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

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
    final rating = hasPlayer && player!['rating'] != null
        ? (player!['rating'] as num).toDouble()
        : 0.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: hasPlayer
              ? (isRed
                    ? Colors.black.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.25))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: hasPlayer
                ? (isRed ? Colors.grey.withValues(alpha: 0.5) : Colors.white54)
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
                  ? (isRed ? Colors.white.withValues(alpha: 0.3) : Colors.white24)
                  : Colors.black12,
              backgroundImage: iconPath != null ? AssetImage(iconPath) : null,
              child: !hasPlayer
                  ? const Icon(Icons.add, color: Colors.white24)
                  : (iconPath == null
                        ? Icon(
                            Icons.person,
                            color: isRed ? Colors.black : Colors.white,
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
                  Text(
                    hasPlayer ? player!['name'] : "Vazio",
                    style: TextStyle(
                      color: hasPlayer ? AppColors.textWhite : Colors.white38,
                      fontWeight: hasPlayer
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (hasPlayer && rating > 0)
                    Text(
                      "OVR: ${rating.toStringAsFixed(1)}",
                      style: const TextStyle(
                        color: Colors.amber,
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
