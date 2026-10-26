import 'dart:async';
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../utils/constants.dart';
import '../../utils/player_identity.dart';

enum MatchExitType {
  removeWhite,
  removeRed,
  removeBoth,
  splitWinner,
}

/// Ação de saída e reorganização de times após o término de uma partida.
class MatchExitAction {
  final MatchExitType type;
  final String title;
  final String badgeText;
  final String description;
  final String leavingSummary;
  final String stayingSummary;
  final List<Map<String, dynamic>> leavers;
  final List<Map<String, dynamic>> entering;
  final List<Map<String, dynamic>>? splitWinners;
  final List<Map<String, dynamic>>? splitLosers;

  const MatchExitAction({
    required this.type,
    required this.title,
    required this.badgeText,
    required this.description,
    required this.leavingSummary,
    required this.stayingSummary,
    required this.leavers,
    required this.entering,
    this.splitWinners,
    this.splitLosers,
  });
}

/// Diálogo com confirmação explícita do que acontecerá ao encerrar a partida,
/// botões com peso visual equivalente e timer de proteção configurável.
class MatchFinishConfirmationDialog extends StatefulWidget {
  final int scoreRed;
  final int scoreWhite;
  final String resultTitle;
  final Color resultColor;
  final MatchExitAction defaultAction;
  final List<MatchExitAction> manualOptions;
  final bool timerEnabled;
  final int timerDurationSeconds;
  final ValueChanged<MatchExitAction> onConfirm;

  const MatchFinishConfirmationDialog({
    super.key,
    required this.scoreRed,
    required this.scoreWhite,
    required this.resultTitle,
    required this.resultColor,
    required this.defaultAction,
    required this.manualOptions,
    this.timerEnabled = true,
    this.timerDurationSeconds = kMatchFinishConfirmationDelaySeconds,
    required this.onConfirm,
  });

  @override
  State<MatchFinishConfirmationDialog> createState() =>
      _MatchFinishConfirmationDialogState();
}

class _MatchFinishConfirmationDialogState
    extends State<MatchFinishConfirmationDialog> {
  late MatchExitAction _currentAction;
  int _remainingSeconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _currentAction = widget.defaultAction;
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    if (!widget.timerEnabled || widget.timerDurationSeconds <= 0) {
      _remainingSeconds = 0;
      return;
    }

    setState(() {
      _remainingSeconds = widget.timerDurationSeconds;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_remainingSeconds > 1) {
          _remainingSeconds--;
        } else {
          _remainingSeconds = 0;
          timer.cancel();
        }
      });
    });
  }

  void _setAction(MatchExitAction action) {
    setState(() {
      _currentAction = action;
    });
    // Reinicia o timer sempre que a ação muda para garantir leitura
    _startTimer();
  }

  void _openManualSelection() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.deepBlue,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (bCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    'Escolha quem sai de campo:',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Divider(color: Colors.white24),
                ...widget.manualOptions.map((opt) {
                  final isSelected = opt.type == _currentAction.type;
                  return ListTile(
                    leading: Icon(
                      isSelected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: isSelected
                          ? AppColors.accentBlue
                          : AppColors.textMuted,
                    ),
                    title: Text(
                      opt.title,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      opt.description,
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 12),
                    ),
                    onTap: () {
                      Navigator.pop(bCtx);
                      _setAction(opt);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isConfirmDisabled = widget.timerEnabled && _remainingSeconds > 0;

    return PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: AppColors.headerBlue,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borderSubtle),
        ),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Column(
          children: [
            Text(
              widget.resultTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: widget.resultColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Placar Final: ${widget.scoreRed} x ${widget.scoreWhite}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              // Card destacado com a ação explícita
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.deepBlue.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.accentBlue.withValues(alpha: 0.7),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.accentBlue.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color:
                                  AppColors.accentBlue.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            _currentAction.badgeText.toUpperCase(),
                            style: const TextStyle(
                              color: AppColors.accentBlueLight,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _currentAction.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _currentAction.description,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    const Divider(color: Colors.white12, height: 20),
                    _buildDetailRow(
                      icon: Icons.logout,
                      iconColor: Colors.redAccent,
                      label: 'Sai:',
                      value: _currentAction.leavingSummary,
                    ),
                    const SizedBox(height: 6),
                    _buildDetailRow(
                      icon: Icons.check_circle_outline,
                      iconColor: Colors.greenAccent,
                      label: 'Fica:',
                      value: _currentAction.stayingSummary,
                    ),
                    const SizedBox(height: 6),
                    _buildDetailRow(
                      icon: Icons.login,
                      iconColor: AppColors.accentBlueLight,
                      label: 'Entra:',
                      value: _formatEnteringPlayers(_currentAction.entering),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          Row(
            children: [
              // Botão 1: "Alterar na Mão" com mesmo peso visual
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white38),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _openManualSelection,
                  icon: const Icon(Icons.tune, size: 18),
                  label: const Text(
                    'Alterar na Mão',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Botão 2: "Confirmar" com timer de proteção
              Expanded(
                child: Semantics(
                  enabled: !isConfirmDisabled,
                  label: isConfirmDisabled
                      ? 'Confirmar ação, aguarde $_remainingSeconds segundos'
                      : 'Confirmar ação',
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isConfirmDisabled
                          ? Colors.white12
                          : AppColors.accentBlue,
                      foregroundColor: isConfirmDisabled
                          ? Colors.white38
                          : AppColors.textWhite,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: isConfirmDisabled ? 0 : 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: isConfirmDisabled
                        ? null
                        : () {
                            Navigator.pop(context);
                            widget.onConfirm(_currentAction);
                          },
                    icon: Icon(
                      isConfirmDisabled ? Icons.hourglass_top : Icons.check,
                      size: 18,
                    ),
                    label: Text(
                      isConfirmDisabled
                          ? 'Confirmar ($_remainingSeconds)'
                          : 'Confirmar',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 16),
        const SizedBox(width: 6),
        Text(
          '$label ',
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  String _formatEnteringPlayers(List<Map<String, dynamic>> entering) {
    if (entering.isEmpty) return 'Nenhum jogador na fila';
    final names = entering
        .map((p) => (p['name'] ?? playerIdFromObject(p)).toString())
        .take(4)
        .toList();
    if (entering.length > 4) {
      return '${names.join(', ')} e +${entering.length - 4}';
    }
    return names.join(', ');
  }
}
