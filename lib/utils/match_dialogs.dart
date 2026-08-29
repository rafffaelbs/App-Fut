import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/player.dart';

class MatchDialogs {
  static void showRemovePopup(
    BuildContext context,
    Player player,
    VoidCallback onConfirm,
  ) {
    showDialog<void>(
      context: context,
      builder: (BuildContext c) => AlertDialog(
        backgroundColor: AppColors.headerBlue,
        title: const Text("Remover?", style: TextStyle(color: AppColors.textWhite)),
        content: Text(
          "Tirar ${player.name} do time?",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            child: const Text("Cancelar", style: TextStyle(color: Colors.white54)),
            onPressed: () => Navigator.pop(c),
          ),
          TextButton(
            child: const Text("Remover", style: TextStyle(color: Colors.redAccent)),
            onPressed: () {
              onConfirm();
              Navigator.pop(c);
            },
          ),
        ],
      ),
    );
  }
}