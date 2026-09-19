import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

/// Shows the confirmation dialog for deleting a session.
/// Returns `true` if the user confirmed the deletion.
Future<bool> showSessionDeleteDialog(BuildContext context) async {
  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext ctx) => AlertDialog(
      backgroundColor: AppColors.headerBlue,
      title: const Text(
        "Excluir Pelada?",
        style: TextStyle(color: AppColors.textWhite),
      ),
      content: const Text(
        "Tem certeza que deseja excluir esta pelada?",
        style: TextStyle(color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text(
            "Cancelar",
            style: TextStyle(color: Colors.white54),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text(
            "Excluir",
            style: TextStyle(color: Colors.redAccent),
          ),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}