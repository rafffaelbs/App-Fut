# ARCHITECTURE.md — App do Fut (um código, vários apps)

> Documento de referência para quem executa as tarefas (Antigravity / Claude Code).
> Base: `docs/INVENTARIO_SUPABASE.md`. Em caso de conflito entre este documento e o código, **pare e registre em `docs/DUVIDAS.md`** em vez de decidir sozinho.

## 1. Objetivo

Um único repositório gera:

| App | Dados | Login | Admin | Tema | Quem usa |
|---|---|---|---|---|---|
| **personal** | Supabase | sim | sim | Blue Lock | Enzo e o grupo dele |
| **public** | SQLite local (drift) | não | o dono do aparelho é admin | neutro | qualquer pessoa |
| **web_readonly** (depois) | Supabase (somente leitura) | a decidir | não | igual ao personal | quem usa iPhone |

O app public terá botões **Exportar banco (.db)** e **Importar banco (.db)** como backup. Quem quiser ficar online "se vira" usando as interfaces e o schema documentado.

## 2. Regras de ouro

1. **Fase 1 não muda comportamento.** O app personal deve continuar idêntico depois de cada tarefa.
2. **Isolamento do Supabase:** só `lib/data/supabase/` e `lib/bootstrap_personal.dart` podem importar `supabase_flutter`. Verificação (deve imprimir **nada**):
   ```
   grep -rl "supabase_flutter" lib | grep -v "^lib/data/supabase/" | grep -v "^lib/bootstrap_personal.dart"
   ```
3. Telas, widgets, serviços e utils dependem de **interfaces** (`lib/domain/`) e de `AppServices` / `AppFeatures`. Nunca de classes `Supabase*`.
4. `lib/utils/*_calculator.dart` não dependem de plataforma nem de banco. **Não alterar as fórmulas.**
5. **Não alterar:** nomes de tabelas/colunas do Supabase, policies RLS, RPCs, fórmulas dos calculators.
6. Uma tarefa = uma branch = commits pequenos. Antes de terminar: `flutter analyze` e `flutter test`.
7. **Não adicionar pacotes** sem estar listado na tarefa. Pacotes previstos mais à frente: `drift`, `drift_flutter` (ou `sqlite3_flutter_libs`), `path`.
8. Exceções e mensagens de erro existentes (ex.: "sem permissão") devem ser **preservadas com o mesmo texto**.
9. Dúvida ou achado fora do escopo → `docs/DUVIDAS.md` (arquivo, linha, o que viu). Não resolver por conta própria.

## 3. Estrutura alvo de pastas

```
lib/
  domain/
    repositories/      # interfaces (classes abstratas) — Fase 1 / T1
    services/          # AuthService, PermissionService, BackupService
  data/
    supabase/          # implementações Supabase* (e supabase_config.dart)
    local/             # drift/SQLite (Fase 3)
  app/
    app_services.dart  # guarda as implementações ativas (substitui SupabaseService.instance)
    app_features.dart  # flags por flavor
  bootstrap_personal.dart
  bootstrap_public.dart      # Fase 3
  main_personal.dart
  main_public.dart           # Fase 3
  (config, constants, models, screens, utils, widgets: como estão)
tool/legacy/           # scripts de migração antigos (fora dos apps)
docs/
```

`lib/main.dart` continua existindo até a Fase 1 acabar, apenas chamando `main_personal.dart`, para não quebrar comandos atuais.

## 4. Mapa de interfaces (origem → destino)

### 4.1 Núcleo (existe nos dois apps)

| Interface | Origem | Observação |
|---|---|---|
| `GroupsRepository` | `groups_repository.dart` | `getMyGroups`, `createGroup`, `updateGroup`, `deleteGroup`. No public: um grupo único criado no primeiro uso. |
| `SeasonsRepository` | `seasons_repository.dart` | Todos os 5 métodos, assinaturas iguais. |
| `SessionsRepository` | `sessions_repository.dart` | Todos os 9 métodos **+ novo** `getRuntimeState(String sessionId)` (ver 4.4). |
| `MatchesRepository` | `matches_repository.dart` | Todos os 7 métodos. `savePendingMatch` fica (fila offline do personal); no public pode gravar direto. |
| `RatingsRepository` | `ratings_repository.dart` | Todos os 4 métodos. |
| `SessionArrivalsRepository` | `session_arrivals_repository.dart` | Todos os 4 métodos. |
| `PlayersRepository` | `players_repository.dart` | **Só estes:** `getPlayersByGroup`, `createGhostPlayer`, `updatePlayer`, `setPlayerIcon`, `removePlayerFromGroup`, `getPlayerById`, `setNameEffect`, `setMonthlyHighlight`, `setCosmetics`, `setCommunityAttributes`, `setAdvancedStat`. |

### 4.2 Específicas de online / multiusuário

