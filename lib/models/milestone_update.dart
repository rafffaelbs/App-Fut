import 'package:flutter/material.dart';

enum MilestoneType {
  gamesSeason,
  gamesTotal,
  goalsSeason,
  goalsTotal,
  assistsSeason,
  assistsTotal,
  winsTotal,
  hatTrick,
  cleanSheet,
}

/// Representa uma atualização histórica/conquista de um jogador no grupo.
class MilestoneUpdate {
  final String id;
  final String playerId;
  final String playerName;
  final String? playerIcon;
  final String title;
  final String description;
  final DateTime date;
  final MilestoneType type;
  final int value;
  final IconData icon;
  final Color color;

  const MilestoneUpdate({
    required this.id,
    required this.playerId,
    required this.playerName,
    this.playerIcon,
    required this.title,
    required this.description,
    required this.date,
    required this.type,
    required this.value,
    required this.icon,
    required this.color,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'playerId': playerId,
      'playerName': playerName,
      'playerIcon': playerIcon,
      'title': title,
      'description': description,
      'date': date.toIso8601String(),
      'type': type.name,
      'value': value,
    };
  }
}
