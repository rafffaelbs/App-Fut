import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_do_fut/app/app_services.dart';
import 'package:app_do_fut/bootstrap_web.dart';
import 'package:app_do_fut/data/supabase/readonly/snapshot_source.dart';
import 'package:app_do_fut/main_web.dart';
import 'package:app_do_fut/models/group_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('extractTokenFromUrl', () {
    test('extrai token de fragmento com formato /#/g/<token>', () {
      final uri = Uri.parse('http://localhost:8080/#/g/token-12345');
      expect(extractTokenFromUrl(uri), 'token-12345');
    });

    test('extrai token de fragmento com query string /#/g/<token>?a=b', () {
      final uri = Uri.parse('https://app-fut.pages.dev/#/g/token-abc?ref=home');
      expect(extractTokenFromUrl(uri), 'token-abc');
    });

    test('extrai token de fragmento sem barra inicial #g/<token>', () {
      final uri = Uri.parse('https://app-fut.pages.dev/#g/token-sem-barra');
      expect(extractTokenFromUrl(uri), 'token-sem-barra');
    });

    test('rejeita rotas de pathSegments /g/<token> (aceita apenas fragmento)', () {
      final uri = Uri.parse('https://app-fut.pages.dev/g/token-direto');
      expect(extractTokenFromUrl(uri), isNull);
    });

    test('retorna nulo quando não há rota de grupo', () {
      expect(extractTokenFromUrl(Uri.parse('https://app-fut.pages.dev/')), isNull);
      expect(extractTokenFromUrl(Uri.parse('https://app-fut.pages.dev/#/')), isNull);
      expect(extractTokenFromUrl(Uri.parse('https://app-fut.pages.dev/#/home')), isNull);
      expect(extractTokenFromUrl(Uri.parse('https://app-fut.pages.dev/#/g/')), isNull);
    });
  });

  group('bootstrapWeb', () {
    test('retorna invalid quando token está vazio ou ausente', () async {
      final res = await bootstrapWeb(
        tokenOverride: '',
        initializeFlutterBinding: false,
      );
      expect(res.isInvalidLink, isTrue);
      expect(res.isValid, isFalse);
      expect(res.group, isNull);
    });

    test('retorna invalid quando ocorre InvalidLinkException', () async {
      final source = SnapshotSource(
        token: 'bad-token',
        rpcCaller: (token) async {
          throw const PostgrestException(
            message: 'invalid_link',
            code: 'P0001',
          );
        },
      );
      final res = await bootstrapWeb(
        tokenOverride: 'bad-token',
        snapshotSourceOverride: source,
        initializeFlutterBinding: false,
      );
      expect(res.isInvalidLink, isTrue);
      expect(res.isValid, isFalse);
    });

    test('retorna connectionError quando ocorre erro de rede ou timeout', () async {
      final source = SnapshotSource(
        token: 'net-token',
        rpcCaller: (token) async {
          throw Exception('SocketException: Failed host lookup');
        },
      );
      final res = await bootstrapWeb(
        tokenOverride: 'net-token',
        snapshotSourceOverride: source,
        initializeFlutterBinding: false,
      );
      expect(res.isConnectionError, isTrue);
      expect(res.isInvalidLink, isFalse);
      expect(res.isValid, isFalse);
    });

    test('retorna success e monta AppServices quando token e snapshot são válidos', () async {
      final source = SnapshotSource(
        token: 'good-token',
        initialData: {
          'group': {'id': 'grp-valid', 'name': 'Fut INF'},
          'seasons': [],
          'sessions': [],
          'players': [],
          'members': [],
          'matches': [],
          'lineups': [],
          'events': [],
        },
      );

      final res = await bootstrapWeb(
        tokenOverride: 'good-token',
        snapshotSourceOverride: source,
        initializeFlutterBinding: false,
      );

      expect(res.isSuccess, isTrue);
      expect(res.isValid, isTrue);
      expect(res.group, isNotNull);
      expect(res.group!.id, 'grp-valid');
      expect(res.group!.name, 'Fut INF');

      // Verifica AppServices montado com flags web_readonly
      expect(AppServices.isInitialized, isTrue);
      expect(AppServices.instance.features.isReadOnly, isTrue);
      expect(AppServices.instance.features.hasAuth, isFalse);
      expect(AppServices.instance.features.hasCosmetics, isTrue);
      expect(AppServices.instance.features.hasGoalSounds, isFalse);
      expect(AppServices.instance.siteSync, isNull);
      expect(AppServices.instance.diagnostics, isNull);
    });
  });

  group('AppWeb Widgets', () {
    testWidgets('exibe tela de link inválido quando result.isInvalidLink é true', (tester) async {
      await tester.pumpWidget(
        AppWeb(result: BootstrapWebResult.invalid()),
      );

      expect(
        find.text('Link inválido ou desativado. Peça um novo link ao administrador.'),
        findsOneWidget,
      );
      expect(find.byType(InvalidLinkScreen), findsOneWidget);
    });

    testWidgets('exibe tela de erro de conexão com botão Tentar de novo', (tester) async {
      int retryCount = 0;
      await tester.pumpWidget(
        AppWeb(
          result: BootstrapWebResult.connectionError(),
          bootstrapCaller: () async {
            retryCount++;
            return BootstrapWebResult.connectionError();
          },
        ),
      );

      expect(
        find.text('Não foi possível carregar. Verifique a internet'),
        findsOneWidget,
      );
      expect(find.byType(ConnectionErrorScreen), findsOneWidget);

      final retryBtn = find.text('Tentar de novo');
      expect(retryBtn, findsOneWidget);

      await tester.tap(retryBtn);
      await tester.pump();
      expect(retryCount, 1);
    });

    testWidgets('abre painel do grupo quando result é válido', (tester) async {
      final source = SnapshotSource(
        token: 'token-ui',
        initialData: {
          'group': {'id': 'grp-1', 'name': 'Grupo Teste'},
          'seasons': [],
          'sessions': [],
          'players': [],
          'members': [],
          'matches': [],
          'lineups': [],
          'events': [],
        },
      );

      await bootstrapWeb(
        tokenOverride: 'token-ui',
        snapshotSourceOverride: source,
        initializeFlutterBinding: false,
      );

      const group = GroupModel(id: 'grp-1', name: 'Grupo Teste');
      final result = BootstrapWebResult.success(group: group, snapshotSource: source);

      await tester.pumpWidget(AppWeb(result: result));
      await tester.pumpAndSettle();

      // Painel aberto com abas
      expect(find.text('Peladas'), findsWidgets);
      expect(find.text('Elenco'), findsWidgets);
      expect(find.text('Estatísticas'), findsWidgets);

      // Não exibe engrenagem de configurações nem botão de perfil
      expect(find.byIcon(Icons.settings), findsNothing);
      expect(find.byIcon(Icons.account_circle), findsNothing);
    });
  });
}
