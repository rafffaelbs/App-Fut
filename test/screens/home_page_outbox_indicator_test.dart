import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_do_fut/constants/app_colors.dart';
import 'package:app_do_fut/domain/services/match_outbox.dart';
import 'package:app_do_fut/main_personal.dart';
import '../helpers/test_app_services.dart';

class FakeMatchOutbox implements MatchOutbox {
  final ValueNotifier<int> pendingNotifier;
  final ValueNotifier<int> failedNotifier;
  final ValueNotifier<String?> lastErrorNotifier;

  FakeMatchOutbox({int pending = 0, int failed = 0})
      : pendingNotifier = ValueNotifier<int>(pending),
        failedNotifier = ValueNotifier<int>(failed),
        lastErrorNotifier = ValueNotifier<String?>(null);

  @override
  ValueListenable<int> get pending => pendingNotifier;

  @override
  ValueListenable<int> get failed => failedNotifier;

  @override
  ValueListenable<String?> get lastError => lastErrorNotifier;

  @override
  Future<void> enqueue(Map<String, dynamic> job) async {}

  @override
  Future<void> flush() async {}

  @override
  Future<void> refreshCounts() async {}

  @override
  Future<List<Map<String, dynamic>>> failedJobs() async => [];

  @override
  Future<void> retryFailed(String matchId) async {}

  @override
  Future<void> discardFailed(String matchId) async {}
}

void main() {
  late FakeMatchOutbox fakeOutbox;

  setUp(() {
    fakeOutbox = FakeMatchOutbox();
    setupTestAppServices(
      outbox: fakeOutbox,
    );
  });

  group('HomePage indicador de partidas pendentes no AppBar', () {
    testWidgets('(a) com outbox falso pending=0 e failed=0 o ícone não aparece', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: HomePage()),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.cloud_upload_outlined), findsNothing);
      expect(find.byIcon(Icons.cloud_off_outlined), findsNothing);
    });

    testWidgets('(b) com pending>0 aparece na cor neutra', (tester) async {
      fakeOutbox.pendingNotifier.value = 2;

      await tester.pumpWidget(
        const MaterialApp(home: HomePage()),
      );
      await tester.pumpAndSettle();

      final iconFinder = find.byIcon(Icons.cloud_upload_outlined);
      expect(iconFinder, findsOneWidget);

      final iconWidget = tester.widget<Icon>(iconFinder);
      expect(iconWidget.color, isNot(AppColors.danger));
    });

    testWidgets('(c) com failed>0 aparece na cor de alerta', (tester) async {
      fakeOutbox.failedNotifier.value = 1;

      await tester.pumpWidget(
        const MaterialApp(home: HomePage()),
      );
      await tester.pumpAndSettle();

      final iconFinder = find.byIcon(Icons.cloud_off_outlined);
      expect(iconFinder, findsOneWidget);

      final iconWidget = tester.widget<Icon>(iconFinder);
      expect(iconWidget.color, AppColors.danger);
    });

    testWidgets('(d) o ícone reage quando as contagens mudam', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: HomePage()),
      );
      await tester.pumpAndSettle();

      // Inicialmente nada
      expect(find.byIcon(Icons.cloud_upload_outlined), findsNothing);
      expect(find.byIcon(Icons.cloud_off_outlined), findsNothing);

      // Incrementa pending -> aparece neutro
      fakeOutbox.pendingNotifier.value = 3;
      await tester.pump();
      expect(find.byIcon(Icons.cloud_upload_outlined), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off_outlined), findsNothing);

      // Incrementa failed -> muda para ícone de alerta
      fakeOutbox.failedNotifier.value = 1;
      await tester.pump();
      expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
      expect(find.byIcon(Icons.cloud_upload_outlined), findsNothing);

      // Zera ambos -> desaparece
      fakeOutbox.pendingNotifier.value = 0;
      fakeOutbox.failedNotifier.value = 0;
      await tester.pump();
      expect(find.byIcon(Icons.cloud_upload_outlined), findsNothing);
      expect(find.byIcon(Icons.cloud_off_outlined), findsNothing);
    });

    testWidgets('ao tocar no ícone abre diálogo simples com contagens e instrução', (tester) async {
      fakeOutbox.pendingNotifier.value = 2;
      fakeOutbox.failedNotifier.value = 1;

      await tester.pumpWidget(
        const MaterialApp(home: HomePage()),
      );
      await tester.pumpAndSettle();

      final cloudButton = find.byIcon(Icons.cloud_off_outlined);
      expect(cloudButton, findsOneWidget);

      await tester.tap(cloudButton);
      await tester.pumpAndSettle();

      expect(find.text('2 partida(s) aguardando envio'), findsOneWidget);
      expect(find.text('1 partida(s) com problema'), findsOneWidget);
      expect(find.text('Abra a pelada para ver os detalhes e tentar de novo'), findsOneWidget);
    });
  });
}
