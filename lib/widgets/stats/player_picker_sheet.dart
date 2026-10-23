import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../shared/ranking_player_bits.dart';

/// Bottom sheet com busca e lista de jogadores (avatar + nome cosmético).
/// [players] são mapas no formato de `GroupBootstrap.playerSnapshotMap`.
/// Retorna o id escolhido.
Future<String?> showPlayerPickerSheet(
  BuildContext context, {
  required List<Map<String, dynamic>> players,
  String? excludeId,
  String title = 'Selecione o jogador',
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => _PlayerPickerBody(
      players: players.where((p) => p['id'] != excludeId).toList(),
      title: title,
    ),
  );
}

class _PlayerPickerBody extends StatefulWidget {
  final List<Map<String, dynamic>> players;
  final String title;
  const _PlayerPickerBody({required this.players, required this.title});

  @override
  State<_PlayerPickerBody> createState() => _PlayerPickerBodyState();
}

class _PlayerPickerBodyState extends State<_PlayerPickerBody> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final list = widget.players
        .where((p) => q.isEmpty || (p['name'] ?? '').toString().toLowerCase().contains(q))
        .toList();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (ctx, controller) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderSubtle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                autofocus: false,
                onChanged: (v) => setState(() => _query = v),
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Buscar jogador',
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.surfaceSubtle,
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: list.isEmpty
                  ? const Center(
                      child: Text('Nenhum jogador encontrado',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    )
                  : ListView.builder(
                      controller: controller,
                      itemCount: list.length,
                      itemExtent: 56,
                      itemBuilder: (_, i) {
                        final p = list[i];
                        return InkWell(
                          onTap: () => Navigator.pop(context, p['id'] as String),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                RankAvatar(player: p, size: 36),
                                const SizedBox(width: 12),
                                Expanded(child: RankName(player: p)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
