import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/milestone_update.dart';
import '../models/player_model.dart';
import '../models/season_model.dart';
import '../models/session_model.dart';
import 'player_identity.dart';

const List<int> _kGameThresholds = [10, 25, 50, 75, 100, 150, 200, 250, 300, 400, 500];
const List<int> _kGoalThresholds = [10, 25, 50, 75, 100, 150, 200, 250, 300, 400, 500];
const List<int> _kAssistThresholds = [10, 25, 50, 75, 100, 150, 200];
const List<int> _kWinThresholds = [10, 25, 50, 75, 100, 150, 200, 250, 300];
const List<int> _kCleanSheetThresholds = [5, 10, 25, 50, 75, 100];

/// Analisa cronologicamente as partidas e identifica as marcas históricas
/// atingidas pelos jogadores (ordenadas da mais recente para a menos recente).
List<MilestoneUpdate> computeGroupMilestones({
  required List<dynamic> allHistory,
  required List<SessionModel> sessions,
  required List<PlayerModel> players,
  SeasonModel? currentSeason,
}) {
  if (allHistory.isEmpty) return const [];

  final Map<String, String> namesById = {
    for (final p in players) p.id: p.displayName,
  };
  final Map<String, String?> iconsById = {
    for (final p in players) p.id: p.icon,
  };

  // Garante ordenação cronológica crescente (do mais antigo para o mais recente)
  // para acumular as contagens corretamente.
  final sortedMatches = List<dynamic>.from(allHistory);
  sortedMatches.sort((a, b) {
    final da = _parseMatchDate(a);
    final db = _parseMatchDate(b);
    return da.compareTo(db);
  });

  final Map<String, int> totalGames = {};
  final Map<String, int> seasonGames = {};
  final Map<String, int> totalGoals = {};
  final Map<String, int> seasonGoals = {};
  final Map<String, int> totalAssists = {};
  final Map<String, int> seasonAssists = {};
  final Map<String, int> totalWins = {};
  final Map<String, int> totalCleanSheets = {};

  final List<MilestoneUpdate> milestones = [];

  for (final match in sortedMatches) {
    if (match is! Map) continue;
    final matchId = (match['id'] ?? '').toString();
    final matchDate = _parseMatchDate(match);

    final bool inSeason = _isMatchInSeason(matchDate, currentSeason);

    final int scoreRed = (match['scoreRed'] as num?)?.toInt() ?? 0;
    final int scoreWhite = (match['scoreWhite'] as num?)?.toInt() ?? 0;
    final bool redWon = scoreRed > scoreWhite;
    final bool whiteWon = scoreWhite > scoreRed;

    // Jogadores da partida
    final playersMap = match['players'] as Map?;
    final List<dynamic> redList = List<dynamic>.from(playersMap?['red'] ?? []);
    final List<dynamic> whiteList = List<dynamic>.from(playersMap?['white'] ?? []);
    final dynamic gkRed = playersMap?['gk_red'];
    final dynamic gkWhite = playersMap?['gk_white'];

    final Set<String> processedPlayers = {};
    final Map<String, int> goalsInMatch = {};

    void processParticipation(dynamic pObj, bool isRed, bool isGk) {
      if (pObj == null) return;
      final pid = playerIdFromObject(pObj);
      if (pid.isEmpty || processedPlayers.contains(pid)) return;
      processedPlayers.add(pid);

      final pName = namesById[pid] ?? (pObj['name'] ?? pid).toString();
      final pIcon = iconsById[pid] ?? pObj['icon']?.toString();

      // Jogos no total
      final prevTotalGames = totalGames[pid] ?? 0;
      final newTotalGames = prevTotalGames + 1;
      totalGames[pid] = newTotalGames;
      _checkThreshold(
        prev: prevTotalGames,
        next: newTotalGames,
        thresholds: _kGameThresholds,
        onCrossed: (val) {
          milestones.add(MilestoneUpdate(
            id: '${matchId}_${pid}_gt_$val',
            playerId: pid,
            playerName: pName,
            playerIcon: pIcon,
            title: '$pName alcançou $val jogos no total',
            description: 'Marca histórica acumulada em todas as partidas do grupo.',
            date: matchDate,
            type: MilestoneType.gamesTotal,
            value: val,
            icon: Icons.military_tech,
            color: AppColors.accentBlueLight,
          ));
        },
      );

      // Jogos na temporada
      if (inSeason) {
        final prevSeasonGames = seasonGames[pid] ?? 0;
        final newSeasonGames = prevSeasonGames + 1;
        seasonGames[pid] = newSeasonGames;
        _checkThreshold(
          prev: prevSeasonGames,
          next: newSeasonGames,
          thresholds: _kGameThresholds,
          onCrossed: (val) {
            milestones.add(MilestoneUpdate(
              id: '${matchId}_${pid}_gs_$val',
              playerId: pid,
              playerName: pName,
              playerIcon: pIcon,
              title: '$pName alcançou $val jogos na temporada',
              description: 'Grande regularidade na temporada atual!',
              date: matchDate,
              type: MilestoneType.gamesSeason,
              value: val,
              icon: Icons.calendar_month,
              color: AppColors.accentBlueLight,
            ));
          },
        );
      }

      // Vitórias
      final bool won = isRed ? redWon : whiteWon;
      if (won) {
        final prevWins = totalWins[pid] ?? 0;
        final newWins = prevWins + 1;
        totalWins[pid] = newWins;
        _checkThreshold(
          prev: prevWins,
          next: newWins,
          thresholds: _kWinThresholds,
          onCrossed: (val) {
            milestones.add(MilestoneUpdate(
              id: '${matchId}_${pid}_w_$val',
              playerId: pid,
              playerName: pName,
              playerIcon: pIcon,
              title: '$pName alcançou $val vitórias no total',
              description: 'Histórico vitorioso no grupo.',
              date: matchDate,
              type: MilestoneType.winsTotal,
              value: val,
              icon: Icons.emoji_events,
              color: Colors.amberAccent,
            ));
          },
        );
      }

      // Clean sheet de goleiro
      if (isGk) {
        final conceded = isRed ? scoreWhite : scoreRed;
        if (conceded == 0) {
          final prevCS = totalCleanSheets[pid] ?? 0;
          final newCS = prevCS + 1;
          totalCleanSheets[pid] = newCS;
          _checkThreshold(
            prev: prevCS,
            next: newCS,
            thresholds: _kCleanSheetThresholds,
            onCrossed: (val) {
              milestones.add(MilestoneUpdate(
                id: '${matchId}_${pid}_cs_$val',
                playerId: pid,
                playerName: pName,
                playerIcon: pIcon,
                title: '$pName alcançou $val clean sheets (jogos sem sofrer gol)',
                description: 'Muralha na trave!',
                date: matchDate,
                type: MilestoneType.cleanSheet,
                value: val,
                icon: Icons.shield_outlined,
                color: Colors.greenAccent,
              ));
            },
          );
        }
      }
    }

    for (final p in redList) {
      processParticipation(p, true, false);
    }
    processParticipation(gkRed, true, true);

    for (final p in whiteList) {
      processParticipation(p, false, false);
    }
    processParticipation(gkWhite, false, true);

    // Processa eventos (gols e assistências)
    final events = match['events'] as List?;
    if (events != null) {
      for (final ev in events) {
        if (ev is! Map) continue;
        final type = ev['type'];
        final pid = eventPlayerId(ev, 'player');
        final astId = eventPlayerId(ev, 'assist');

        if (type == 'goal' && pid.isNotEmpty) {
          goalsInMatch[pid] = (goalsInMatch[pid] ?? 0) + 1;

          final pName = namesById[pid] ?? pid;
          final pIcon = iconsById[pid];

          // Gols no total
          final prevGoals = totalGoals[pid] ?? 0;
          final newGoals = prevGoals + 1;
          totalGoals[pid] = newGoals;
          _checkThreshold(
            prev: prevGoals,
            next: newGoals,
            thresholds: _kGoalThresholds,
            onCrossed: (val) {
              milestones.add(MilestoneUpdate(
                id: '${matchId}_${pid}_gtot_$val',
                playerId: pid,
                playerName: pName,
                playerIcon: pIcon,
                title: '$pName alcançou $val gols no total',
                description: 'Marca histórica de artilharia no grupo!',
                date: matchDate,
                type: MilestoneType.goalsTotal,
                value: val,
                icon: Icons.sports_soccer,
                color: Colors.amber,
              ));
            },
          );

          // Gols na temporada
          if (inSeason) {
            final prevSGoals = seasonGoals[pid] ?? 0;
            final newSGoals = prevSGoals + 1;
            seasonGoals[pid] = newSGoals;
            _checkThreshold(
              prev: prevSGoals,
              next: newSGoals,
              thresholds: _kGoalThresholds,
              onCrossed: (val) {
                milestones.add(MilestoneUpdate(
                  id: '${matchId}_${pid}_gseas_$val',
                  playerId: pid,
                  playerName: pName,
                  playerIcon: pIcon,
                  title: '$pName alcançou $val gols na temporada',
                  description: 'Artilheiro nato na temporada atual.',
                  date: matchDate,
                  type: MilestoneType.goalsSeason,
                  value: val,
                  icon: Icons.sports_soccer,
                  color: Colors.amber,
                ));
              },
            );
          }
        }

        if (type == 'goal' && astId.isNotEmpty) {
          final astName = namesById[astId] ?? astId;
          final astIcon = iconsById[astId];

          // Assistências no total
          final prevAst = totalAssists[astId] ?? 0;
          final newAst = prevAst + 1;
          totalAssists[astId] = newAst;
          _checkThreshold(
            prev: prevAst,
            next: newAst,
            thresholds: _kAssistThresholds,
            onCrossed: (val) {
              milestones.add(MilestoneUpdate(
                id: '${matchId}_${astId}_atot_$val',
                playerId: astId,
                playerName: astName,
                playerIcon: astIcon,
                title: '$astName alcançou $val assistências no total',
                description: 'Visão de jogo impressionante no grupo.',
                date: matchDate,
                type: MilestoneType.assistsTotal,
                value: val,
                icon: Icons.handshake_outlined,
                color: Colors.cyanAccent,
              ));
            },
          );

          // Assistências na temporada
          if (inSeason) {
            final prevSAst = seasonAssists[astId] ?? 0;
            final newSAst = prevSAst + 1;
            seasonAssists[astId] = newSAst;
            _checkThreshold(
              prev: prevSAst,
              next: newSAst,
              thresholds: _kAssistThresholds,
              onCrossed: (val) {
                milestones.add(MilestoneUpdate(
                  id: '${matchId}_${astId}_aseas_$val',
                  playerId: astId,
                  playerName: astName,
                  playerIcon: astIcon,
                  title: '$astName alcançou $val assistências na temporada',
                  description: 'Garçom de elite na temporada!',
                  date: matchDate,
                  type: MilestoneType.assistsSeason,
                  value: val,
                  icon: Icons.handshake_outlined,
                  color: Colors.cyanAccent,
                ));
              },
            );
          }
        }
      }
    }

    // Hat-trick na partida (3 ou mais gols)
    goalsInMatch.forEach((pid, gCount) {
      if (gCount >= 3) {
        final pName = namesById[pid] ?? pid;
        final pIcon = iconsById[pid];
        milestones.add(MilestoneUpdate(
          id: '${matchId}_${pid}_hattrick',
          playerId: pid,
          playerName: pName,
          playerIcon: pIcon,
          title: '$pName marcou um hat-trick ($gCount gols na partida)!',
          description: 'Atuação de gala na rodada.',
          date: matchDate,
          type: MilestoneType.hatTrick,
          value: gCount,
          icon: Icons.local_fire_department,
          color: Colors.deepOrangeAccent,
        ));
      }
    });
  }

  // Ordena do mais recente para o menos recente
  milestones.sort((a, b) => b.date.compareTo(a.date));

  return milestones;
}

void _checkThreshold({
  required int prev,
  required int next,
  required List<int> thresholds,
  required void Function(int val) onCrossed,
}) {
  for (final t in thresholds) {
    if (prev < t && next >= t) {
      onCrossed(t);
    }
  }
}

DateTime _parseMatchDate(dynamic match) {
  if (match is Map) {
    final raw = match['session_date'] ?? match['date'] ?? match['start_time'];
    if (raw != null) {
      final parsed = DateTime.tryParse(raw.toString());
      if (parsed != null) return parsed;
    }
  }
  return DateTime.fromMillisecondsSinceEpoch(0);
}

bool _isMatchInSeason(DateTime matchDate, SeasonModel? currentSeason) {
  if (currentSeason == null) {
    // Fallback: mesmo ano calendário
    return matchDate.year == DateTime.now().year;
  }
  if (currentSeason.startDate != null) {
    if (matchDate.isBefore(currentSeason.startDate!)) return false;
  }
  if (currentSeason.endDate != null) {
    // Fim da data do endDate (inclusivo)
    final endLimit = currentSeason.endDate!.add(const Duration(days: 1));
    if (matchDate.isAfter(endLimit)) return false;
  }
  return true;
}
