import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class MatchDialogs {
  
  static void showRemovePopup(BuildContext context, Map<String, dynamic> player, Function onConfirm) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppColors.headerBlue,
        title: Text("Remover?", style: TextStyle(color: AppColors.textWhite)),
        content: Text("Tirar ${player['name']} do time?", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            child: const Text("Cancelar", style: TextStyle(color: Colors.white54)),
            onPressed: () => Navigator.pop(c),
          ),
          TextButton(
            child: const Text("Remover", style: TextStyle(color: Colors.redAccent)),
            onPressed: () {
              onConfirm(); // Call the logic from the main screen
              Navigator.pop(c);
            },
          ),
        ],
      ),
    );
  }
}