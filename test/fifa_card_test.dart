import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_do_fut/models/cosmetic_effect.dart';
import 'package:app_do_fut/utils/cosmetic_resolver.dart';
import 'package:app_do_fut/utils/overall_calculator.dart';
import 'package:app_do_fut/widgets/player/fifa_card.dart';
import 'package:app_do_fut/widgets/shared/player_avatar_frame.dart';

const _attrs = CommunityAttributes(pac: 80, sho: 75, pas: 70, dri: 82, def: 60, phy: 77);

final _frame = PlayerFrameInfo(resolveCosmetic(const PlayerCosmetics(
  goldenBall: true,
  nameEffect: CosmeticEffect.fire,
  monthlyStars: 3,
)));

Widget _card(CardDensity d, int ovr) => FifaCard(
      name: 'Arrascaeta',
      iconPath: 'assets/players_icons/arrascaeta.png',
      overall: ovr,
      attributes: _attrs,
      frame: _frame,
      density: d,
    );

Widget _harness(Widget child) => MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(backgroundColor: const Color(0xff0b1017), body: child),
    );

void main() {
  test('faixas de tier sem lacunas: 64/65, 74/75, 79/80, 84/85', () {
    expect(tierForOverall(0), CardTier.bronze);
    expect(tierForOverall(64), CardTier.bronze);
    expect(tierForOverall(65), CardTier.silver);
    expect(tierForOverall(74), CardTier.silver);
    expect(tierForOverall(75), CardTier.gold);
    expect(tierForOverall(79), CardTier.gold);
    expect(tierForOverall(80), CardTier.platinum);
    expect(tierForOverall(84), CardTier.platinum);
    expect(tierForOverall(85), CardTier.legendary);
    expect(tierForOverall(99), CardTier.legendary);
    expect(cardTierLabel(CardTier.legendary), 'Lendária');
    expect(cardPaletteFor(CardTier.platinum).border, isNotNull);
    expect(cardPaletteFor(CardTier.legendary).innerLine, isNotNull);
    expect(cardPaletteFor(CardTier.gold).border, isNull);
  });

  testWidgets('Bola de Ouro + Fogo + 3 estrelas renderiza nas 4 densidades',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    Widget row(int ovr) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final d in CardDensity.values)
              Padding(
                padding: const EdgeInsets.all(8),
                child: SizedBox(
                  width: switch (d) {
                    CardDensity.full => 200,
                    CardDensity.large => 132,
                    CardDensity.medium => 60,
                    CardDensity.small => 56,
                  },
                  child: _card(d, ovr),
                ),
              ),
          ],
        );

    await tester.pumpWidget(_harness(Column(children: [row(90), row(78)])));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(FifaCard), findsNWidgets(8));
    await expectLater(
        find.byType(Column).first, matchesGoldenFile('goldens/fifa_card_densities.png'));
  });

  testWidgets('atributos ficam abaixo da linha e o ritmo vertical é igual',
      (tester) async {
    await tester.pumpWidget(_harness(Center(
        child: SizedBox(width: 200, child: _card(CardDensity.full, 88)))));
    await tester.pumpAndSettle();

    final line = tester.getRect(find.byKey(const ValueKey('card-divider')));
    final attrs = tester.getRect(find.byKey(const ValueKey('card-attrs')));
    final name = tester.getRect(find.text('ARRASCAETA'));
    // A plaqueta/nome é centralizado em uma caixa; o gap é medido caixa → linha.
    expect(attrs.top, closeTo(line.bottom, 0.01));
    // PAC (80) e DRI (82), os da primeira fileira, ficam abaixo da linha.
    expect(tester.getRect(find.text('80')).top, greaterThan(line.bottom));
    expect(tester.getRect(find.text('82')).top, greaterThan(line.bottom));
    expect(name.bottom, lessThan(line.top));
  });

  testWidgets('nome sem sombra e chip (S) sem textura', (tester) async {
    await tester.pumpWidget(_harness(Column(children: [
      SizedBox(width: 200, child: _card(CardDensity.full, 70)),
      SizedBox(width: 56, child: _card(CardDensity.small, 70)),
    ])));
    await tester.pumpAndSettle();

    for (final t in tester.widgetList<Text>(find.byType(Text))) {
      expect(t.style?.shadows, isNull);
    }
    // Textura: 1 camada uniforme na carta cheia, nenhuma no chip.
    final patterns = tester.widgetList<Image>(find.byType(Image)).where((i) {
      final p = i.image;
      final inner = p is ResizeImage ? p.imageProvider : p;
      return inner is AssetImage && inner.assetName == FifaCard.patternAsset;
    });
    expect(patterns.length, 1);
  });
}