| Interface | Métodos | Por quê é separada |
|---|---|---|
| `PlayerAccountRepository` | `createPlayerWithUser`, `linkEmailToPlayer`, `claimGhostProfiles` (RPC), `getMyPlayers` | Dependem de usuário logado (`auth.uid`). |
| `MembershipRepository` | `getMembers`, `getMyMembership`, `promoteToAdmin`, `demoteToMember`, `addMember`, `removeMember`, `findGroupByCode` (RPC), `requestToJoin`, `listPendingRequests`, `approveRequest` (RPC), `rejectRequest` (RPC) | Convites, pedidos de entrada e papéis só fazem sentido com vários usuários. **`isCurrentUserAdmin` sai daqui** (vai para `PermissionService`). |
| `GoalSoundRepository` | `setGoalSound`, `uploadGoalSound`, `clearGoalSound` | Usa Storage (`goal-sounds`). Flag `hasGoalSounds`. |
| `ActionLogsRepository` | `log`, `getRecentLogs`, `exportAndCleanOldLogs` (RPC) | Auditoria de admin. No public: implementação que não faz nada. |

### 4.3 Serviços novos (transversais)

```dart
abstract class AuthService {
  String? get currentUserId;
  bool get isSignedIn;
  Stream<bool> get signedInChanges;      // substitui auth.onAuthStateChange no AuthGate
  Future<void> signIn(String email, String password);
  Future<void> signUp(String email, String password);
  Future<void> signOut();
}
// Erros viram AppAuthException(message) — telas não conhecem AuthException do Supabase.

abstract class PermissionService {
  Future<bool> isAdmin(String groupId);      // mesma regra de hoje: creator_id OU role == 'admin'
  Future<void> requireAdmin(String groupId); // lança a MESMA exceção/mensagem de hoje
}
```

- Os repositórios Supabase recebem `PermissionService` no construtor e deixam de chamar `_membersRepo.isCurrentUserAdmin`.
- No app public: `AuthService` sempre logado com id fixo local; `PermissionService.isAdmin` sempre `true`.

`BackupService` (`sync_service`, `cache_sync_manager`): só personal; ver T3c.

### 4.4 Consulta solta a corrigir

`lib/screens/match_screen.dart:410-415` consulta `sessions` direto. Vira `SessionsRepository.getRuntimeState(sessionId)` retornando `Map<String, dynamic>?` com as colunas `seconds_played, is_running, score_red, score_white, red_streak, white_streak, is_overtime, started_at`. Mesmo resultado de hoje.

## 5. Feature flags (`AppFeatures`)

| Flag | personal | public | web_readonly |
|---|---|---|---|
| `hasAuth` (login) | true | false | decidir |
| `hasMembershipManagement` (convites, pedidos, papéis) | true | false | false |
| `hasCosmetics` (efeitos de nome, Bola de Ouro, Craque do Mês) | true | false (ou simplificado) | true |
| `hasGoalSounds` | true | false | false |
| `hasAuditLog` | true | false | false |
| `hasCloudBackup` (sync_data) | true | false | false |
| `hasDbExportImport` | false | true | false |
| `isReadOnly` | false | false | true |

Regra: tela de admin/engrenagem/edição aparece se `AppFeatures` permitir **e** `PermissionService.isAdmin` for true (e `isReadOnly` for false).

## 6. Dados locais e transações (Fase 3 — responsabilidade do Claude)

- Schema drift espelha os nomes do Supabase (inglês). IDs `TEXT` (uuid). Sem tipos específicos de Postgres. `PRAGMA foreign_keys = ON`. `schemaVersion` do drift = `user_version`.
- **Devem rodar em uma transação SQLite:** `createGroup`, `saveFullMatch`, `updateFullMatch`, `updatePartialMatch`, `deleteMatch`, `savePendingMatch`, `createGhostPlayer`, `replaceArrivals`.
- No Supabase essas operações hoje são sequenciais sem transação (risco de registros órfãos se falhar no meio). **Fora do escopo agora**; candidato futuro: mover para função Postgres (RPC).
- `_syncToCloud` (`match_screen.dart:281-329`) grava `session_arrivals` e `sessions` a cada mudança; no local fica barato, mas manter a mesma chamada.
- Export: `VACUUM INTO`. Import: validar (`integrity_check`, `user_version`), backup do banco atual, trocar o arquivo, reabrir.

## 7. Web somente leitura (Fase 2)

Problemas no código atual (só afetam o build web; no celular funcionam):

- `dart:io`/`File`/`path_provider` em `ranking_screen.dart`, `history_screen.dart`, `group_ranking_screen.dart` (screenshot/compartilhar) → usar import condicional ou `kIsWeb` e esconder/adaptar.
- `sync_service.dart`, `data_migration_service.dart`, `fix_event_times_service.dart` usam `dart:io` → **não podem ser importados** pelo entrypoint web.
- `file_picker` (usa `path`), `share_plus` e `audioplayers` têm limitações na web.

Modelo de acesso (login por e-mail ou link público) **ainda em decisão**; a segurança real é por RLS de `SELECT`, não por esconder botão.

## 8. Checklist manual de regressão (rodar no celular após cada merge na main)

1. Abrir o app e entrar (login).
2. Abrir o grupo e ver ranking e ranking expandido.
3. Criar uma pelada, adicionar presentes.
4. Jogar uma partida: gol, cronômetro, finalizar. Conferir que salvou.
5. Ver histórico e estatísticas da temporada.
6. Abrir um jogador: carta e comparação.
7. Com usuário **não admin**: engrenagem não aparece em Peladas/Elenco/Estatísticas.
8. Com admin: gerenciar membros e temporadas abre normalmente.
