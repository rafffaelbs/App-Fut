import 'package:flutter/material.dart';

class TeamLogo extends StatelessWidget {
  final String label;
  final String assetPath;
  final double size;

  const TeamLogo({
    super.key,
    required this.label,
    required this.assetPath,
    this.size = 50,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Image.asset(
          assetPath,
          width: size,
          height: size,
          opacity: const AlwaysStoppedAnimation(0.7),
          errorBuilder: (context, error, stackTrace) {
            return Icon(Icons.checkroom, color: Colors.white54, size: size * 0.8);
          },
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: const Color(0xffe0e1dd).withOpacity(0.9),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}