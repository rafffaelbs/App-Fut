import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../utils/rating_calculator.dart';

class PlayerCard extends StatelessWidget {
  final Map<String, dynamic> player;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const PlayerCard({
    super.key,
    required this.player,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final String name = player['name'] ?? '';
    final String initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final double rating = player['rating'] != null ? (player['rating'] as num).toDouble() : kRatingBase;
    final int games = player['totalGames'] ?? 0;
    final String? iconPath = player['icon'];
    final Color rColor = getRatingColor(rating);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.headerBlue,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.deepBlue,
                  radius: 26,
                  child: iconPath != null
                      ? ClipOval(child: Padding(padding: const EdgeInsets.all(6), child: Image.asset(iconPath, fit: BoxFit.contain)))
                      : Text(initial, style: TextStyle(color: rColor, fontWeight: FontWeight.bold, fontSize: 20)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: rating / kMaxRating,
                                minHeight: 4,
                                backgroundColor: Colors.white10,
                                valueColor: AlwaysStoppedAnimation<Color>(rColor.withValues(alpha: 0.7)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(getRatingLabel(rating, games), style: TextStyle(color: rColor, fontSize: 11, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: rColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: rColor.withValues(alpha: 0.3), width: 1),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(rating.toStringAsFixed(1), style: TextStyle(color: rColor, fontSize: 13, fontWeight: FontWeight.bold, height: 1)),
                      Text('/10', style: TextStyle(color: rColor.withValues(alpha: 0.5), fontSize: 9)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 17),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
