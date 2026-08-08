import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

/// Exibe o diálogo de confirmação de exclusão de uma pelada.
/// Retorna `true` se o usuário confirmou a exclusão.
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