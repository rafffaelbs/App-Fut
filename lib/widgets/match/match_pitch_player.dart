import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../utils/rating_calculator.dart';

class MatchPitchPlayer extends StatelessWidget {
  final Map<String, dynamic> player;
  final bool isRed;
  final bool isMotm;
  final Map<String, dynamic> stats;
  final VoidCallback onTap;
  final List<Widget> eventIcons;

  const MatchPitchPlayer({
    super.key,
    required this.player,
    required this.isRed,
    required this.isMotm,
    required this.stats,
    required this.onTap,
    required this.eventIcons,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none, alignment: Alignment.center,
            children: [
              CircleAvatar(
                radius: 20, 
                backgroundColor: isRed ? Colors.redAccent : Colors.white, 
                child: CircleAvatar(
                  radius: 18, 
                  backgroundColor: AppColors.deepBlue, 
                  backgroundImage: player['icon'] != null ? AssetImage(player['icon']) : null, 
                  child: player['icon'] == null ? Text(player['name'][0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)) : null
                )
              ),
              if (isMotm && stats['nota'] >= 7.0) 
                const Positioned(top: -6, left: -6, child: Icon(Icons.star, color: Colors.amber, size: 16)),
              if (eventIcons.isNotEmpty) 
                Positioned(
                  top: -5, right: -15, 
                  child: Container(
                    padding: const EdgeInsets.all(2), 
                    decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)), 
                    child: Row(mainAxisSize: MainAxisSize.min, children: eventIcons)
                  )
                ),
              Positioned(
                bottom: -6, 
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), 
                  decoration: BoxDecoration(
                    color: getRatingColor(stats['nota']), 
                    borderRadius: BorderRadius.circular(4), 
                    border: Border.all(color: Colors.black87, width: 1)
                  ), 
                  child: Text(stats['nota'].toStringAsFixed(1), style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold))
                )
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(player['name'].toString().split(' ')[0], style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600, shadows: [Shadow(color: Colors.black, blurRadius: 2)])),
        ],
      ),
    );
  }
}
