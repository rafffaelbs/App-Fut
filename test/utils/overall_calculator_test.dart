import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_do_fut/constants/app_colors.dart';
import 'package:app_do_fut/utils/overall_calculator.dart';

void main() {
  group('overall_calculator characterization tests', () {
    group('appRatingTo100', () {
      test('case 1: zero rating (0.0 -> 0.0)', () {
        expect(appRatingTo100(0.0), equals(0.0));
      });

      test('case 2: base rating (7.0 -> 70.0)', () {
        expect(appRatingTo100(7.0), equals(70.0));
      });

      test('case 3: decimal rating (8.45 -> 84.5)', () {
        expect(appRatingTo100(8.45), closeTo(84.5, 1e-4));
      });

      test('case 4: max rating (10.0 -> 100.0)', () {
        expect(appRatingTo100(10.0), equals(100.0));
      });

      test('case 5: boundary clamps (below 0 -> 0.0, above 10 -> 100.0)', () {
        expect(appRatingTo100(-2.5), equals(0.0));
        expect(appRatingTo100(12.5), equals(100.0));
      });
    });

    group('calculateOverall', () {
      test('case 1: player without community rating (community: null -> uses 50.0 neutral)', () {
        // appRating10 = 7.0 -> app100 = 70.0. comm = 50.0.
        // raw = 70.0 * 0.3 + 50.0 * 0.7 = 21.0 + 35.0 = 56.0 -> 56
        final overall = calculateOverall(appRating10: 7.0, community: null);
        expect(overall, equals(56));
      });

      test('case 2: player with CommunityAttributes.empty (no attributes -> uses 50.0 neutral)', () {
        final overall = calculateOverall(
          appRating10: 8.0,
          community: CommunityAttributes.empty,
        );
        // app100 = 80.0 -> 80 * 0.3 (24) + 50 * 0.7 (35) = 59
        expect(overall, equals(59));
      });

      test('case 3: player with all 6 community attributes (uses average)', () {
        const community = CommunityAttributes(
          pac: 80,
          sho: 85,
          pas: 90,
          dri: 75,
          def: 70,
          phy: 80,
        );
        // avg = (80+85+90+75+70+80) / 6 = 480 / 6 = 80.0
        // appRating10 = 9.0 -> app100 = 90.0
        // raw = 90.0 * 0.3 (27) + 80.0 * 0.7 (56) = 83.0 -> 83
        final overall = calculateOverall(appRating10: 9.0, community: community);
        expect(overall, equals(83));
      });

      test('case 4: player with ratingOverride (overrides average)', () {
        const community = CommunityAttributes(
          pac: 50,
          sho: 50,
          pas: 50,
          dri: 50,
          def: 50,
          phy: 50,
          ratingOverride: 95.0,
        );
        // ratingOverride is 95.0, overriding the 50.0 average
        // appRating10 = 8.0 -> app100 = 80.0
        // raw = 80 * 0.3 (24) + 95 * 0.7 (66.5) = 90.5 -> round() = 91
        final overall = calculateOverall(appRating10: 8.0, community: community);
        expect(overall, equals(91));
      });

      test('case 5: boundary limits (min 0, max clamped at kOverallMax 99)', () {
        // Lower limit
        final minOverall = calculateOverall(
          appRating10: 0.0,
          community: const CommunityAttributes(ratingOverride: 0.0),
        );
        expect(minOverall, equals(0));

        // Upper limit: even with 10.0 and 100 comm -> 100.0, clamped at kOverallMax (99)
        final maxOverall = calculateOverall(
          appRating10: 10.0,
          community: const CommunityAttributes(ratingOverride: 100.0),
        );
        expect(maxOverall, equals(99));
      });

      test('case 6: partial community attributes without override fallback to neutral 50.0', () {
        // Missing def and phy
        const community = CommunityAttributes(
          pac: 90,
          sho: 90,
          pas: 90,
          dri: 90,
        );
        expect(community.hasAllAttributes, isFalse);
        expect(community.communityRating, isNull);

        // Fallback to 50.0: app100 = 70 * 0.3 (21) + 50 * 0.7 (35) = 56
        final overall = calculateOverall(appRating10: 7.0, community: community);
        expect(overall, equals(56));
      });
    });

    group('playerOverallOf', () {
      test('case 1: map contains explicit overall number', () {
        final player = {'overall': 87};
        expect(playerOverallOf(player), equals(87.0));
      });

      test('case 2: map contains rating and community object', () {
        const comm = CommunityAttributes(ratingOverride: 80.0);
        final player = {'rating': 8.0, 'community': comm};
        // app100 = 80 (24) + 80 * 0.7 (56) = 80
        expect(playerOverallOf(player), equals(80.0));
      });

      test('case 3: map contains rating and flat community_* keys', () {
        final player = {
          'rating': 7.0,
          'community_pac': 80,
          'community_sho': 80,
          'community_pas': 80,
          'community_dri': 80,
          'community_def': 80,
          'community_phy': 80,
        };
        // avg = 80.0, app = 70.0 -> 21 + 56 = 77
        expect(playerOverallOf(player), equals(77.0));
      });

      test('case 4: map with no rating and no community (uses fallbacks)', () {
        final player = <String, dynamic>{'name': 'Novato'};
        // fallback app rating = 7.0 (app100 = 70) and neutral community = 50.0
        // raw = 21 + 35 = 56
        expect(playerOverallOf(player), equals(56.0));
      });

      test('case 5: map with non-numeric overall falls back to calculation', () {
        final player = {
          'overall': 'not_a_number',
          'rating': 9.0,
          'community_rating_override': 90.0,
        };
        // app100 = 90 (27) + 90 * 0.7 (63) = 90
        expect(playerOverallOf(player), equals(90.0));
      });
    });

    group('tierForOverall', () {
      test('case 1: overall 0 -> CardTier.gold', () {
        expect(tierForOverall(0), equals(CardTier.gold));
      });

      test('case 2: overall 79 -> CardTier.gold', () {
        expect(tierForOverall(79), equals(CardTier.gold));
      });

      test('case 3: overall 80 -> CardTier.platinum', () {
        expect(tierForOverall(80), equals(CardTier.platinum));
      });

      test('case 4: overall 84 -> CardTier.platinum', () {
        expect(tierForOverall(84), equals(CardTier.platinum));
      });

      test('case 5: overall 85 -> CardTier.legendary', () {
        expect(tierForOverall(85), equals(CardTier.legendary));
      });

      test('case 6: overall 99 -> CardTier.legendary', () {
        expect(tierForOverall(99), equals(CardTier.legendary));
      });
    });

    group('cardTierLabel', () {
      test('case 1: CardTier.gold -> Ouro', () {
        expect(cardTierLabel(CardTier.gold), equals('Ouro'));
      });

      test('case 2: CardTier.platinum -> Platina', () {
        expect(cardTierLabel(CardTier.platinum), equals('Platina'));
      });

      test('case 3: CardTier.legendary -> Lendária', () {
        expect(cardTierLabel(CardTier.legendary), equals('Lendária'));
      });
    });

    group('overallColor', () {
      test('case 1: overall < 80 -> AppColors.tierGold', () {
        expect(overallColor(70), equals(AppColors.tierGold));
        expect(overallColor(79.4), equals(AppColors.tierGold));
      });

      test('case 2: overall 80 to 84 -> AppColors.tierPlatinumBorder', () {
        expect(overallColor(80), equals(AppColors.tierPlatinumBorder));
        expect(overallColor(84), equals(AppColors.tierPlatinumBorder));
      });

      test('case 3: overall >= 85 -> AppColors.tierLegendaryFrom', () {
        expect(overallColor(85), equals(AppColors.tierLegendaryFrom));
        expect(overallColor(99), equals(AppColors.tierLegendaryFrom));
      });

      test('case 4: rounds floating num to tier boundary (79.6 rounds to 80 -> platinum)', () {
        expect(overallColor(79.6), equals(AppColors.tierPlatinumBorder));
      });

      test('case 5: rounds floating num to tier boundary (84.6 rounds to 85 -> legendary)', () {
        expect(overallColor(84.6), equals(AppColors.tierLegendaryFrom));
      });
    });

    group('shiftLightness', () {
      test('case 1: zero delta preserves color', () {
        const c = Color(0xFF102030);
        expect(shiftLightness(c, 0.0), equals(c));
      });

      test('case 2: positive delta increases lightness', () {
        const c = Color(0xFF404040);
        final shifted = shiftLightness(c, 0.2);
        final origL = HSLColor.fromColor(c).lightness;
        final newL = HSLColor.fromColor(shifted).lightness;
        expect(newL, closeTo(origL + 0.2, 1e-3));
      });

      test('case 3: negative delta decreases lightness', () {
        const c = Color(0xFF808080);
        final shifted = shiftLightness(c, -0.2);
        final origL = HSLColor.fromColor(c).lightness;
        final newL = HSLColor.fromColor(shifted).lightness;
        expect(newL, closeTo(origL - 0.2, 1e-3));
      });

      test('case 4: positive delta clamped at 1.0 (pure white)', () {
        const c = Color(0xFF404040);
        final shifted = shiftLightness(c, 1.5);
        expect(shifted, equals(const Color(0xFFFFFFFF)));
      });

      test('case 5: negative delta clamped at 0.0 (pure black)', () {
        const c = Color(0xFF404040);
        final shifted = shiftLightness(c, -1.5);
        expect(shifted, equals(const Color(0xFF000000)));
      });
    });

    group('cardPaletteFor', () {
      test('case 1: gold palette properties', () {
        final palette = cardPaletteFor(CardTier.gold);
        expect(palette.gradient.length, equals(3));
        expect(palette.text, equals(AppColors.tierGoldText));
        expect(palette.nameText, equals(AppColors.tierGoldText));
        expect(palette.border, isNull);
        expect(palette.innerLine, isNull);
        expect(palette.pattern, equals(AppColors.tierGold));
      });

      test('case 2: platinum palette properties', () {
        final palette = cardPaletteFor(CardTier.platinum);
        expect(palette.gradient.length, equals(3));
        expect(palette.text, equals(AppColors.tierPlatinumBorder));
        expect(palette.nameText, equals(AppColors.tierPlatinumText));
        expect(palette.border, equals(AppColors.tierPlatinumBorder));
        expect(palette.innerLine, isNull);
        expect(palette.pattern, equals(AppColors.tierPlatinumBorder));
      });

      test('case 3: legendary palette properties', () {
        final palette = cardPaletteFor(CardTier.legendary);
        expect(palette.gradient.length, equals(3));
        expect(palette.gradient[0], equals(AppColors.tierLegendaryFrom));
        expect(palette.gradient[2], equals(AppColors.tierLegendaryTo));
        expect(palette.text, equals(AppColors.tierLegendaryAccent));
        expect(palette.nameText, equals(AppColors.tierLegendaryText));
        expect(palette.border, isNull);
        expect(palette.innerLine, equals(AppColors.tierLegendaryLine));
        expect(palette.pattern, equals(AppColors.tierLegendaryTo));
      });
    });

    group('CommunityAttributes class', () {
      test('case 1: empty instance has no attributes and null average/communityRating', () {
        const attr = CommunityAttributes.empty;
        expect(attr.hasAllAttributes, isFalse);
        expect(attr.hasAnyAttribute, isFalse);
        expect(attr.average, isNull);
        expect(attr.communityRating, isNull);
        expect(attr.hasCommunityRating, isFalse);
      });

      test('case 2: partial attributes', () {
        const attr = CommunityAttributes(pac: 80, sho: 70);
        expect(attr.hasAllAttributes, isFalse);
        expect(attr.hasAnyAttribute, isTrue);
        expect(attr.valueOf('pac'), equals(80));
        expect(attr.valueOf('sho'), equals(70));
        expect(attr.valueOf('pas'), isNull);
        expect(attr.average, isNull);
        expect(attr.communityRating, isNull);
      });

      test('case 3: all 6 attributes computes arithmetic average', () {
        const attr = CommunityAttributes(
          pac: 90,
          sho: 80,
          pas: 70,
          dri: 85,
          def: 60,
          phy: 75,
        );
        expect(attr.hasAllAttributes, isTrue);
        expect(attr.hasAnyAttribute, isTrue);
        // (90 + 80 + 70 + 85 + 60 + 75) / 6 = 460 / 6 = 76.6666...
        expect(attr.average, closeTo(76.6666, 1e-4));
        expect(attr.communityRating, closeTo(76.6666, 1e-4));
        expect(attr.hasCommunityRating, isTrue);
      });

      test('case 4: ratingOverride takes precedence over average', () {
        const attr = CommunityAttributes(
          pac: 50,
          sho: 50,
          pas: 50,
          dri: 50,
          def: 50,
          phy: 50,
          ratingOverride: 88.5,
        );
        expect(attr.average, equals(50.0));
        expect(attr.communityRating, equals(88.5));
      });

      test('case 5: fromMap factory parsing with various types and nulls', () {
        final map = {
          'community_pac': '85',
          'community_sho': 80,
          'community_pas': null,
          'community_dri': 'invalid_num',
          'community_def': 75,
          'community_phy': 70,
          'community_rating_override': '89.5',
        };
        final attr = CommunityAttributes.fromMap(map);
        expect(attr.pac, equals(85));
        expect(attr.sho, equals(80));
        expect(attr.pas, isNull);
        expect(attr.dri, isNull);
        expect(attr.def, equals(75));
        expect(attr.phy, equals(70));
        expect(attr.ratingOverride, equals(89.5));
        expect(attr.communityRating, equals(89.5));
      });

      test('case 6: valueOf with invalid key returns null', () {
        const attr = CommunityAttributes(pac: 80);
        expect(attr.valueOf('unknown_key'), isNull);
      });
    });
  });
}
