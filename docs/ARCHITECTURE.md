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
4. `lib/utils/*_calculator.dart` não dependem de plataforma nem de banco. **Não alterar as fórmulas.** **Exceção conhecida:** `stats_calculator.dart` (~linhas 100-124) e `site_data_generator.dart` leem `SharedPreferences` direto (`match_history_*`, `sessions_*`, `seasons_*`). Não mexer agora; tratar na T3e.
5. **Não alterar:** nomes de tabelas/colunas do Supabase, policies RLS, RPCs, fórmulas dos calculators.
6. Uma tarefa = uma branch = commits pequenos. Antes de terminar: `flutter analyze` e `flutter test`.
7. **Não adicionar pacotes** sem estar listado na tarefa. Pacotes previstos mais à frente: `drift`, `drift_flutter` (ou `sqlite3_flutter_libs`), `path`.
8. Exceções e mensagens de erro existentes (ex.: "sem permissão") devem ser **preservadas com o mesmo texto**.
9. Dúvida ou achado fora do escopo → `docs/DUVIDAS.md` (arquivo, linha, o que viu). Não resolver por conta própria.
10. **Não renomear nem alterar chaves de `SharedPreferences`** (lista na seção 9). Uma chave alterada faz o app perder partidas pendentes ou o estado da partida em andamento de quem já tem o app instalado.
11. **Não mexer na lógica de proteção contra queda de internet** (fila de envio, cache, estado local da partida; seção 9). Só é permitido movê-la de pasta/abstraí-la como descrito nas tarefas, preservando o comportamento.

## 3. Estrutura alvo de pastas

