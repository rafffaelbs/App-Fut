import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AvatarRatingStyle {
  off, // Desligado: fundo escuro padrão, sem destaque de rating
  halo, // Auréola: borda brilhante externa com a cor do rating
  background, // Fundo: círculo preenchido com a cor/gradiente do rating
}

enum AvatarContext {
  ranking,
  dashboard,
  stats,
  match,
}

class AvatarStyleManager {
  AvatarStyleManager._();
  static final AvatarStyleManager instance = AvatarStyleManager._();

  final ValueNotifier<int> changeNotifier = ValueNotifier<int>(0);

  AvatarRatingStyle _ranking = AvatarRatingStyle.background;
  AvatarRatingStyle _dashboard = AvatarRatingStyle.background;
  AvatarRatingStyle _stats = AvatarRatingStyle.background;
  AvatarRatingStyle _match = AvatarRatingStyle.halo;

  bool _loaded = false;

  AvatarRatingStyle getStyle(AvatarContext context) {
    if (!_loaded) {
      // Carrega em segundo plano na primeira chamada
      load();
    }
    switch (context) {
      case AvatarContext.ranking:
        return _ranking;
      case AvatarContext.dashboard:
        return _dashboard;
      case AvatarContext.stats:
        return _stats;
      case AvatarContext.match:
        return _match;
    }
  }

  AvatarRatingStyle get rankingStyle => getStyle(AvatarContext.ranking);
  AvatarRatingStyle get dashboardStyle => getStyle(AvatarContext.dashboard);
  AvatarRatingStyle get statsStyle => getStyle(AvatarContext.stats);
  AvatarRatingStyle get matchStyle => getStyle(AvatarContext.match);

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _ranking = _parse(
        prefs.getString('avatar_style_ranking'),
        fallback: AvatarRatingStyle.background,
      );
      _dashboard = _parse(
        prefs.getString('avatar_style_dashboard'),
        fallback: AvatarRatingStyle.background,
      );
      _stats = _parse(
        prefs.getString('avatar_style_stats'),
        fallback: AvatarRatingStyle.background,
      );
      _match = _parse(
        prefs.getString('avatar_style_match'),
        fallback: AvatarRatingStyle.halo,
      );
      _loaded = true;
      changeNotifier.value++;
    } catch (_) {
      _loaded = true;
    }
  }

  Future<void> setStyle(AvatarContext context, AvatarRatingStyle style) async {
    switch (context) {
      case AvatarContext.ranking:
        _ranking = style;
        break;
      case AvatarContext.dashboard:
        _dashboard = style;
        break;
      case AvatarContext.stats:
        _stats = style;
        break;
      case AvatarContext.match:
        _match = style;
        break;
    }
    changeNotifier.value++;

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _keyFor(context);
      await prefs.setString(key, style.name);
    } catch (_) {}
  }

  Future<void> applyPreset({
    required AvatarRatingStyle ranking,
    required AvatarRatingStyle dashboard,
    required AvatarRatingStyle stats,
    required AvatarRatingStyle match,
  }) async {
    _ranking = ranking;
    _dashboard = dashboard;
    _stats = stats;
    _match = match;
    changeNotifier.value++;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('avatar_style_ranking', ranking.name);
      await prefs.setString('avatar_style_dashboard', dashboard.name);
      await prefs.setString('avatar_style_stats', stats.name);
      await prefs.setString('avatar_style_match', match.name);
    } catch (_) {}
  }

  String _keyFor(AvatarContext context) {
    switch (context) {
      case AvatarContext.ranking:
        return 'avatar_style_ranking';
      case AvatarContext.dashboard:
        return 'avatar_style_dashboard';
      case AvatarContext.stats:
        return 'avatar_style_stats';
      case AvatarContext.match:
        return 'avatar_style_match';
    }
  }

  AvatarRatingStyle _parse(String? val, {required AvatarRatingStyle fallback}) {
    if (val == null) return fallback;
    for (final s in AvatarRatingStyle.values) {
      if (s.name == val) return s;
    }
    return fallback;
  }

  @visibleForTesting
  void resetForTest() {
    _ranking = AvatarRatingStyle.background;
    _dashboard = AvatarRatingStyle.background;
    _stats = AvatarRatingStyle.background;
    _match = AvatarRatingStyle.halo;
    _loaded = false;
    changeNotifier.value = 0;
  }
}
