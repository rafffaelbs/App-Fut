import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/session_model.dart';

class SessionListTile extends StatelessWidget {
  final SessionModel session;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const SessionListTile({
    super.key,
    required this.session,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final bool isLive = session.isLive;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.headerBlue,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isLive ? AppColors.accentBlue : AppColors.borderSubtle,
          width: isLive ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: isLive
                      ? AppColors.accentBlue
                      : AppColors.surfaceSubtle,
                  child: Icon(
                    Icons.sports_soccer,
                    color: isLive ? Colors.white : AppColors.textMuted,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              session.title,
                              style: const TextStyle(
                                color: AppColors.textWhite,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isLive)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.highlightGreen.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.highlightGreen),
                              ),
                              child: const Text(
                                "AO VIVO",
                                style: TextStyle(
                                  color: AppColors.highlightGreen,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            size: 13,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            session.date,
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                          ),
                          const SizedBox(width: 14),
                          const Icon(
                            Icons.people,
                            size: 14,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${session.playerCount}x${session.playerCount}',
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert,
                    color: AppColors.textDim,
                  ),
                  color: AppColors.surfaceElevated,
                  onSelected: (String value) {
                    if (value == 'edit') {
                      onEdit();
                    } else if (value == 'delete') {
                      onDelete();
                    }
                  },
                  itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(
                            Icons.edit,
                            color: Colors.white,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Editar',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete,
                            color: AppColors.redTeam,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Excluir',
                            style: TextStyle(
                              color: AppColors.redTeam,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
