import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/app_colors.dart';
import '../../models/milestone_update.dart';

class NotificationsSheet extends StatefulWidget {
  final String groupId;
  final String myPlayerId;
  final String playerName;
  final List<MilestoneUpdate> myUpdates;
  final VoidCallback? onCleared;

  const NotificationsSheet({
    super.key,
    required this.groupId,
    required this.myPlayerId,
    required this.playerName,
    required this.myUpdates,
    this.onCleared,
  });

  static Future<void> show({
    required BuildContext context,
    required String groupId,
    required String myPlayerId,
    required String playerName,
    required List<MilestoneUpdate> myUpdates,
    VoidCallback? onCleared,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NotificationsSheet(
        groupId: groupId,
        myPlayerId: myPlayerId,
        playerName: playerName,
        myUpdates: myUpdates,
        onCleared: onCleared,
      ),
    );
  }

  @override
  State<NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<NotificationsSheet> {
  @override
  void initState() {
    super.initState();
    _markAsRead();
  }

  Future<void> _markAsRead() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'last_seen_notif_${widget.groupId}_${widget.myPlayerId}',
        DateTime.now().toIso8601String(),
      );
      widget.onCleared?.call();
    } catch (_) {}
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inDays == 0) return 'Hoje';
    if (diff.inDays == 1) return 'Ontem';
    if (diff.inDays < 7) return 'Há ${diff.inDays} dias';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final updates = widget.myUpdates;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: AppColors.deepBlue,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.accentBlue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.accentBlue.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Icon(
                    Icons.notifications_active,
                    color: AppColors.accentBlueLight,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Minhas Notificações',
                        style: TextStyle(
                          color: AppColors.textWhite,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Atualizações de ${widget.playerName}',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.borderSubtle, height: 1),

          // List or Empty
          Flexible(
            child: updates.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 48,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.headerBlue,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.borderSubtle),
                          ),
                          child: const Icon(
                            Icons.emoji_events_outlined,
                            size: 48,
                            color: Colors.amber,
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Nenhuma notificação por enquanto',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textWhite,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Suas marcas de gols, jogos e feitos especiais aparecerão aqui conforme você joga!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textDim,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    itemCount: updates.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final item = updates[i];
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.headerBlue,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: item.color.withValues(alpha: 0.35),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: item.color.withValues(alpha: 0.08),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: item.color.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: item.color.withValues(alpha: 0.5),
                                ),
                              ),
                              child: Icon(item.icon, color: item.color, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.title.replaceAll(
                                            widget.playerName,
                                            'Você',
                                          ),
                                          style: const TextStyle(
                                            color: AppColors.textWhite,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        _formatDate(item.date),
                                        style: const TextStyle(
                                          color: AppColors.textDim,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item.description,
                                    style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
