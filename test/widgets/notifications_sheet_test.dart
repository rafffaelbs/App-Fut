import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_do_fut/models/milestone_update.dart';
import 'package:app_do_fut/widgets/shared/notifications_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('NotificationsSheet exibe atualizações do jogador logado', (tester) async {
    final update1 = MilestoneUpdate(
      id: 'notif_1',
      playerId: 'p1',
      playerName: 'Enzo',
      title: 'Enzo alcançou 100 jogos na temporada',
      description: 'Grande regularidade!',
      date: DateTime(2026, 5, 10),
      type: MilestoneType.gamesSeason,
      value: 100,
      icon: Icons.calendar_month,
      color: Colors.blue,
    );

    final update2 = MilestoneUpdate(
      id: 'notif_2',
      playerId: 'p1',
      playerName: 'Enzo',
      title: 'Enzo alcançou 50 gols no total',
      description: 'Artilharia pura!',
      date: DateTime(2026, 5, 9),
      type: MilestoneType.goalsTotal,
      value: 50,
      icon: Icons.sports_soccer,
      color: Colors.amber,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NotificationsSheet(
            groupId: 'group1',
            myPlayerId: 'p1',
            playerName: 'Enzo',
            myUpdates: [update1, update2],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Minhas Notificações'), findsOneWidget);
    expect(find.text('Atualizações de Enzo'), findsOneWidget);
    expect(find.text('Você alcançou 100 jogos na temporada'), findsOneWidget);
    expect(find.text('Você alcançou 50 gols no total'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('last_seen_notif_group1_p1'), isNotNull);
  });

  testWidgets('NotificationsSheet exibe estado vazio quando sem novidades', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: NotificationsSheet(
            groupId: 'group1',
            myPlayerId: 'p2',
            playerName: 'Gabriel',
            myUpdates: [],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Minhas Notificações'), findsOneWidget);
    expect(find.text('Nenhuma notificação por enquanto'), findsOneWidget);
  });
}
