import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_do_fut/domain/repositories/groups_repository.dart';
import 'package:app_do_fut/main_personal.dart';
import 'package:app_do_fut/models/group_model.dart';
import '../helpers/test_app_services.dart';

class FakeGroupsRepo implements GroupsRepository {
  List<GroupModel> groupsToReturn = [];
  bool shouldThrow = false;
  bool isFromCache = false;

  @override
  bool get lastLoadFromCache => isFromCache;

  @override
  Future<List<GroupModel>> getMyGroups() async {
    if (shouldThrow) {
      throw Exception('Sem rede e sem cache');
    }
    return groupsToReturn;
  }

  @override
  Future<GroupModel> createGroup({required String name, String? adminPlayerName}) async =>
      throw UnimplementedError();

  @override
  Future<GroupModel> updateGroup(GroupModel group) async => group;

  @override
  Future<void> deleteGroup(String groupId) async {}
}

void main() {
  late FakeGroupsRepo fakeGroups;

  setUp(() {
    fakeGroups = FakeGroupsRepo();
    setupTestAppServices(
      groups: fakeGroups,
    );
  });

  group('HomePage sinalização de cache e conectividade', () {
    testWidgets('mostra "Sem conexão. Mostrando dados salvos." quando dados vêm do cache', (tester) async {
      fakeGroups.isFromCache = true;
      fakeGroups.groupsToReturn = [
        const GroupModel(id: 'g1', name: 'Pelada de Quarta'),
      ];

      await tester.pumpWidget(
        const MaterialApp(home: HomePage()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pelada de Quarta'), findsOneWidget);
      expect(find.text('Sem conexão. Mostrando dados salvos.'), findsOneWidget);
    });

    testWidgets('mostra "Nenhum grupo ainda." com "Sem conexão." quando sem rede e sem cache', (tester) async {
      fakeGroups.shouldThrow = true;
      fakeGroups.isFromCache = false;

      await tester.pumpWidget(
        const MaterialApp(home: HomePage()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nenhum grupo ainda.'), findsOneWidget);
      expect(find.text('Sem conexão.'), findsOneWidget);
      expect(find.text('Sem conexão. Mostrando dados salvos.'), findsNothing);
    });

    testWidgets('mostra "Nenhum grupo ainda." sem aviso de conexão quando busca online com sucesso sem grupos', (tester) async {
      fakeGroups.shouldThrow = false;
      fakeGroups.isFromCache = false;
      fakeGroups.groupsToReturn = [];

      await tester.pumpWidget(
        const MaterialApp(home: HomePage()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nenhum grupo ainda.'), findsOneWidget);
      expect(find.text('Sem conexão.'), findsNothing);
      expect(find.text('Sem conexão. Mostrando dados salvos.'), findsNothing);
    });

    testWidgets('mostra lista de grupos normalmente sem aviso quando busca online com sucesso com grupos', (tester) async {
      fakeGroups.shouldThrow = false;
      fakeGroups.isFromCache = false;
      fakeGroups.groupsToReturn = [
        const GroupModel(id: 'g2', name: 'Pelada de Sábado'),
      ];

      await tester.pumpWidget(
        const MaterialApp(home: HomePage()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pelada de Sábado'), findsOneWidget);
      expect(find.text('Sem conexão.'), findsNothing);
      expect(find.text('Sem conexão. Mostrando dados salvos.'), findsNothing);
    });
  });
}
