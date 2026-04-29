import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../utils/rating_calculator.dart';

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
    double overallRating = player['rating'] != null ? (player['rating'] as num).toDouble() : kRatingBase;
    
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4, left: 6, right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.headerBlue,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: getRatingColor(overallRating).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(overallRating.toStringAsFixed(1), style: TextStyle(color: getRatingColor(overallRating), fontSize: 9, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(player['name'].toString().split(' ')[0], style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
            ),
            Row(mainAxisSize: MainAxisSize.min, children: eventIcons),
          ],
        ),
      ),
    );
  }
}
