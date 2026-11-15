import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_do_fut/services/avatar_style_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AvatarStyleManager.instance.load();
  });

  test('valores padrão correspondem à solicitação (fundo no ranking/dash/stats, auréola na partida)', () {
    final manager = AvatarStyleManager.instance;
    expect(manager.getStyle(AvatarContext.ranking), AvatarRatingStyle.background);
    expect(manager.getStyle(AvatarContext.dashboard), AvatarRatingStyle.background);
    expect(manager.getStyle(AvatarContext.stats), AvatarRatingStyle.background);
    expect(manager.getStyle(AvatarContext.match), AvatarRatingStyle.halo);
  });

  test('setStyle atualiza estilo e notifica listeners', () async {
    final manager = AvatarStyleManager.instance;
    int notifyCount = 0;
    manager.changeNotifier.addListener(() {
      notifyCount++;
    });

    await manager.setStyle(AvatarContext.ranking, AvatarRatingStyle.off);
    expect(manager.getStyle(AvatarContext.ranking), AvatarRatingStyle.off);
    expect(notifyCount, 1);

    await manager.setStyle(AvatarContext.match, AvatarRatingStyle.background);
    expect(manager.getStyle(AvatarContext.match), AvatarRatingStyle.background);
    expect(notifyCount, 2);
  });

  test('applyPreset configura múltiplos contextos simultaneamente', () async {
    final manager = AvatarStyleManager.instance;

    await manager.applyPreset(
      ranking: AvatarRatingStyle.halo,
      dashboard: AvatarRatingStyle.halo,
      stats: AvatarRatingStyle.halo,
      match: AvatarRatingStyle.halo,
    );
    expect(manager.getStyle(AvatarContext.ranking), AvatarRatingStyle.halo);
    expect(manager.getStyle(AvatarContext.dashboard), AvatarRatingStyle.halo);
    expect(manager.getStyle(AvatarContext.stats), AvatarRatingStyle.halo);
    expect(manager.getStyle(AvatarContext.match), AvatarRatingStyle.halo);

    await manager.applyPreset(
      ranking: AvatarRatingStyle.off,
      dashboard: AvatarRatingStyle.off,
      stats: AvatarRatingStyle.off,
      match: AvatarRatingStyle.off,
    );
    expect(manager.getStyle(AvatarContext.ranking), AvatarRatingStyle.off);
    expect(manager.getStyle(AvatarContext.dashboard), AvatarRatingStyle.off);
    expect(manager.getStyle(AvatarContext.stats), AvatarRatingStyle.off);
    expect(manager.getStyle(AvatarContext.match), AvatarRatingStyle.off);

    await manager.applyPreset(
      ranking: AvatarRatingStyle.background,
      dashboard: AvatarRatingStyle.background,
      stats: AvatarRatingStyle.background,
      match: AvatarRatingStyle.halo,
    );
    expect(manager.getStyle(AvatarContext.ranking), AvatarRatingStyle.background);
    expect(manager.getStyle(AvatarContext.dashboard), AvatarRatingStyle.background);
    expect(manager.getStyle(AvatarContext.stats), AvatarRatingStyle.background);
    expect(manager.getStyle(AvatarContext.match), AvatarRatingStyle.halo);
  });

  test('persiste em SharedPreferences e recarrega corretamente', () async {
    final manager = AvatarStyleManager.instance;
    await manager.setStyle(AvatarContext.ranking, AvatarRatingStyle.off);
    await manager.setStyle(AvatarContext.dashboard, AvatarRatingStyle.halo);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('avatar_style_ranking'), 'off');
    expect(prefs.getString('avatar_style_dashboard'), 'halo');

    // Recarrega
    await manager.load();
    expect(manager.getStyle(AvatarContext.ranking), AvatarRatingStyle.off);
    expect(manager.getStyle(AvatarContext.dashboard), AvatarRatingStyle.halo);
  });
}
