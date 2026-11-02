import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../models/player_stat_distribution.dart';

/// Paleta vibrante para as fatias da barra de distribuição e indicadores de jogadores.
const List<Color> statDistributionPalette = [
  Color(0xFF38BDF8), // Azul celeste
  Color(0xFF34D399), // Verde esmeralda
  Color(0xFFFBBF24), // Âmbar
  Color(0xFFF87171), // Coral / Vermelho suave
  Color(0xFFA78BFA), // Roxo claro
  Color(0xFFFB923C), // Laranja
  Color(0xFF2DD4BF), // Ciano / Teal
  Color(0xFFF472B6), // Rosa
  Color(0xFF818CF8), // Índigo
  Color(0xFFA3E635), // Verde limão
  Color(0xFFE879F9), // Fúcsia
  Color(0xFF67E8F9), // Azul turquesa
];

Color getDistributionColor(int index) {
  return statDistributionPalette[index % statDistributionPalette.length];
}

/// Card para a tela de detalhes do jogador mostrando o Top 3 e a opção "Ver mais".
class PlayerStatDistributionCard extends StatelessWidget {
  final PlayerStatCategoryData data;
  final void Function(String playerId, String playerName)? onTapPlayer;

  const PlayerStatDistributionCard({
    super.key,
    required this.data,
    this.onTapPlayer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.deepBlue,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho do Card
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: data.iconColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(data.icon, color: data.iconColor, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        data.totalReferenceLabel,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!data.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${data.items.length} ${data.items.length == 1 ? 'jogador' : 'jogadores'}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Mini barra de distribuição no topo do card
          if (!data.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 6,
                  child: Row(
                    children: [
                      for (var i = 0; i < data.items.length; i++)
                        Expanded(
                          flex: data.items[i].count,
                          child: Container(color: getDistributionColor(i)),
                        ),
                      if (data.unassignedCount > 0)
                        Expanded(
                          flex: data.unassignedCount,
                          child: Container(color: Colors.white24),
                        ),
                    ],
                  ),
                ),
              ),
            ),

          const SizedBox(height: 10),

          // Lista Top 3 ou estado vazio
          if (data.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Text(
                'Nenhum registro para esta estatística.',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  for (var i = 0; i < data.top3.length; i++)
                    _buildTopRow(
                      context,
                      rank: i + 1,
                      item: data.top3[i],
                      color: getDistributionColor(i),
                    ),
                ],
              ),
            ),

