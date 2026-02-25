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
    bool empty = player == null;
    Color c = isRed ? Colors.redAccent : Colors.white;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.headerBlue,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: empty ? Colors.transparent : c.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            empty
                ? const Icon(
                    Icons.person_outline,
                    color: Colors.white12,
                    size: 30,
                  )
                : CircleAvatar(
                    backgroundColor: c,
                    foregroundColor: isRed ? Colors.white : Colors.black,
                    radius: 16,
                    child: Text(
                      player!['name'].substring(0, 1).toUpperCase(),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
            const SizedBox(height: 4),
            Text(
              empty ? "Vazio" : player!['name'],
              style: TextStyle(
                color: empty ? Colors.white24 : AppColors.textWhite,
                fontSize: 14,
                fontWeight: empty ? FontWeight.normal : FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
