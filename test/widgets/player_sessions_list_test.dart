import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_do_fut/utils/player_session_summary.dart';
import 'package:app_do_fut/widgets/player/player_sessions_list.dart';

PlayerSessionSummary _s(int i) => PlayerSessionSummary(
      sessionId: 's$i',
      date: DateTime(2026, 10, 30 - i),
      goals: i,
      assists: 1,
      wins: 2,
      draws: 1,
      losses: 0,
    );

Widget _host(Widget child) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  testWidgets('mostra 3 peladas e o botão "Ver mais"', (tester) async {
    await tester.pumpWidget(_host(PlayerSessionsList(
      summaries: [for (var i = 0; i < 5; i++) _s(i)],
      titles: const {'s0': 'Pelada de quinta'},
    )));

    expect(find.byType(PlayerSessionTile), findsNWidgets(3));
    expect(find.text('Ver mais'), findsOneWidget);
    expect(find.text('Pelada de quinta'), findsOneWidget);
    // Sem nome no cache: usa a data.
    expect(find.text('Pelada de 29/10/2026'), findsOneWidget);
    expect(find.text('Sem peladas no período'), findsNothing);
  });

  testWidgets('"Ver mais" abre a lista completa e rolável', (tester) async {
    await tester.pumpWidget(_host(PlayerSessionsList(
      summaries: [for (var i = 0; i < 12; i++) _s(i)],
    )));

    await tester.tap(find.text('Ver mais'));
    await tester.pumpAndSettle();

    expect(find.text('Peladas (12)'), findsOneWidget);
    // Rola até a última pelada da lista completa.
    await tester.scrollUntilVisible(
      find.text('Pelada de 19/10/2026'),
      200,
      scrollable: find.descendant(
        of: find.byType(DraggableScrollableSheet),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('Pelada de 19/10/2026'), findsOneWidget);
  });

  testWidgets('com 3 ou menos peladas não mostra "Ver mais"', (tester) async {
    await tester.pumpWidget(_host(PlayerSessionsList(
      summaries: [for (var i = 0; i < 3; i++) _s(i)],
    )));
    expect(find.byType(PlayerSessionTile), findsNWidgets(3));
    expect(find.text('Ver mais'), findsNothing);
  });

  testWidgets('estado vazio: "Sem peladas no período"', (tester) async {
    await tester.pumpWidget(_host(const PlayerSessionsList(summaries: [])));
    expect(find.text('Sem peladas no período'), findsOneWidget);
    expect(find.byType(PlayerSessionTile), findsNothing);
    expect(find.text('Ver mais'), findsNothing);
  });
}
