import 'package:flutter/material.dart';

/// Item individual da distribuição de uma estatística de jogador (ex: Pessoa A, 3 gols, 30%).
class PlayerStatDistributionItem {
  final String playerId;
  final String name;
  final int count;
  final double percentage; // 0.0 a 100.0

  const PlayerStatDistributionItem({
    required this.playerId,
    required this.name,
    required this.count,
    required this.percentage,
  });

  /// Formata o percentual: exibe sem decimais se for exato (30%), ou com 1 decimal (33.3%).
  String get formattedPercentage {
    if (percentage % 1 == 0) {
      return '${percentage.toInt()}%';
    }
    return '${percentage.toStringAsFixed(1)}%';
  }
}

/// Metadados e lista completa de uma categoria de distribuição.
class PlayerStatCategoryData {
  final String id;
  final String title;
  final String subtitle;
  final String calculationExplanation;
  final IconData icon;
  final Color iconColor;
  final String unitLabel; // Plural, ex: "gols", "passes", "vitórias"
  final String unitLabelSingular; // Singular, ex: "gol", "passe", "vitória"
  final int totalReference;
  final String totalReferenceLabel;
  final List<PlayerStatDistributionItem> items;
  final int unassignedCount;
  final String? unassignedLabel;

  const PlayerStatCategoryData({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.calculationExplanation,
    required this.icon,
    required this.iconColor,
    required this.unitLabel,
    required this.unitLabelSingular,
    required this.totalReference,
    required this.totalReferenceLabel,
    required this.items,
    this.unassignedCount = 0,
    this.unassignedLabel,
  });

  bool get isEmpty => items.isEmpty;

  List<PlayerStatDistributionItem> get top3 => items.take(3).toList();

  String formatCount(int count) {
    return '$count ${count == 1 ? unitLabelSingular : unitLabel}';
  }
}
