import 'dart:async';

import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../theme/app_theme.dart';

/// Header da partida estilo SofaScore: 72dp fixos, três colunas
/// (Time A · tempo + play/pause · Time B).
///
/// Os botões −/+ do placar ficam escondidos: toque longo no placar mostra
/// por alguns segundos (evita toque errado durante o jogo).
class MatchScoreboard extends StatefulWidget {
  static const double height = 72;

  final int scoreRed;
  final int scoreWhite;
  final double redTeamRating;
  final double whiteTeamRating;
  final String timeString;
  final bool isMatchRunning;
  final bool isOvertime;
  final bool isReadyToStart;

  final Function(bool isRed, int delta) onUpdateScore;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onStop;

  const MatchScoreboard({
    super.key,
    required this.scoreRed,
    required this.scoreWhite,
    required this.redTeamRating,
    required this.whiteTeamRating,
    required this.timeString,
    required this.isMatchRunning,
    required this.isOvertime,
    required this.isReadyToStart,
    required this.onUpdateScore,
    required this.onStart,
    required this.onPause,
    required this.onStop,
  });

  @override
  State<MatchScoreboard> createState() => _MatchScoreboardState();
}

class _MatchScoreboardState extends State<MatchScoreboard> {
  bool _showAdjust = false;
  Timer? _hideTimer;

  void _reveal() {
    _hideTimer?.cancel();
    setState(() => _showAdjust = true);
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showAdjust = false);
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _adjust(bool isRed, int delta) {
    widget.onUpdateScore(isRed, delta);
    _reveal(); // renova o tempo de exibição
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MatchScoreboard.height,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: AppColors.headerBlue,
        border: Border(bottom: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _team(
              name: 'Time Vermelho',
              asset: 'assets/images/vermelho.png',
              rating: widget.redTeamRating,
              isRed: true,
            ),
          ),
          _score(widget.scoreRed, true),
          SizedBox(width: 108, child: _center()),
          _score(widget.scoreWhite, false),
          Expanded(
            child: _team(
              name: 'Time Branco',
              asset: 'assets/images/branco.png',
              rating: widget.whiteTeamRating,
              isRed: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _team({
    required String name,
    required String asset,
    required double rating,
    required bool isRed,
  }) {
    final logo = Image.asset(
      asset,
      width: 32,
      height: 32,
      errorBuilder: (_, _, _) => Icon(
        Icons.checkroom,
        size: 28,
        color: isRed ? AppColors.redTeam : AppColors.whiteTeam,
      ),
    );
    final info = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          isRed ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star, color: AppColors.warning, size: 12),
            const SizedBox(width: 2),
            Text(
              rating.toStringAsFixed(1),
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
    final children = isRed
        ? [logo, const SizedBox(width: 6), Flexible(child: info)]
        : [Flexible(child: info), const SizedBox(width: 6), logo];
    return Row(
      mainAxisAlignment:
          isRed ? MainAxisAlignment.start : MainAxisAlignment.end,
      children: children,
    );
  }

  Widget _score(int value, bool isRed) {
    final number = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: _reveal,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text(
          '$value',
          style: AppTheme.number(
            fontSize: 40,
            fontWeight: FontWeight.w700,
            color: AppColors.textWhite,
          ),
        ),
      ),
    );
    if (!_showAdjust) return number;
    final minus = _adjustBtn(Icons.remove, () => _adjust(isRed, -1));
    final plus = _adjustBtn(Icons.add, () => _adjust(isRed, 1));
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [minus, number, plus],
    );
  }

  Widget _adjustBtn(IconData icon, VoidCallback onTap) {
    return SizedBox(
      width: 28,
      height: 28,
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 18,
        color: AppColors.highlightBlue,
        icon: Icon(icon),
        onPressed: onTap,
      ),
    );
  }

  Widget _center() {
    final timeColor = widget.isOvertime
        ? AppColors.redTeam
        : (widget.isMatchRunning
            ? AppColors.highlightGreen
            : AppColors.textMuted);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          widget.isOvertime ? '${widget.timeString} +' : widget.timeString,
          style: AppTheme.number(fontSize: 20, color: timeColor),
        ),
        const SizedBox(height: 2),
        if (!widget.isMatchRunning)
          _circle(
            AppColors.highlightGreen,
            Icons.play_arrow,
            widget.isReadyToStart ? widget.onStart : null,
          )
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _circle(AppColors.orangeStreak, Icons.pause, widget.onPause),
              const SizedBox(width: 12),
              _circle(AppColors.redTeam, Icons.stop, widget.onStop),
            ],
          ),
      ],
    );
  }

  Widget _circle(Color color, IconData icon, VoidCallback? onPressed) {
    final enabled = onPressed != null;
    return Material(
      color: enabled ? color : AppColors.surfaceSubtle,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(
            icon,
            size: 22,
            color: enabled ? AppColors.textWhite : AppColors.textDim,
          ),
        ),
      ),
    );
  }
}
