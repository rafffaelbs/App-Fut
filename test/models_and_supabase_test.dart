import 'package:flutter_test/flutter_test.dart';
import 'package:app_do_fut/models/player_model.dart';
import 'package:app_do_fut/models/group_member_model.dart';
import 'package:app_do_fut/models/season_model.dart';
import 'package:app_do_fut/models/session_model.dart';
import 'package:app_do_fut/models/match_model.dart';
import 'package:app_do_fut/models/match_lineup_model.dart';
import 'package:app_do_fut/models/match_event_model.dart';
import 'package:app_do_fut/models/rating_history_model.dart';
import 'package:app_do_fut/models/player_badge_model.dart';

void main() {
  group('PlayerModel & Lógica de Jogador Fantasma', () {
    test('Jogador fantasma deve ter creatorId == null e isGhost == true', () {
      final ghostPlayer = PlayerModel(
        id: '11111111-1111-1111-1111-111111111111',
        creatorId: null,
        name: 'Neymar da Pelada (Fantasma)',
        icon: 'assets/players_icons/neymar.png',
        manualBadges: const [
          PlayerBadgeModel(icon: '⚽', title: 'Artilheiro Nato'),
        ],
      );

      expect(ghostPlayer.isGhost, isTrue);
      expect(ghostPlayer.creatorId, isNull);

      final map = ghostPlayer.toMap();
      expect(map['creator_id'], isNull);
      expect(map['name'], equals('Neymar da Pelada (Fantasma)'));
    });

    test('Jogador autenticado deve ter creatorId preenchido e isGhost == false', () {
      final userPlayer = PlayerModel(
        id: '22222222-2222-2222-2222-222222222222',
        creatorId: 'auth-user-uuid-12345',
        name: 'Marinho Registrado',
      );

      expect(userPlayer.isGhost, isFalse);
      expect(userPlayer.creatorId, equals('auth-user-uuid-12345'));

      final map = userPlayer.toMap();
      expect(map['creator_id'], equals('auth-user-uuid-12345'));
    });

    test('Desserialização de Jogador a partir do Supabase', () {
      final rawSupabaseMap = {
        'id': '33333333-3333-3333-3333-333333333333',
        'creator_id': null,
        'name': 'Zico da Várzea',
        'icon': 'assets/players_icons/zico.png',
        'manual_badges': [
          {'icon': '⭐', 'title': 'Craque'},
        ],
        'created_at': '2026-09-12T15:00:00.000Z',
      };

      final jogador = PlayerModel.fromMap(rawSupabaseMap);
      expect(jogador.id, equals('33333333-3333-3333-3333-333333333333'));
      expect(jogador.isGhost, isTrue);
      expect(jogador.name, equals('Zico da Várzea'));
      expect(jogador.manualBadges.length, equals(1));
      expect(jogador.manualBadges.first.title, equals('Craque'));
      expect(jogador.createdAt, isNotNull);
    });
  });

  group('GroupMemberModel & Governança por Papel (admin vs member)', () {
    test('Membro com papel == "admin" tem isAdmin == true', () {
      final membroAdmin = GroupMemberModel(
        id: 'membro-1',
        groupId: 'grupo-1',
        playerId: 'jogador-1',
        role: 'admin',
      );

      expect(membroAdmin.isAdmin, isTrue);
      expect(membroAdmin.isMember, isFalse);
    });

    test('Membro com papel == "member" tem isAdmin == false', () {
      final membroComum = GroupMemberModel(
        id: 'membro-2',
        groupId: 'grupo-1',
        playerId: 'jogador-2',
        role: 'member',
      );

      expect(membroComum.isAdmin, isFalse);
      expect(membroComum.isMember, isTrue);
    });
  });

  group('SeasonModel & SessionModel', () {
    test('SeasonModel mapeia datas e flag isActive corretamente', () {
      final temporada = SeasonModel(
        id: 'temp-1',
        groupId: 'grp-1',
        name: '2026.1',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 6, 30),
        isActive: true,
      );

      final map = temporada.toMap();
      expect(map['is_active'], isTrue);
      expect(map['start_date'], equals('2026-01-01'));
      expect(map['end_date'], equals('2026-06-30'));
    });

    test('SessionModel mapeia status e status ao vivo', () {
      final sessao = SessionModel(
        id: 'sess-1',
        seasonId: 'temp-1',
        title: 'Pelada de Terça',
        timestamp: DateTime.now(),
        status: SessionModel.statusEmAndamento,
        durationMinutes: 90,
        winLimit: 3,
      );

      expect(sessao.isLive, isTrue);
      expect(sessao.winLimit, equals(3));
    });
  });

  group('MatchModel, Escalação, Eventos & Histórico de Ratings', () {
    test('Partida completa com escalação, eventos e ratings', () {
      final escalacoes = [
        const MatchLineupModel(
          matchId: 'part-1',
          playerId: 'jog-1',
          team: MatchLineupModel.teamA,
          rating: 8.5,
        ),
        const MatchLineupModel(
          matchId: 'part-1',
          playerId: 'jog-2',
          team: MatchLineupModel.teamB,
          isGoalkeeper: true,
          rating: 6.0,
        ),
      ];

      final eventos = [
        const MatchEventModel(
          matchId: 'part-1',
          playerId: 'jog-1',
          assistPlayerId: null,
          eventType: MatchEventModel.typeGoal,
        ),
      ];

      final partida = MatchModel(
        id: 'part-1',
        sessionId: 'sess-1',
        startTime: DateTime.now(),
        teamAScore: 1,
        teamBScore: 0,
        lineups: escalacoes,
        events: eventos,
      );

      expect(partida.redWon, isTrue);
      expect(partida.isDraw, isFalse);
      expect(partida.escalacao.length, equals(2));
      expect(partida.eventos.first.isGoal, isTrue);
    });

    test('RatingHistoryModel armazena rating resultante e playerId', () {
      final rating = RatingHistoryModel(
        id: 10,
        playerId: 'jog-ghost-1',
        matchId: 'part-1',
        ratingChange: 1.8,
        newRating: 7.8,
        createdAt: DateTime.now(),
      );

      expect(rating.newRating, equals(7.8));
      expect(rating.playerId, equals('jog-ghost-1'));
    });
  });
}
