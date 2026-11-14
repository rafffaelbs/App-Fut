import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_do_fut/app/app_features.dart';
import 'package:app_do_fut/app/app_services.dart';
import 'package:app_do_fut/models/player_model.dart';
import 'package:app_do_fut/services/group_bootstrap.dart';

import '../helpers/test_app_services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GroupBootstrap.instance.clearMemorySnapshots();
  });

  test('prefetch em readonly NÃO grava no SharedPreferences e mantém dados em memória', () async {
    const groupId = 'test-grp-readonly';
    const dummyPlayer = PlayerModel(
      id: 'p-1',
      name: 'Neymar',
      rating: 8.5,
    );

    setupTestAppServices(
      features: const AppFeatures.webReadonly(),
      players: StubPlayersRepository(players: const [dummyPlayer]),
    );

    expect(AppServices.instance.features.isReadOnly, isTrue);

    final ok = await GroupBootstrap.instance.prefetch(groupId, force: true);
    expect(ok, isTrue);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('players_$groupId'), isFalse);
    expect(prefs.containsKey('ratings_snapshot_at_$groupId'), isFalse);

    // Os dados existem em memória
    final mem = GroupBootstrap.instance.getMemorySnapshot(groupId);
    expect(mem, isNotNull);
    expect(mem!.length, 1);
    expect(mem.first['name'], 'Neymar');
    expect(mem.first['rating'], 8.5);

    // hasLocalSnapshot retorna true consultando a memória
    final hasSnap = await GroupBootstrap.hasLocalSnapshot(groupId);
    expect(hasSnap, isTrue);
  });
}
