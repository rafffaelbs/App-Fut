import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_do_fut/models/player_stat_distribution.dart';
import 'package:app_do_fut/widgets/stats/player_stat_distribution_card.dart';

void main() {
  group('PlayerStatDistributionItem', () {
    test('formata percentual exato sem casas decimais e fracionário com 1 casa', () {
      const itemExact = PlayerStatDistributionItem(
        playerId: 'p1',
        name: 'Pessoa A',
        count: 3,
        percentage: 30.0,
      );
      expect(itemExact.formattedPercentage, '30%');

      const itemFractional = PlayerStatDistributionItem(
        playerId: 'p2',
        name: 'Pessoa B',
        count: 1,
        percentage: 33.333,
      );
      expect(itemFractional.formattedPercentage, '33.3%');
    });
  });

  group('PlayerStatCategoryData', () {
    test('valida o exemplo do usuário: 10 gols no total com Top 3 e distribuição completa', () {
      const totalGoals = 10;
      final items = [
        const PlayerStatDistributionItem(
          playerId: 'p1',
          name: 'Pessoa A',
          count: 3,
          percentage: (3 / totalGoals) * 100, // 30%
        ),
        const PlayerStatDistributionItem(
          playerId: 'p2',
          name: 'Pessoa B',
          count: 2,
          percentage: (2 / totalGoals) * 100, // 20%
        ),
        const PlayerStatDistributionItem(
          playerId: 'p3',
          name: 'Pessoa C',
          count: 2,
          percentage: (2 / totalGoals) * 100, // 20%
        ),
        const PlayerStatDistributionItem(
          playerId: 'p4',
          name: 'Pessoa D',
          count: 1,
          percentage: (1 / totalGoals) * 100, // 10%
        ),
        const PlayerStatDistributionItem(
          playerId: 'p5',
          name: 'Pessoa E',
          count: 1,
          percentage: (1 / totalGoals) * 100, // 10%
        ),
        const PlayerStatDistributionItem(
          playerId: 'p6',
          name: 'Pessoa F',
          count: 1,
          percentage: (1 / totalGoals) * 100, // 10%
        ),
      ];

      final category = PlayerStatCategoryData(
        id: 'topAssister',
        title: 'Garçom Favorito',
        subtitle: 'Quem mais deu assistências para seus gols',
        calculationExplanation:
            'Calculado sobre os seus $totalGoals gols marcados.',
        icon: Icons.handshake,
        iconColor: Colors.amber,
        unitLabel: 'gols seus',
        unitLabelSingular: 'gol seu',
        totalReference: totalGoals,
        totalReferenceLabel: '$totalGoals gols no total',
        items: items,
      );

      // Top 3 deve conter exatamente as 3 primeiras pessoas
      expect(category.top3.length, 3);
      expect(category.top3[0].name, 'Pessoa A');
      expect(category.top3[0].formattedPercentage, '30%');
      expect(category.top3[1].name, 'Pessoa B');
      expect(category.top3[1].formattedPercentage, '20%');
      expect(category.top3[2].name, 'Pessoa C');
      expect(category.top3[2].formattedPercentage, '20%');

      // Lista completa ordenada
      expect(category.items.length, 6);
      expect(category.items[3].name, 'Pessoa D');
      expect(category.items[3].formattedPercentage, '10%');
      expect(category.items[4].name, 'Pessoa E');
      expect(category.items[4].formattedPercentage, '10%');
      expect(category.items[5].name, 'Pessoa F');
      expect(category.items[5].formattedPercentage, '10%');

      // Formatação de contagem singular/plural
      expect(category.formatCount(1), '1 gol seu');
      expect(category.formatCount(3), '3 gols seus');
    });

    test('correção do bug do Plano de Ação: parceiro em 3 derrotas de 10 representa 30% das derrotas', () {
      const totalLosses = 10;
      const countWithPartner = 3;
      final pct = (countWithPartner / totalLosses) * 100;

      final item = PlayerStatDistributionItem(
        playerId: 'p_bad',
        name: 'Parceiro Azarado',
        count: countWithPartner,
        percentage: pct,
      );

      expect(item.formattedPercentage, '30%');
      expect(item.formattedPercentage, isNot('75%'));
    });
  });

  group('PlayerStatDistributionCard Widget', () {
    testWidgets('renderiza card com Top 3 e botão Ver mais', (tester) async {
      final category = PlayerStatCategoryData(
        id: 'topAssister',
        title: 'Garçom Favorito',
        subtitle: 'Quem mais deu passes para seus gols',
        calculationExplanation: 'Calculado sobre os seus 10 gols marcados.',
        icon: Icons.handshake,
        iconColor: Colors.amber,
        unitLabel: 'passes',
        unitLabelSingular: 'passe',
        totalReference: 10,
        totalReferenceLabel: '10 gols no total',
        items: const [
          PlayerStatDistributionItem(
            playerId: 'p1',
            name: 'Pessoa A',
            count: 3,
            percentage: 30.0,
          ),
          PlayerStatDistributionItem(
            playerId: 'p2',
            name: 'Pessoa B',
            count: 2,
            percentage: 20.0,
          ),
          PlayerStatDistributionItem(
            playerId: 'p3',
            name: 'Pessoa C',
            count: 2,
            percentage: 20.0,
          ),
          PlayerStatDistributionItem(
            playerId: 'p4',
            name: 'Pessoa D',
            count: 1,
            percentage: 10.0,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlayerStatDistributionCard(data: category),
          ),
        ),
      );

      // Título e total
      expect(find.text('Garçom Favorito'), findsOneWidget);
      expect(find.text('10 gols no total'), findsOneWidget);

      // Top 3 visíveis no card
      expect(find.text('Pessoa A'), findsOneWidget);
      expect(find.text('3 passes (30%)'), findsOneWidget);
      expect(find.text('Pessoa B'), findsOneWidget);
      expect(find.text('2 passes (20%)'), findsNWidgets(2)); // B e C
      expect(find.text('Pessoa C'), findsOneWidget);

      // Pessoa D (4º lugar) não deve estar no card (apenas no Ver mais)
      expect(find.text('Pessoa D'), findsNothing);

      // Botão Ver mais
      expect(find.text('Ver mais'), findsOneWidget);
    });

    testWidgets('renderiza estado vazio quando não há registros', (tester) async {
      const emptyCategory = PlayerStatCategoryData(
        id: 'topAssister',
        title: 'Garçom Favorito',
        subtitle: 'Quem mais deu passes para seus gols',
        calculationExplanation: 'Calculado sobre 0 gols.',
        icon: Icons.handshake,
        iconColor: Colors.amber,
        unitLabel: 'passes',
        unitLabelSingular: 'passe',
        totalReference: 0,
        totalReferenceLabel: '0 gols no total',
        items: [],
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PlayerStatDistributionCard(data: emptyCategory),
          ),
        ),
      );

      expect(find.text('Garçom Favorito'), findsOneWidget);
      expect(find.text('Nenhum registro para esta estatística.'), findsOneWidget);
      expect(find.text('Ver mais'), findsNothing);
    });

    testWidgets('clicar em Ver mais abre modal com distribuição e lista completa', (tester) async {
      String? tappedPlayerId;

      final category = PlayerStatCategoryData(
        id: 'topAssister',
        title: 'Garçom Favorito',
        subtitle: 'Quem mais deu passes para seus gols',
        calculationExplanation:
            'Calculado sobre os seus 10 gols marcados no total.',
        icon: Icons.handshake,
        iconColor: Colors.amber,
        unitLabel: 'passes',
        unitLabelSingular: 'passe',
        totalReference: 10,
        totalReferenceLabel: '10 gols no total',
        items: const [
          PlayerStatDistributionItem(
            playerId: 'p1',
            name: 'Pessoa A',
            count: 3,
            percentage: 30.0,
          ),
          PlayerStatDistributionItem(
            playerId: 'p2',
            name: 'Pessoa B',
            count: 2,
            percentage: 20.0,
          ),
          PlayerStatDistributionItem(
            playerId: 'p3',
            name: 'Pessoa C',
            count: 2,
            percentage: 20.0,
          ),
          PlayerStatDistributionItem(
            playerId: 'p4',
            name: 'Pessoa D',
            count: 1,
            percentage: 10.0,
          ),
        ],
        unassignedCount: 2,
        unassignedLabel: 'Gols individuais (sem assistência)',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlayerStatDistributionCard(
              data: category,
              onTapPlayer: (id, name) {
                tappedPlayerId = id;
              },
            ),
          ),
        ),
      );

      // Abre o modal clicando em Ver mais
      await tester.tap(find.text('Ver mais'));
      await tester.pumpAndSettle();

      // Modal aberto: deve conter a explicação dos parâmetros da conta
      expect(
        find.text('Calculado sobre os seus 10 gols marcados no total.'),
        findsOneWidget,
      );
      expect(find.text('Distribuição'), findsOneWidget);

      // Agora Pessoa D deve estar visível na lista completa
      expect(find.text('Pessoa D'), findsOneWidget);
      expect(find.text('1 passe (10%)'), findsOneWidget);

      // Gols não atribuídos / individuais
      expect(find.text('Gols individuais (sem assistência)'), findsOneWidget);
      expect(find.text('2 passes (20%)'), findsWidgets);

      // Clicar em um jogador aciona onTapPlayer
      await tester.tap(find.text('Pessoa D'));
      await tester.pumpAndSettle();

      expect(tappedPlayerId, 'p4');
    });
  });
}
