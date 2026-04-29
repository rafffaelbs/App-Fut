import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../utils/constants.dart';

void showIconPickerModal({
  required BuildContext context,
  required List<String> takenIcons,
  required void Function(String) onSelected,
  String? currentIcon,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      return Container(
        decoration: const BoxDecoration(
          color: AppColors.headerBlue,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              "Escolher Ícone",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 400, // Altura fixa para scroll
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: (availablePlayerIcons.length / 4).ceil(),
                itemBuilder: (ctx, rowIndex) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: List.generate(4, (colIndex) {
                        final iconIndex = rowIndex * 4 + colIndex;
                        if (iconIndex >= availablePlayerIcons.length) {
                          return const Expanded(child: SizedBox());
                        }

                        final path = availablePlayerIcons[iconIndex];
                        final bool selected = currentIcon == path;
                        final bool isTaken = takenIcons.contains(path);

                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(right: colIndex < 3 ? 12 : 0),
                            child: GestureDetector(
                              onTap: isTaken
                                  ? null
                                  : () {
                                      onSelected(path);
                                      Navigator.pop(ctx);
                                    },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: selected
                                      ? AppColors.accentBlue.withValues(alpha: 0.25)
                                      : (isTaken
                                          ? Colors.black26
                                          : AppColors.deepBlue.withValues(alpha: 0.6)),
                                  border: Border.all(
                                    color: selected
                                        ? AppColors.accentBlue
                                        : (isTaken ? Colors.transparent : Colors.white12),
                                    width: selected ? 2 : 1,
                                  ),
                                ),
                                padding: const EdgeInsets.all(8),
                                child: Opacity(
                                  opacity: isTaken ? 0.2 : 1.0,
                                  child: Image.asset(
                                    path,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, _, _) => const Icon(
                                      Icons.person_outline,
                                      color: Colors.white38,
                                      size: 28,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}
