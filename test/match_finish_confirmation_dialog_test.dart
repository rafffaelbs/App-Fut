import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_do_fut/widgets/match/match_finish_confirmation_dialog.dart';

void main() {
  group('MatchFinishConfirmationDialog Widget Tests', () {
    final defaultAction = MatchExitAction(
      type: MatchExitType.removeWhite,
      title: 'Tirar o Time Branco',
      badgeText: 'Sugestão da Pelada',
      description: 'O time perdedor sai de campo.',
      leavingSummary: 'Time Branco (5 jogadores)',
      stayingSummary: 'Time Vermelho continua',
      leavers: [
        {'name': 'B1'},
        {'name': 'B2'}
      ],
      entering: [
        {'name': 'E1'},
        {'name': 'E2'}
      ],
    );

    final manualAction = MatchExitAction(
      type: MatchExitType.removeRed,
      title: 'Tirar o Time Vermelho',
      badgeText: 'Ação Manual',
      description: 'Saída manual do time vermelho.',
      leavingSummary: 'Time Vermelho (5 jogadores)',
      stayingSummary: 'Time Branco continua',
      leavers: [
        {'name': 'R1'},
        {'name': 'R2'}
      ],
      entering: [
        {'name': 'E1'},
        {'name': 'E2'}
      ],
    );

    testWidgets('Protection timer counts down 3 -> 2 -> 1 -> enabled', (tester) async {
      MatchExitAction? confirmedAction;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MatchFinishConfirmationDialog(
              scoreRed: 3,
              scoreWhite: 1,
              resultTitle: 'Vitória do VERMELHO!',
              resultColor: Colors.redAccent,
              defaultAction: defaultAction,
              manualOptions: [defaultAction, manualAction],
              timerEnabled: true,
              timerDurationSeconds: 3,
              onConfirm: (action) => confirmedAction = action,
            ),
          ),
        ),
      );

      // At t = 0s: button disabled, text 'Confirmar (3)'
      expect(find.text('Confirmar (3)'), findsOneWidget);
      final confirmBtnFinder = find.widgetWithText(ElevatedButton, 'Confirmar (3)');
      expect(confirmBtnFinder, findsOneWidget);
      final elevatedButton = tester.widget<ElevatedButton>(confirmBtnFinder);
      expect(elevatedButton.onPressed, isNull);

      // Advance 1s -> 'Confirmar (2)'
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Confirmar (2)'), findsOneWidget);

      // Advance 1s -> 'Confirmar (1)'
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Confirmar (1)'), findsOneWidget);

      // Advance 1s -> 'Confirmar' and enabled
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Confirmar'), findsOneWidget);
      final enabledBtn = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Confirmar'));
      expect(enabledBtn.onPressed, isNotNull);

      // Tap Confirm
      await tester.tap(find.widgetWithText(ElevatedButton, 'Confirmar'));
      await tester.pump();
      expect(confirmedAction, equals(defaultAction));
    });

    testWidgets('Timer disabled configuration allows immediate confirmation', (tester) async {
      MatchExitAction? confirmedAction;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MatchFinishConfirmationDialog(
              scoreRed: 2,
              scoreWhite: 0,
              resultTitle: 'Vitória do VERMELHO!',
              resultColor: Colors.redAccent,
              defaultAction: defaultAction,
              manualOptions: [defaultAction],
              timerEnabled: false,
              onConfirm: (action) => confirmedAction = action,
            ),
          ),
        ),
      );

      // Immediately enabled without countdown
      expect(find.text('Confirmar'), findsOneWidget);
      final btn = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Confirmar'));
      expect(btn.onPressed, isNotNull);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Confirmar'));
      await tester.pump();
      expect(confirmedAction, equals(defaultAction));
    });

    testWidgets('Selecting a manual option updates the action and resets timer', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MatchFinishConfirmationDialog(
              scoreRed: 3,
              scoreWhite: 1,
              resultTitle: 'Vitória do VERMELHO!',
              resultColor: Colors.redAccent,
              defaultAction: defaultAction,
              manualOptions: [defaultAction, manualAction],
              timerEnabled: true,
              timerDurationSeconds: 3,
              onConfirm: (_) {},
            ),
          ),
        ),
      );

      // Advance 2s -> countdown is at (1)
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Confirmar (1)'), findsOneWidget);

      // Tap 'Alterar na Mão'
      await tester.tap(find.text('Alterar na Mão'));
      await tester.pumpAndSettle();

      // Select 'Tirar o Time Vermelho'
      expect(find.text('Escolha quem sai de campo:'), findsOneWidget);
      await tester.tap(find.text('Tirar o Time Vermelho'));
      await tester.pumpAndSettle();

      // Dialog updated to new action
      expect(find.text('Tirar o Time Vermelho'), findsOneWidget);
      // Timer was reset to 3s!
      expect(find.text('Confirmar (3)'), findsOneWidget);
    });

    testWidgets('Both Alterar na Mão and Confirmar buttons have equal presence', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MatchFinishConfirmationDialog(
              scoreRed: 1,
              scoreWhite: 1,
              resultTitle: 'Empate!',
              resultColor: Colors.orangeAccent,
              defaultAction: defaultAction,
              manualOptions: [defaultAction],
              timerEnabled: false,
              onConfirm: (_) {},
            ),
          ),
        ),
      );

      expect(find.widgetWithText(OutlinedButton, 'Alterar na Mão'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Confirmar'), findsOneWidget);
    });
  });
}