          // Rodapé "Ver mais"
          if (!data.isEmpty) ...[
            const Divider(color: Colors.white10, height: 1),
            InkWell(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(16),
              ),
              onTap: () => showPlayerDistributionSheet(
                context,
                data: data,
                onTapPlayer: onTapPlayer,
              ),
              child: Container(
                height: 42,
                alignment: Alignment.center,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Ver mais',
                      style: TextStyle(
                        color: AppColors.accentBlue,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: AppColors.accentBlue,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTopRow(
    BuildContext context, {
    required int rank,
    required PlayerStatDistributionItem item,
    required Color color,
  }) {
    Color rankColor;
    if (rank == 1) {
      rankColor = const Color(0xFFFFD700); // Ouro
    } else if (rank == 2) {
      rankColor = const Color(0xFFC0C0C0); // Prata
    } else {
      rankColor = const Color(0xFFCD7F32); // Bronze
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // Posição (1º, 2º, 3º)
          Container(
            width: 22,
            alignment: Alignment.centerLeft,
            child: Text(
              '$rankº',
              style: TextStyle(
                color: rankColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Ponto com a cor da barra
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),

          // Nome do jogador
          Expanded(
            child: Text(
              item.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),

          // Contagem e porcentagem
          Text(
            '${data.formatCount(item.count)} (${item.formattedPercentage})',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Abre o modal/bottom sheet com a distribuição completa em barra e lista de todos os jogadores.
Future<void> showPlayerDistributionSheet(
  BuildContext context, {
  required PlayerStatCategoryData data,
  void Function(String playerId, String playerName)? onTapPlayer,
}) {
  final isWide = MediaQuery.of(context).size.width >= 600;

  Widget buildContent(ScrollController? controller) {
    return _PlayerDistributionSheetContent(
      data: data,
      controller: controller,
      onTapPlayer: onTapPlayer,
    );
  }

  if (isWide) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.headerBlue,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
          child: buildContent(null),
        ),
      ),
    );
  }

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.headerBlue,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => buildContent(controller),
    ),
  );
}

class _PlayerDistributionSheetContent extends StatefulWidget {
  final PlayerStatCategoryData data;
  final ScrollController? controller;
  final void Function(String playerId, String playerName)? onTapPlayer;

  const _PlayerDistributionSheetContent({
    required this.data,
    this.controller,
    this.onTapPlayer,
  });

  @override
  State<_PlayerDistributionSheetContent> createState() =>
      _PlayerDistributionSheetContentState();
}

class _PlayerDistributionSheetContentState
    extends State<_PlayerDistributionSheetContent> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final query = _searchQuery.trim().toLowerCase();
    final allItems = widget.data.items;

    // Itens filtrados para a lista
    final filtered = <int>[
      for (var i = 0; i < allItems.length; i++)
        if (query.isEmpty || allItems[i].name.toLowerCase().contains(query)) i,
    ];

    return Column(
      children: [
        // Indicador de arrasto no topo (mobile)
        const SizedBox(height: 8),
        Container(
          width: 38,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 8),

        // Cabeçalho do modal
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: widget.data.iconColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  widget.data.icon,
                  color: widget.data.iconColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.data.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      widget.data.subtitle,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),

        // Explicação clara dos parâmetros da conta
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline,
                  color: AppColors.accentBlue,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.data.calculationExplanation,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Barra de Distribuição Colorida
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Distribuição',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Toque na fatia para detalhes',
                    style: TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  height: 26,
                  color: Colors.black26,
                  child: Row(
                    children: [
                      for (var i = 0; i < allItems.length; i++)
                        Expanded(
                          flex: allItems[i].count,
                          child: Tooltip(
                            message:
                                '${allItems[i].name}: ${widget.data.formatCount(allItems[i].count)} (${allItems[i].formattedPercentage})',
                            child: Container(
                              color: getDistributionColor(i),
                              alignment: Alignment.center,
                              child: (allItems[i].percentage >= 8)
                                  ? Text(
                                      allItems[i].formattedPercentage,
                                      style: const TextStyle(
                                        color: Colors.black87,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      if (widget.data.unassignedCount > 0)
                        Expanded(
                          flex: widget.data.unassignedCount,
                          child: Tooltip(
                            message:
                                '${widget.data.unassignedLabel ?? "Outros"}: ${widget.data.formatCount(widget.data.unassignedCount)}',
                            child: Container(
                              color: Colors.white24,
                              alignment: Alignment.center,
                              child: Text(
                                widget.data.unassignedCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Campo de busca rápida se houver muitos jogadores
        if (allItems.length > 6)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
            child: SizedBox(
              height: 38,
              child: TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Buscar jogador...',
                  hintStyle: const TextStyle(
                    color: Colors.white38,
                    fontSize: 13,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Colors.white38,
                    size: 18,
                  ),
                  filled: true,
                  fillColor: Colors.black26,
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          )
        else
          const SizedBox(height: 10),

        const Divider(color: Colors.white10, height: 16),

        // Lista Completa Ordenada do Maior para o Menor
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Text(
                    'Nenhum jogador encontrado com essa busca.',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                )
              : ListView.separated(
                  controller: widget.controller,
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  itemCount:
                      filtered.length +
                      (widget.data.unassignedCount > 0 ? 1 : 0),
                  separatorBuilder: (_, _) =>
                      const Divider(color: Colors.white10, height: 1),
                  itemBuilder: (ctx, index) {
                    // Item não atribuído (ex: gols sem assistência) ao final da lista
                    if (index == filtered.length) {
                      final double unassignedPct =
                          widget.data.totalReference > 0
                          ? (widget.data.unassignedCount /
                                  widget.data.totalReference) *
                              100
                          : 0.0;
                      final String formattedPct = unassignedPct % 1 == 0
                          ? '${unassignedPct.toInt()}%'
                          : '${unassignedPct.toStringAsFixed(1)}%';

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: const BoxDecoration(
                                color: Colors.white12,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.person_off,
                                size: 14,
                                color: Colors.white38,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                widget.data.unassignedLabel ??
                                    'Sem assistência / Gol individual',
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                            Text(
                              '${widget.data.formatCount(widget.data.unassignedCount)} ($formattedPct)',
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final realIndex = filtered[index];
                    final item = allItems[realIndex];
                    final color = getDistributionColor(realIndex);

                    return InkWell(
                      onTap: widget.onTapPlayer == null
                          ? null
                          : () {
                              Navigator.pop(context);
                              widget.onTapPlayer!(item.playerId, item.name);
                            },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 4,
                        ),
                        child: Row(
                          children: [
                            // Posição no ranking
                            Container(
                              width: 28,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '${realIndex + 1}º',
                                style: TextStyle(
                                  color: realIndex == 0
                                      ? const Color(0xFFFFD700)
                                      : realIndex == 1
                                      ? const Color(0xFFC0C0C0)
                                      : realIndex == 2
                                      ? const Color(0xFFCD7F32)
                                      : Colors.white54,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),

                            // Ponto colorido da barra
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Nome do jogador
                            Expanded(
                              child: Text(
                                item.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),

                            // Contagem e Porcentagem
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${widget.data.formatCount(item.count)} (${item.formattedPercentage})',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),

                            if (widget.onTapPlayer != null) ...[
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.chevron_right,
                                color: Colors.white24,
                                size: 16,
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
