import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../utils/stats_board_utils.dart';
import 'stat_row.dart';

/// "Ver mais": ranking completo do quadro. Celular (<600dp) = bottom sheet
/// arrastável de altura total; tablet/web = diálogo de ~480dp.
Future<void> showFullRanking(
  BuildContext context, {
  required String title,
  required List<StatRow> rows,
  String? footer,
  void Function(StatRow row)? onTapRow,
}) {
  Widget body(ScrollController? controller) => FullRankingList(
        title: title,
        rows: rows,
        footer: footer,
        controller: controller,
        onTapRow: onTapRow == null
            ? null
            : (r) {
                Navigator.pop(context);
                onTapRow(r);
              },
      );

  if (MediaQuery.of(context).size.width >= 600) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surfaceElevated,
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 640),
          child: body(null),
        ),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.95,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => body(controller),
    ),
  );
}

class FullRankingList extends StatefulWidget {
  final String title;
  final List<StatRow> rows;
  final String? footer;
  final ScrollController? controller;
  final void Function(StatRow row)? onTapRow;

  const FullRankingList({
    super.key,
    required this.title,
    required this.rows,
    this.footer,
    this.controller,
    this.onTapRow,
  });

  @override
  State<FullRankingList> createState() => _FullRankingListState();
}

class _FullRankingListState extends State<FullRankingList> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    // Posição vem do ranking completo, não do filtro de busca.
    final positions = rankWithTies(widget.rows.map((r) => r.tieValue).toList());
    final q = _query.trim().toLowerCase();
    final visible = <int>[
      for (var i = 0; i < widget.rows.length; i++)
        if (q.isEmpty || widget.rows[i].searchName.contains(q)) i,
    ];
    return Column(
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
            child: Text(widget.title,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Buscar por nome',
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
          child: visible.isEmpty
              ? const Center(
                  child: Text('Nada encontrado',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12)))
              : ListView.builder(
                  controller: widget.controller,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: visible.length,
                  itemBuilder: (_, k) {
                    final i = visible[k];
                    return StatRowTile(
                      row: widget.rows[i],
                      position: positions[i],
                      height: 56,
                      showAvatar: true,
                      onTap: widget.onTapRow == null ? null : () => widget.onTapRow!(widget.rows[i]),
                    );
                  },
                ),
        ),
        if (widget.footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Text(widget.footer!,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ),
      ],
    );
  }
}
