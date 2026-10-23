import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../utils/overall_calculator.dart';
import '../shared/player_name_text.dart';
import '../shared/player_avatar_frame.dart';

class MatchPlayerTile extends StatelessWidget {
  final Map<String, dynamic> player;
  final bool isRed;
  final Map<String, dynamic> matchStats;
  final VoidCallback onTap;
  final List<Widget> eventIcons;

  const MatchPlayerTile({
    super.key,
    required this.player,
    required this.isRed,
    required this.matchStats,
    required this.onTap,
    required this.eventIcons,
  });

  @override
  Widget build(BuildContext context) {
    final double overallRating = playerOverallOf(player);
    final frame = resolvePlayerFrame(player);
    
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6, left: 6, right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.headerBlue,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Row(
          children: [
            PlayerAvatarFrame(
              frame: frame,
              compact: true,
              isCircular: true,
              child: Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: overallColor(overallRating).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  overallRating.round().toString(),
                  style: TextStyle(
                    color: overallColor(overallRating),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: PlayerNameText(
                name: player['name'].toString().split(' ')[0],
                nameEffect: player['name_effect']?.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Row(mainAxisSize: MainAxisSize.min, children: eventIcons),
          ],
        ),
      ),
    );
  }
}