```
lib/
  domain/
    repositories/      # interfaces (classes abstratas) — Fase 1 / T1
    services/          # AuthService, PermissionService, MatchOutbox, SiteSyncService, DiagnosticsService
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
| `SessionsRepository` | `sessions_repository.dart` | 7 métodos (`getCachedSession`, `getSessionById`, `getSessionsByGroup`, `createSession`, `updateSession`, `updateRuntimeState`, `deleteSession`) **+ novo** `getRuntimeState(String sessionId)` (ver 4.4). Fora: `getSessionsBySeason`, `finalizeSession` (0 chamadores). |
| `MatchesRepository` | `matches_repository.dart` | **Só estes (5):** `getMatchesBySession`, `getMatchesByGroup`, `savePendingMatch`, `updatePartialMatch`, `deleteMatch`. Fora: `saveFullMatch` e `updateFullMatch` (0 chamadores). `savePendingMatch` fica (fila offline do personal); no public pode gravar direto. |
| `RatingsRepository` | `ratings_repository.dart` | **Não terá interface:** os 4 métodos (`getPlayerHistoryBySeason`, `getFullPlayerHistory`, `getLatestRatingsBySeason`, `recordRatingsBatch`) têm 0 chamadores. **Hoje nada lê nem grava `rating_history`**: as notas são calculadas em memória a partir de partidas e eventos. |
| `CustomBadgesRepository` (novo) | `manage_badges_screen`, `player_detail` | `getCustomBadges(groupId)` e `saveCustomBadges(groupId, badges)`. Hoje vive só em `SharedPreferences` (`custom_badges_<grupo>`); não existe no Supabase. Personal: SharedPreferences (igual hoje). Public: tabela no SQLite. |
| `MatchHistoryStore` (novo) | `match_screen`, ranking, `stats_calculator` | `readSession(sessionId)` e `appendToSession(sessionId, record)`. Hoje é `match_history_<sessão>` em `SharedPreferences`. Personal: igual hoje. Public: derivado das tabelas do SQLite. Quem usa é decidido na T3e. |
| `SessionArrivalsRepository` | `session_arrivals_repository.dart` | `getArrivals`, `getPlayerIdsBySessions`, `replaceArrivals`. Fora: `clearArrivals` (0 chamadores). |
| `PlayersRepository` | `players_repository.dart` | **Só estes (11):** `getPlayersByGroup`, `createGhostPlayer`, `updatePlayer`, `setPlayerIcon`, `setGoalSound`, `removePlayerFromGroup`, `getPlayerById`, `setNameEffect`, `setMonthlyHighlight`, `setCommunityAttributes`, `setAdvancedStat`. Fora: `setCosmetics` (0 chamadores). |

### 4.2 Específicas de online / multiusuário

| Interface | Métodos | Por quê é separada |
|---|---|---|
| `PlayerAccountRepository` | `claimGhostProfiles` (RPC), `getMyPlayers` | Dependem de usuário logado (`auth.uid`). Fora: `createPlayerWithUser`, `linkEmailToPlayer` (0 chamadores). |
| `MembershipRepository` | `getMembers`, `getMyMembership`, `promoteToAdmin`, `demoteToMember`, `findGroupByCode` (RPC), `requestToJoin`, `listPendingRequests`, `approveRequest` (RPC), `rejectRequest` (RPC) | Convites, pedidos de entrada e papéis só fazem sentido com vários usuários. **`isCurrentUserAdmin` sai daqui** (vai para `PermissionService`). Fora: `addMember`, `removeMember` (0 chamadores). |
| ~~`GoalSoundRepository`~~ | — | **Não existe.** `setGoalSound` ficou em `PlayersRepository`; `uploadGoalSound` e `clearGoalSound` têm 0 chamadores (o bucket `goal-sounds` não é usado). Flag `hasGoalSounds` continua valendo. |
| `ActionLogsRepository` | `log` (somente) | Auditoria de admin (gravação). `getRecentLogs` e `exportAndCleanOldLogs` têm 0 chamadores. No public: implementação que não faz nada. |

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

### 4.3b Serviços da camada de rede (descobertos no `INVENTARIO_OFFLINE.md`)

```dart
abstract class MatchOutbox {            // fila de envio de partidas (hoje: PendingMatchQueue)
  ValueListenable<int> get pending;
  ValueListenable<String?> get lastError;
  Future<void> enqueue(Map<String, dynamic> job);
  Future<void> flush();
}
abstract class SiteSyncService {        // hoje: sync_service (o que sobra após a T0c)
  Future<String> getOrCreateSyncCode();
  Future<void> exportDataToSupabase(String syncCode);
}
abstract class DiagnosticsService {     // hoje: cache_sync_manager (painel de debug do admin)
  // mesmos métodos públicos de CacheSyncManager + a classe CacheSyncStatus
}
```

- `MatchOutbox` — personal: `SupabaseMatchOutbox` (a atual `PendingMatchQueue`, comportamento idêntico). Public: `LocalMatchOutbox`, que grava direto no SQLite; `pending` fica sempre 0 e `flush` não faz nada.
- `SiteSyncService` e `DiagnosticsService` — só personal; no public ficam `null` em `AppServices`.
- `CacheStore` (cache de leitura usado só pelos repositórios Supabase) vai junto com eles para `lib/data/supabase/`.
- `GroupBootstrap` (snapshot local do elenco) fica em `lib/services/`; só depende de repositórios via `AppServices`.

### 4.4 Consulta solta a corrigir

`lib/screens/match_screen.dart:410-415` consulta `sessions` direto. Vira `SessionsRepository.getRuntimeState(sessionId)` retornando `Map<String, dynamic>?` com as colunas `seconds_played, is_running, score_red, score_white, red_streak, white_streak, is_overtime, started_at`. Mesmo resultado de hoje.

### 4.5 Métodos sem chamadores e telas inalcançáveis (de `docs/CODIGO_MORTO.md`)

- **Métodos com 0 chamadores** (não entram em nenhuma interface e não serão implementados no SQLite; **permanecem** nas classes Supabase por enquanto, não apagar nesta fase): `ActionLogsRepository.getRecentLogs/exportAndCleanOldLogs`; `GroupMembersRepository.addMember/removeMember`; `MatchesRepository.saveFullMatch/updateFullMatch`; `PlayersRepository.createPlayerWithUser/linkEmailToPlayer/uploadGoalSound/clearGoalSound/setCosmetics`; `RatingsRepository` (os 4 métodos); `SessionArrivalsRepository.clearArrivals`; `SessionsRepository.getSessionsBySeason/finalizeSession`.
- **Telas inalcançáveis** (nenhuma rota ou botão as abre): `expanded_ranking_screen`, `group_ranking_screen`, `tournament_screen`, `blank_screen`. Removidas na T0g (se o Enzo confirmar).
- Se algum desses itens for planejado (ex.: tela de logs do admin, login por e-mail, gráfico de evolução usando `rating_history`), reavaliar antes de apagar o código.

## 5. Feature flags (`AppFeatures`)

| Flag | personal | public | web_readonly |
|---|---|---|---|
| `hasAuth` (login) | true | false | decidir |
| `hasMembershipManagement` (convites, pedidos, papéis) | true | false | false |
| `hasCosmetics` (efeitos de nome, Bola de Ouro, Craque do Mês) | true | false (ou simplificado) | true |
| `hasGoalSounds` | true | false | false |
| `hasAuditLog` | true | false | false |
| `hasSiteSync` (envio do "pacote do site" para `sync_data` a cada ~90 s) | true | false | false |
| `hasCloudDraftSync` (rascunho da partida no Supabase: `replaceArrivals`/`updateRuntimeState`, restauração remota no `_loadMatchState`) | true | false | false |
| `hasAdminDebug` (painel de debug, teste de conexão) | true | false | false |
| `hasDbExportImport` | false | true | false |
| `isReadOnly` | false | false | true |

Regra: tela de admin/engrenagem/edição aparece se `AppFeatures` permitir **e** `PermissionService.isAdmin` for true (e `isReadOnly` for false).

## 6. Dados locais e transações (Fase 3 — responsabilidade do Claude)

- Schema drift espelha os nomes do Supabase (inglês). IDs `TEXT` (uuid). Sem tipos específicos de Postgres. `PRAGMA foreign_keys = ON`. `schemaVersion` do drift = `user_version`.
- **Devem rodar em uma transação SQLite:** `createGroup`, `saveFullMatch`, `updateFullMatch`, `updatePartialMatch`, `deleteMatch`, `savePendingMatch`, `createGhostPlayer`, `replaceArrivals`.
- No Supabase essas operações hoje são sequenciais sem transação (risco de registros órfãos se falhar no meio). **Fora do escopo agora**; candidato futuro: mover para função Postgres (RPC).
- O rascunho em nuvem da partida (`_syncToCloud`/`_scheduleCloudSync`, `match_screen.dart` ~268-329) grava `session_arrivals` e `sessions` a cada mudança. No public fica desligado pela flag `hasCloudDraftSync` (o estado em andamento já está em `SharedPreferences`).
- No public, finalizar partida passa por `LocalMatchOutbox` (grava direto no SQLite, na mesma transação do resto). A lista de tabelas é a mesma de `savePendingMatch`: `matches`, `match_lineups`, `match_events`. **Resolvido (T0d):** `rating_history` não é gravado em lugar nenhum no fluxo atual; no SQLite v1 a tabela não é criada (só se o T0e achar um leitor ativo).
- `SharedPreferences` guarda hoje dados que podem ser de domínio (ex.: `match_history_<id>`, `players_<groupId>`). No public, o `.db` exportado precisa conter tudo que importa; o que for "só local em SharedPreferences" precisa ser migrado ou descartado de forma consciente. Decisões na seção 10.
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
9. **Modo avião:** finalizar uma partida, ver o selo de pendente e o banner vermelho; desligar o modo avião, tocar "Reenviar agora" e conferir que a partida aparece no Supabase. (Obrigatório depois de qualquer tarefa que toque fila, cache ou `match_screen`.)

## 9. Proteção contra queda de internet — como funciona hoje (NÃO MEXER)

Fonte: `docs/INVENTARIO_OFFLINE.md`. São 4 camadas independentes; **nenhuma é o `sync_service`**:

1. **Estado da partida em andamento** — `match_screen._saveMatchState()` grava a cada ação no `SharedPreferences` (placar, eventos, times, cronômetro, goleiros...). Se o app fecha, `_loadMatchState()` restaura e recalcula o cronômetro pela hora de início.
2. **Fila de envio (outbox)** — `PendingMatchQueue`: ao finalizar, a partida é gravada em `pending_matches_v1` e enviada em segundo plano, com reenvio automático (5s, 10s, 20s, 40s, 60s), ao abrir a tela, ao iniciar partida, ao voltar do background e pelo botão "Reenviar agora". Telas de histórico/ranking mesclam as pendentes via `_pendingMatches()`.
3. **Cache de leitura** — `CacheStore` (chaves `cache:*`) usado pelos repositórios de partidas, sessões e jogadores como fallback quando a rede falha.
4. **Snapshot do elenco** — `GroupBootstrap` (`players_<groupId>`, `ratings_snapshot_at_<groupId>`) permite sorteio/draft sem rede.

Chaves de `SharedPreferences` que NÃO podem mudar: `pending_matches_v1`, `cache:*`, `my_sync_code`, `cache_has_pending_cloud_sync`, `cache_last_cloud_sync_at`, `cache_last_cloud_fetch_at`, `present_players_*`, `team_red_*`, `team_white_*`, `score_red_*`, `score_white_*`, `match_events_*`, `is_overtime_*`, `seconds_played_*`, `is_running_*`, `start_timestamp_*`, `red_streak_*`, `white_streak_*`, `active_gk_*`, `first_gk_*`, `match_history_*`, `players_*`, `ratings_snapshot_at_*`.

O que `sync_service` e `cache_sync_manager` realmente fazem: `sync_service` envia o "pacote do site" (JSON do `SiteDataGenerator`) para `sync_data` a cada ~90 s e ao fechar a tela de partida (alimenta o site antigo); `cache_sync_manager` é diagnóstico do painel de debug do admin (ping e dump do storage). Nenhum dos dois dispara reenvio da fila.

## 10. Dados que hoje vivem só no SharedPreferences (de `INVENTARIO_SHAREDPREFS.md`)

| Dado | Chave | Situação hoje | Decisão |
|---|---|---|---|
| Súmula local das partidas | `match_history_<sessão>` | Única fonte do ranking do grupo (`GroupRankingScreen`); fallback de `RankingScreen` e `MatchScreen`; lida também por `stats_calculator`. Escrita por `match_screen` ao finalizar. | Interface `MatchHistoryStore` (T3e). Personal: SharedPreferences, igual hoje. Public: derivada das tabelas do SQLite (somente leitura; `appendToSession` não faz nada). Se o T0e confirmar que `GroupRankingScreen` é inalcançável, ela é removida em vez de adaptada. |
| Insígnias personalizadas | `custom_badges_<grupo>` | Não existe no Supabase; cada aparelho tem as suas. | `CustomBadgesRepository`. Personal: igual hoje. Public: tabela `custom_badges` no SQLite (entra no `.db`). Web: vazio por enquanto. |
| Elenco com campos calculados | `players_<grupo>` | Cache do Supabase, recriado pelo `GroupBootstrap`. | Continua como cache nos dois apps. Depois de importar um `.db`, apagar esses snapshots e `cache:*` (T11). |
| Cache de leitura | `cache:*` | Só repositórios Supabase. | Fica em `lib/data/supabase/`; não existe no public. |
| Estado da partida em andamento | `present_players_*`, `team_*`, `score_*`, `is_running_*`... | Temporário. | Continua em SharedPreferences nos dois apps; **não** vai para o `.db`. Avisar na tela que exportar/importar deve ser feito entre partidas. |
| Preferências de tela | `show_radar_chart`, `pitch_use_cards`, `require_gk`... | Config do aparelho. | Continuam locais; não fazem parte do backup. |
| Legado sem escritor | `sessions_*`, `seasons_*`, `app_groups`, `players_grupo_` | Lidos por `GroupRankingScreen`, `stats_calculator` e `site_data_generator`; praticamente ninguém grava. | Se o T0e confirmar tela inalcançável, remover junto com ela. |
| Envio do site e diagnóstico | `sync_history`, `my_sync_code`, `cache_*_cloud_*` | Só do envio do pacote do site e do painel de debug. | Saem na T7b. |
