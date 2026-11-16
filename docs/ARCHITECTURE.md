# ARCHITECTURE.md — App do Fut (um código, vários apps)

> Documento de referência para quem executa as tarefas (Antigravity / Claude Code).
> Base: `docs/INVENTARIO_SUPABASE.md`. Em caso de conflito entre este documento e o código, **pare e registre em `docs/DUVIDAS.md`** em vez de decidir sozinho.
>
> **Status (15/11/2026): Fase 1, Fase 1b e Fase 2 concluídas; fase C (correções pós-Fase 2) em andamento (`docs/C-TASK.md`, estado em `docs/TASKS.md`).** T0 a T7 e tarefas estéticas/funcionais da Fase 2 (E1a, E1b, E1c, E1d) estão concluídas (site somente leitura no Cloudflare Pages, link por token, dashboard web/app, estatísticas da temporada no padrão do ranking, personalização de estilos de avatar fundo vs auréola, atualizações e notificações pessoais). 322 testes passando (rodados em 15/11/2026, já com a C2), 0 erros no analyze (só avisos antigos: 14 warnings, o resto `info`). Bugs resolvidos e pendências: seção 11, `docs/F2-TASK.md` e `docs/BACKLOG.md`.

## 1. Objetivo

Um único repositório gera:

| App | Dados | Login | Admin | Tema | Quem usa |
|---|---|---|---|---|---|
| **personal** | Supabase | sim | sim | Blue Lock | Enzo e o grupo dele |
| **public** | SQLite local (drift) | não | o dono do aparelho é admin | neutro | qualquer pessoa |
| **web_readonly** | Supabase (somente leitura, por snapshot via token) | não: web no ar, link secreto sem login, apenas leitura | não | igual ao personal | quem usa iPhone |

O app public terá botões **Exportar banco (.db)** e **Importar banco (.db)** como backup. Quem quiser ficar online "se vira" usando as interfaces e o schema documentado.

## 2. Regras de ouro

1. **Fase 1 não muda comportamento.** O app personal deve continuar idêntico depois de cada tarefa.
2. **Isolamento do Supabase:** só `lib/data/supabase/` e `lib/bootstrap_personal.dart` podem importar `supabase_flutter`. A subpasta `lib/data/supabase/readonly/` faz parte de `data/supabase/` (por isso pode importar `supabase_flutter` para o `SnapshotSource`), enquanto `bootstrap_web.dart` usa `SupabaseConfig.client` sem importar `supabase_flutter` diretamente. Verificação (deve imprimir **nada**):
   ```
   grep -rl "supabase_flutter" lib | grep -v "^lib/data/supabase/" | grep -v "^lib/bootstrap_personal.dart"
   ```
3. Telas, widgets, serviços e utils dependem de **interfaces** (`lib/domain/`) e de `AppServices` / `AppFeatures`. Nunca de classes `Supabase*`.
4. `lib/utils/*_calculator.dart` não dependem de plataforma nem de banco. **Não alterar as fórmulas.** **Exceção conhecida (após a T3e):** `getAllGroupMatches` em `stats_calculator.dart` agora recebe `matchesRepository`, `playersRepository` e `matchHistoryStore` por injeção, mas o fallback ainda lê as chaves legadas `sessions_*` e `seasons_*` direto do `SharedPreferences` (~linhas 106-120), e `site_data_generator.dart` (~35-43) também. Ninguém *cria* essas chaves; a única rotina que as reescreve é `_normalizeSessionIds` (`supabase_site_sync_service.dart:171-215`), chamada por `exportDataToSupabase` (linha 31), ou seja, só roda quando o envio ao site antigo roda (e só troca ids antigos `session_<timestamp>` e renomeia `match_history_<id>`). Ficam como leitura legada; saem junto com a T7b.
5. **Não alterar:** nomes de tabelas/colunas do Supabase, policies RLS, RPCs, fórmulas dos calculators. **Exceções aditivas aprovadas:** (a) tabela `group_share_tokens` e funções `get_/rotate_/revoke_group_share_token` e `get_group_snapshot` (`SECURITY DEFINER`); (b) S1 (quando aplicada): substitui a policy `players_select`, cria `visible_player_ids()`, reversível.
6. Uma tarefa = uma branch = commits pequenos. Antes de terminar: `flutter analyze` e `flutter test`.
7. **Não adicionar pacotes** sem estar listado na tarefa. Pacotes previstos mais à frente: `drift`, `drift_flutter` (ou `sqlite3_flutter_libs`), `path`.
8. Exceções e mensagens de erro existentes (ex.: "sem permissão") devem ser **preservadas com o mesmo texto**.
9. Dúvida ou achado fora do escopo → `docs/DUVIDAS.md` (arquivo, linha, o que viu). Não resolver por conta própria.
10. **Não renomear nem alterar chaves de `SharedPreferences`** (lista na seção 9). Uma chave alterada faz o app perder partidas pendentes ou o estado da partida em andamento de quem já tem o app instalado.
11. **Não mexer na lógica de proteção contra queda de internet** (fila de envio, cache, estado local da partida; seção 9). Só é permitido movê-la de pasta/abstraí-la como descrito nas tarefas, preservando o comportamento.

## 3. Estrutura de pastas (conferida com `ls` em 15/11/2026)

```
lib/
  domain/
    repositories/      # interfaces (classes abstratas) — Fase 1 / T1
    services/          # AuthService, PermissionService, MatchOutbox, SiteSyncService, DiagnosticsService
  data/
    supabase/          # implementações Supabase* (e supabase_config.dart, cache_store.dart, site_data_generator.dart)
      readonly/        # web somente leitura por token (9 arquivos): snapshot_source.dart (chama a RPC get_group_snapshot), readonly_services.dart e token_*_repository.dart (groups, matches, membership, players, seasons, session_arrivals, sessions)
    prefs/             # implementações em SharedPreferences (histórico local de partidas, insígnias personalizadas) — T3e
    local/             # drift/SQLite (Fase 3)
  app/
    app_services.dart  # guarda as implementações ativas (substitui SupabaseService.instance)
    app_features.dart  # flags por flavor
  bootstrap_personal.dart
  bootstrap_web.dart         # web somente leitura (usa SupabaseConfig.client, sem importar supabase_flutter)
  bootstrap_public.dart      # Fase 3
  main_personal.dart
  main_web.dart              # entrypoint do site (`flutter build web -t lib/main_web.dart`)
  main_public.dart           # Fase 3
  screens/web/home_dashboard_screen.dart   # aba "Início" (site e app; DUVIDAS #44)
  services/              # group_bootstrap.dart, avatar_style_manager.dart (estilo de avatar por tela), dashboard_store.dart (destaques calculados uma vez por grupo)
  utils/                 # novos: dashboard_highlights.dart, group_milestones_calculator.dart, player_session_summary.dart
  widgets/shared/notifications_sheet.dart; widgets/player/player_sessions_list.dart; models/milestone_update.dart
  (constants, models, screens, theme, utils, widgets: como estão; a pasta lib/config/ deixou de existir, o supabase_config.dart está em lib/data/supabase/)
tool/legacy/           # scripts de migração antigos (fora dos apps)
docs/
```

`lib/main.dart` continua existindo, apenas chamando `main_personal.dart`, para não quebrar comandos atuais. O site é gerado por `lib/main_web.dart` (workflow `.github/workflows/deploy-web.yml`).

## 4. Mapa de interfaces (origem → destino)

### 4.1 Núcleo (existe nos dois apps)

| Interface | Origem | Observação |
|---|---|---|
| `GroupsRepository` | `groups_repository.dart` | `getMyGroups`, `createGroup`, `updateGroup`, `deleteGroup` + getter `lastLoadFromCache`. No public: um grupo único criado no primeiro uso. |
| `SeasonsRepository` | `seasons_repository.dart` | Todos os 5 métodos, assinaturas iguais. |
| `SessionsRepository` | `sessions_repository.dart` | 7 métodos (`getCachedSession`, `getSessionById`, `getSessionsByGroup`, `createSession`, `updateSession`, `updateRuntimeState`, `deleteSession`) **+ novo** `getRuntimeState(String sessionId)` (ver 4.4). Fora: `getSessionsBySeason`, `finalizeSession` (0 chamadores). |
| `MatchesRepository` | `matches_repository.dart` | **Só estes (5):** `getMatchesBySession`, `getMatchesByGroup`, `savePendingMatch`, `updatePartialMatch`, `deleteMatch`. Fora: `saveFullMatch` e `updateFullMatch` (0 chamadores). `savePendingMatch` fica (fila offline do personal); no public pode gravar direto. |
| `RatingsRepository` | `ratings_repository.dart` | **Não terá interface:** os 4 métodos (`getPlayerHistoryBySeason`, `getFullPlayerHistory`, `getLatestRatingsBySeason`, `recordRatingsBatch`) têm 0 chamadores. **Hoje nada lê nem grava `rating_history`**: as notas são calculadas em memória a partir de partidas e eventos. |
| `CustomBadgesRepository` (novo) | `manage_badges_screen`, `player_detail` | `getCustomBadges(groupId)`, `saveCustomBadges(groupId, badges)` e `hasCustomBadges(groupId)` (a chave já foi gravada alguma vez, mesmo com lista vazia; preserva o `containsKey` original). Hoje vive só em `SharedPreferences` (`custom_badges_<grupo>`); não existe no Supabase. Personal: `PrefsCustomBadgesRepository` em `lib/data/prefs/` (SharedPreferences, igual hoje). Public: tabela no SQLite. |
| `MatchHistoryStore` (novo) | `match_screen`, ranking, `stats_calculator` | `readSession(sessionId)`, `appendToSession(sessionId, record)` e `hasSession(sessionId)` (a chave já foi gravada alguma vez; preserva o `containsKey` original; no SQLite significará "já salvou alguma vez"). JSON corrompido vira lista vazia e itens que não são `Map` são descartados. Hoje é `match_history_<sessão>` em `SharedPreferences`. Personal: igual hoje. Public: derivado das tabelas do SQLite. Quem usa é decidido na T3e. |
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
  String? get currentUserEmail;          // usado por main.dart (decidido na T2)
  bool get isSignedIn;
  Stream<bool> get signedInChanges;      // substitui auth.onAuthStateChange no AuthGate
  Future<void> signIn(String email, String password);
  Future<void> signUp(String email, String password);
  Future<void> signOut();
}
// Erros viram AppAuthException(message) — telas não conhecem AuthException do Supabase.

abstract class PermissionService {
  Future<bool> isAdmin(String groupId);      // mesma regra de hoje: creator_id OU role == 'admin'
  Future<void> requireAdmin(String groupId, [String? message]); // lança Exception(message); cada repositório passa o texto que já usava (decidido na T2)
}
```

- Os repositórios Supabase recebem `PermissionService` no construtor e deixam de chamar `_membersRepo.isCurrentUserAdmin`.
- No app public: `AuthService` sempre logado com id fixo local; `PermissionService.isAdmin` sempre `true`.

### 4.3b Serviços da camada de rede (descobertos no `INVENTARIO_OFFLINE.md`)

```dart
abstract class MatchOutbox {            // fila de envio de partidas (hoje: SupabaseMatchOutbox)
  ValueListenable<int> get pending;
  ValueListenable<int> get failed;       // partidas com erro permanente (status 'failed')
  ValueListenable<String?> get lastError;
  Future<void> enqueue(Map<String, dynamic> job);
  Future<void> flush();
  Future<void> refreshCounts();
  Future<List<Map<String, dynamic>>> failedJobs();
  Future<void> retryFailed(String matchId);
  Future<void> discardFailed(String matchId);
}
abstract class SiteSyncService {        // hoje: sync_service (o que sobra após a T0c)
  Future<String> getOrCreateSyncCode();
  Future<void> exportDataToSupabase(String syncCode);
}
abstract class DiagnosticsService {     // hoje: cache_sync_manager (painel de debug do admin)
  // mesmos métodos públicos de CacheSyncManager + a classe CacheSyncStatus
}
```

- `MatchOutbox` — personal: `SupabaseMatchOutbox` (a antiga `PendingMatchQueue`, com suporte a contagem de falhas permanentes e recuperação). Public: `LocalMatchOutbox`, que grava direto no SQLite; `pending` fica sempre 0 e `flush` não faz nada. O selo de pendentes também aparece na HomePage.
- `SiteSyncService` e `DiagnosticsService` — só personal; no public ficam `null` em `AppServices`.
- `CacheStore` (cache de leitura usado só pelos repositórios Supabase) vai junto com eles para `lib/data/supabase/`.
- `GroupBootstrap` (snapshot local do elenco) fica em `lib/services/`; só depende de repositórios via `AppServices`.

### 4.4 Consulta solta a corrigir

`lib/screens/match_screen.dart:410-415` consulta `sessions` direto. Vira `SessionsRepository.getRuntimeState(sessionId)` retornando `Map<String, dynamic>?` com as colunas `seconds_played, is_running, score_red, score_white, red_streak, white_streak, is_overtime, started_at`. Mesmo resultado de hoje.

### 4.5 Métodos sem chamadores e telas inalcançáveis (de `docs/CODIGO_MORTO.md`)

- **Métodos com 0 chamadores** (não entram em nenhuma interface e não serão implementados no SQLite; **permanecem** nas classes Supabase por enquanto, não apagar nesta fase): `ActionLogsRepository.getRecentLogs/exportAndCleanOldLogs`; `GroupMembersRepository.addMember/removeMember`; `MatchesRepository.saveFullMatch/updateFullMatch`; `PlayersRepository.createPlayerWithUser/linkEmailToPlayer/uploadGoalSound/clearGoalSound/setCosmetics`; `RatingsRepository` (os 4 métodos); `SessionArrivalsRepository.clearArrivals`; `SessionsRepository.getSessionsBySeason/finalizeSession`.
- **Telas inalcançáveis** (nenhuma rota ou botão as abre): `expanded_ranking_screen`, `group_ranking_screen`, `tournament_screen`, `blank_screen`. Removidas na T0g (Enzo confirmou).
- Se algum desses itens for planejado (ex.: tela de logs do admin, login por e-mail, gráfico de evolução usando `rating_history`), reavaliar antes de apagar o código.

### 4.6 `AppServices` (17 campos hoje, `lib/app/app_services.dart`)

`features` (AppFeatures), `groups`, `members`, `seasons`, `players`, `playerAccounts`, `sessions`, `matches`, `sessionArrivals`, `actionLogs`, `auth`, `permissions`, `outbox`, `matchHistory`, `customBadges`, e os opcionais `siteSync` e `diagnostics` (nulos no public e na web). `AppServices.instance` é definido uma vez em `bootstrap_personal.dart`. Pontos de entrada: `lib/main.dart` (só chama `mainPersonal()`) → `lib/main_personal.dart`. Isolamento do Supabase conferido em 15/11/2026: **16** arquivos importam `supabase_flutter` (15 em `lib/data/supabase/` + `lib/data/supabase/readonly/snapshot_source.dart`), todos dentro de `lib/data/supabase/`; `bootstrap_personal.dart` hoje não importa. A regra 2 continua válida (o grep da regra imprime nada).

## 5. Feature flags (`AppFeatures`)

| Flag | personal | public | web_readonly |
|---|---|---|---|
| `hasAuth` (login) | true | false | false |
| `hasMembershipManagement` (convites, pedidos, papéis) | true | false | false |
| `hasCosmetics` (efeitos de nome, Bola de Ouro, Craque do Mês) | true | false (ou simplificado) | true |
| `hasGoalSounds` | true | false | false |
| `hasAuditLog` | true | false | false |
| `hasSiteSync` (envio do "pacote do site" antigo para `sync_data`: Timer de uso único de 90 s, rearmado após cada partida finalizada, `match_screen.dart:3713-3725`) | true | false | false |
| `hasCloudDraftSync` (rascunho da partida no Supabase: `replaceArrivals`/`updateRuntimeState`, restauração remota no `_loadMatchState`) | true | false | false |
| `hasAdminDebug` (painel de debug, teste de conexão) | true | false | false |
| `hasDbExportImport` | false | true | false |
| `isReadOnly` | false | false | true |

Regra: tela de admin/engrenagem/edição aparece se `AppFeatures` permitir **e** `PermissionService.isAdmin` for true (e `isReadOnly` for false). No código: `bool canAdminister(bool isAdmin) => !isReadOnly && isAdmin;` em `AppFeatures`, usado em 9 telas. Ações de escrita que **não** exigiam admin na versão original só ganharam `!isReadOnly` (lista completa em `docs/DUVIDAS.md` #19).

**Estado da T4:** implementada. `hasMembershipManagement`, `hasCosmetics`, `hasGoalSounds`, `hasSiteSync`, `hasCloudDraftSync`, `hasAdminDebug` e `isReadOnly` já são consultadas pelas telas. **Ainda sem uso:** `hasAuth`, `hasAuditLog`, `hasDbExportImport` (serão ligadas nas Fases 2 e 3). Para o site (Fase 2): **decidido: `match_screen` não existe na web.** (O arquivo ainda entra no build web por causa do import em `tournament_dashboard_screen.dart:6`, mas a tela não é oferecida com `isReadOnly`; teste em `test/screens/tournament_dashboard_readonly_test.dart`.)

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

- `dart:io`/`File`/`path_provider` em `ranking_screen.dart` e `history_screen.dart` (screenshot/compartilhar) → usar import condicional ou `kIsWeb` e esconder/adaptar. (`group_ranking_screen.dart` foi removida na T0g.)
- Os scripts em `tool/legacy/` usam `dart:io` e ficam fora do app. `sync_service.dart` perdeu o `dart:io` na T0c; confirmar na Fase 2.
- `file_picker` (usa `path`), `share_plus` e `audioplayers` têm limitações na web.

- **Cache do elenco (achado de 02/11):** `PlayerComparisonScreen` lê **só** `players_<groupId>` no `SharedPreferences` e `match_screen` (adicionar jogadores) usa essa chave antes do Supabase. Na web não há `GroupBootstrap.prefetch` rodando como no celular, então essas telas ficariam vazias ou com "Desconhecido". A correção dos bugs B2/B3 (fase 1b) deve fazer essas telas buscarem pelo repositório quando o snapshot faltar, antes da Fase 2.
- `SharedPreferences` na web é `localStorage` do navegador: nenhum dado de partida em andamento ou fila existe lá; telas que dependem disso precisam funcionar sem.

**Estado (15/11/2026): no ar.** Link curto `…/fut` redireciona para `#/g/<token>` (arquivo `_redirects` gerado no deploy a partir do secret `FUT_TOKEN`). Hospedagem: Cloudflare Pages (projeto `app-fut-site`, deploy por GitHub Actions, `flutter build web --release -t lib/main_web.dart --pwa-strategy=none`). **A web não tem `match_screen`** (decidido): partida ao vivo e notificações de evento são só do app.

Modelo de acesso: **link secreto sem login** (decidido; ver `TASKS.md`, Fase 2). A segurança real é por token + funções `SECURITY DEFINER` no banco (T6), não por esconder botão. Os repositórios da web vivem em `lib/data/supabase/readonly/` (parte integrante de `data/supabase/`, utilizando `SnapshotSource` que pode importar `supabase_flutter`), e a inicialização em `bootstrap_web.dart` consome `SupabaseConfig.client`.

## 8. Checklist manual de regressão (rodar no celular após cada merge na main)

1. Abrir o app e entrar (login).
2. Abrir o grupo e ver o ranking de uma pelada e as estatísticas da temporada.
3. Criar uma pelada, adicionar presentes.
4. Jogar uma partida: gol, cronômetro, finalizar. Conferir que salvou.
5. Ver histórico e estatísticas da temporada.
6. Abrir um jogador: carta e comparação.
7. Com usuário **não admin**: engrenagem não aparece em Peladas/Elenco/Estatísticas.
8. Com admin: gerenciar membros e temporadas abre normalmente.
9. **Modo avião:** finalizar uma partida e ver o selo de pendentes (e, no diálogo de pendências, o erro e o botão "Tentar agora"; não existe banner nem botão "Reenviar agora", esses nomes vinham do inventário). Fechar o app por completo e abrir de novo (ainda em modo avião): a partida pendente continua aparecendo no histórico e no ranking. Desligar o modo avião, abrir a tela de partida da pelada (ou tocar "Tentar agora") e conferir que a partida aparece no Supabase, **uma só vez** (sem duplicar). (Obrigatório depois de qualquer tarefa que toque fila, cache ou `match_screen`.)

## 9. Proteção contra queda de internet — como funciona hoje (NÃO MEXER)

Fonte: `docs/INVENTARIO_OFFLINE.md`. São 4 camadas independentes; **nenhuma é o `sync_service`**:

1. **Estado da partida em andamento** — `match_screen._saveMatchState()` grava a cada ação no `SharedPreferences` (placar, eventos, times, cronômetro, goleiros...). Se o app fecha, `_loadMatchState()` restaura e recalcula o cronômetro pela hora de início.
2. **Fila de envio (outbox)** — `SupabaseMatchOutbox` (antes `PendingMatchQueue`): ao finalizar, a partida é gravada em `pending_matches_v1` e enviada em segundo plano. **Gatilhos reais de envio** (confirmados no código, `DUVIDAS.md` itens 14 e 29): 2 s depois de enfileirar; reenvio automático por timer (5s, 10s, 20s, 40s, 60s) enquanto o app está aberto; `initState` da `MatchScreen`; `_startMatch`; botão "Tentar agora" do diálogo de pendências; ao abrir o app após login reconhecido (`_ProfileCheckState.initState` via `triggerOutboxFlush()`); e ao voltar do segundo plano (`_AuthGateState.didChangeAppLifecycleState` com `AppLifecycleState.resumed`).
   - **Isolamento de partidas com problema:** 2 erros permanentes consecutivos entre `23503`, `23502`, `23514`, `22P02` (detectados via `isPermanentOutboxError`) marcam a partida com `status: 'failed'` (campos novos: `status`, `permanent_failures`, `error_code`, `error_message` e `failed_at` no mesmo `pending_matches_v1`). Partidas com erro permanente saem do topo da fila para não bloquear os envios seguintes e são excluídas das estatísticas (`readAll`). A UI oferece opções de "Copiar dados", "Tentar de novo" (`retryFailed`) e "Descartar" (`discardFailed`).
3. **Cache de leitura** — `CacheStore` (chaves `cache:*`) usado pelos repositórios de partidas, sessões e jogadores como fallback quando a rede falha. Inclui também o cache da lista de grupos da conta (`groups:my:<userId>`), adicionado na T-B6b com o getter `lastLoadFromCache` e aviso na tela, permitindo que a `HomePage` abra e mostre os grupos salvos mesmo sem conexão (corrigindo a suposição antiga de que a HomePage "já usava cache").
4. **Snapshot do elenco** — `GroupBootstrap` (`players_<groupId>`, `ratings_snapshot_at_<groupId>`) permite sorteio/draft sem rede.

Chaves de `SharedPreferences` que NÃO podem mudar (lista completa do que o código **grava**, conferida com grep em 15/11/2026; `<id>` = id da pelada):

| Grupo | Chaves | Onde |
|---|---|---|
| Fila de envio | `pending_matches_v1` | `supabase_match_outbox.dart:37` |
| Cache de leitura | `cache:*` (inclui `cache:groups:my:<usuário>`, a lista de grupos da conta; prefixo em `cache_store.dart:18`) | repositórios Supabase |
| Diagnóstico (painel de debug) | `cache_has_pending_cloud_sync`, `cache_last_cloud_sync_at`, `cache_last_cloud_fetch_at` | `supabase_diagnostics_service.dart:10-12` |
| Snapshot e dados locais | `players_<grupo>`, `ratings_snapshot_at_<grupo>`, `match_history_<sessão>`, `custom_badges_<grupo>` | `group_bootstrap.dart`, `prefs_*`, telas |
| Partida em andamento | `present_players_<id>`, `team_red_<id>`, `team_white_<id>`, `score_red_<id>`, `score_white_<id>`, `match_events_<id>`, `is_overtime_<id>`, `seconds_played_<id>`, `is_running_<id>`, `start_timestamp_<id>`, `red_streak_<id>`, `white_streak_<id>`, `active_gk_red_<id>`, `active_gk_white_<id>`, `first_gk_red_<id>`, `first_gk_white_<id>` | `match_screen.dart` |
| Preferências de tela | `show_radar_chart`, `confirm_timer_enabled`, `pitch_horizontal`, `pitch_use_cards`, `pitch_use_chips`, `show_tactical_pitch`, `require_gk`, `avatar_style_ranking`, `avatar_style_dashboard`, `avatar_style_stats`, `avatar_style_match`, `last_seen_notif_<grupo>_<jogador>` | `settings_screen`, `match_screen`, `avatar_style_manager.dart`, `notifications_sheet.dart` |
| Site antigo (saem na T7b) | `my_sync_code`, `sync_history` | `supabase_site_sync_service.dart`, `match_screen.dart` |
| Só lidas (legado; ninguém cria) | `sessions_<grupo>`, `seasons_<grupo>`, `app_groups*`, `players_grupo_*` | `stats_calculator.dart`, `site_data_generator.dart` |

O grep não achou nenhuma outra chave gravada além destas (`seasons_config` no `site_data_generator` é um campo do JSON enviado, não uma chave).

O que o `SupabaseSiteSyncService` (antigo `sync_service`) e o `SupabaseDiagnosticsService` (antigo `cache_sync_manager`) realmente fazem: o `SupabaseSiteSyncService` envia o "pacote do site" (JSON do `SiteDataGenerator`) para `sync_data` por um **Timer de uso único de 90 s, rearmado após cada partida finalizada** (`_scheduleSiteSync`, `match_screen.dart:3713-3725`; não é um ciclo) e ao fechar a tela de partida (alimenta o site antigo); `cache_sync_manager` é diagnóstico do painel de debug do admin (ping e dump do storage). Nenhum dos dois dispara reenvio da fila.

## 10. Dados que hoje vivem só no SharedPreferences (de `INVENTARIO_SHAREDPREFS.md`)

| Dado | Chave | Situação hoje | Decisão |
|---|---|---|---|
| Súmula local das partidas | `match_history_<sessão>` | Fallback de `RankingScreen` e `MatchScreen` (a antiga `GroupRankingScreen` foi removida na T0g); lida também por `stats_calculator`. Escrita por `match_screen` ao finalizar. | Interface `MatchHistoryStore` (T3e). Personal: SharedPreferences, igual hoje. Public: derivada das tabelas do SQLite (somente leitura; `appendToSession` não faz nada). `GroupRankingScreen` foi removida na T0g. |
| Insígnias personalizadas | `custom_badges_<grupo>` | Não existe no Supabase; cada aparelho tem as suas. | `CustomBadgesRepository`. Personal: igual hoje. Public: tabela `custom_badges` no SQLite (entra no `.db`). Web: vazio por enquanto. |
| Elenco com campos calculados | `players_<grupo>` | Cache do Supabase, recriado pelo `GroupBootstrap`. | Continua como cache nos dois apps. Depois de importar um `.db`, apagar esses snapshots e `cache:*` (T11). |
| Cache de leitura | `cache:*` | Só repositórios Supabase. | Fica em `lib/data/supabase/`; não existe no public. |
| Estado da partida em andamento | `present_players_*`, `team_*`, `score_*`, `is_running_*`... | Temporário. | Continua em SharedPreferences nos dois apps; **não** vai para o `.db`. Avisar na tela que exportar/importar deve ser feito entre partidas. |
| Preferências de tela | `show_radar_chart`, `confirm_timer_enabled`, `pitch_*`, `show_tactical_pitch`, `require_gk`, `avatar_style_*`, `last_seen_notif_<grupo>_<jogador>`... | Config do aparelho. | Continuam locais; não fazem parte do backup. |
| Legado sem criador | `sessions_*`, `seasons_*`, `app_groups`, `players_grupo_` | Eram lidos por `GroupRankingScreen` (removida na T0g); ainda lidos por `stats_calculator` e `site_data_generator`. Ninguém cria essas chaves, mas existe uma rotina que reescreve `sessions_*` (e `players_*`, `match_history_*`): `_normalizeSessionIds`/`_normalizeUuidData` em `supabase_site_sync_service.dart` (a partir da linha 73 e 171), chamadas por `exportDataToSupabase` (linhas 30-31), que só roda no envio ao site antigo. O aparelho do Enzo pode ainda ter dados antigos. | **Não remover na T3e.** A Fase 1 já acabou; a decisão de limpar fica junto da T7b (que remove o envio ao site antigo). No app public ficam vazias e inofensivas. |
| Envio do site e diagnóstico | `sync_history`, `my_sync_code`, `cache_*_cloud_*` | Só do envio do pacote do site e do painel de debug. | Saem na T7b. |

## 11. Bugs conhecidos: resolvidos na Fase 1b (detalhe em `docs/BACKLOG.md` seção 0)

Os bugs mapeados no levantamento da Fase 1 foram integralmente corrigidos e integrados na `main` durante a Fase 1b (ver detalhes completos e testes em [BACKLOG.md](file:///home/marinho/Documents/github/App-Fut/docs/BACKLOG.md)):

- **B1 / B1b — Criar grupo e temporada (branches `fix/create-group-season-id` e `fix/create-season-id`):** `createGroup` e `createSeason` agora geram UUID v4 (`const Uuid().v4()`) no código Dart para o campo `id` da temporada, sanando o erro `23502` (`NOT NULL` sem default no PostgreSQL), e contam com rollback sequencial em caso de falha intermediária.
- **B2 / B3 — Cache do elenco e nome do jogador (branch `fix/players-cache`):** `SupabasePlayersRepository` invalida `players:group:<groupId>` no `CacheStore` ao criar, remover ou atualizar jogadores. Mutações atualizam o snapshot local via `GroupBootstrap.refreshLocalSnapshot`. `updatePlayer` persiste alterações no Supabase validando permissões (admin ou dono da conta). As telas de partida e comparação usam fallback automático caso o jogador não esteja no snapshot local.
- **B4 — Estatísticas avançadas do jogador (branch `feature/player-advanced-stats`):** Percentuais de distribuição de derrotas corrigidos pelo Enzo em 02/11.
- **B5 — Partida presa na fila de envio (branch `fix/outbox-permanent-errors`):** Separação de erros transitórios e permanentes (`isPermanentOutboxError` cobrindo `23503`, `23502`, `23514`, `22P02`). Partidas com 2 falhas permanentes consecutivas recebem `status: 'failed'`, não bloqueiam a fila e saem de `readAll()`, com interface para copiar dados, tentar de novo ou descartar.
- **Abrir o app sem rede (branches `fix/offline-startup` e `fix/groups-offline-cache`):** `ProfileCheckResult` distingue erro de rede de lista vazia; `GroupsRepository.getMyGroups` faz cache offline sob `groups:my:<userId>` com o getter `lastLoadFromCache` e aviso de dados salvos na `HomePage`; gatilhos automáticos de outbox ao abrir o app e ao retornar do background.

### O que continua em aberto (ver `docs/BACKLOG.md` "Pendências deixadas pela Fase 1b"):
- **B6:** Qualquer pessoa com o app cria grupos (decisão de desenho; todos os grupos de teste e de terceiros foram apagados em 02/11, exceto o Fut do INF (dados reais, 71 jogadores); discussão de gestão de grupos retorna após o app offline).
- Linhas parciais em `matches`/`match_lineups`/`match_events` no Supabase quando uma partida isolada falha e o descarte remove apenas o armazenamento local (`DUVIDAS.md` 30; candidata: T-B5b).
- `createSeason` sequencial sem bloco transacional / RPC atômica (`DUVIDAS.md` 26).
- RLS da tabela `players` permitindo ao dono alterar outras colunas além do nome (`DUVIDAS.md` 28).
- Tratamento de JSON corrompido em `_readFromPrefs` da outbox para não sobrescrever a fila no próximo enqueue.
- Latência de rede no diálogo de adicionar jogadores offline e detalhes de cache/snapshot mapeados na revisão da Fase 1b.

## 12. O que veio com E1a a E1e (aba Peladas, dashboard, avatares, notificações e cards de resumo)

Na `main` desde 15/11/2026 (commits `b2ea3fa` e `9432713`), estendida em 16/11/2026 com E1e. Código conferido com `ls`/`git show --stat`:

| Recurso | Arquivos |
|---|---|
| Aba "Peladas" na carta do jogador (E1a) | `lib/widgets/player/player_sessions_list.dart`, `lib/utils/player_session_summary.dart`, integração em `lib/screens/player_detail.dart` |
| Dashboard "Início" (E1b), **aba presente no site e no app** (DUVIDAS #44) | `lib/screens/web/home_dashboard_screen.dart`, `lib/services/dashboard_store.dart` (calcula uma vez por grupo), `lib/utils/dashboard_highlights.dart` (destaque do mês, artilheiro, garçom, última pelada, maior goleada), abas em `lib/screens/group_dashboard_screen.dart` |
| Cards de Resumo Geral no Dashboard (E1e) | `lib/screens/web/home_dashboard_screen.dart` (`_overviewCards`), `lib/utils/dashboard_highlights.dart` (`GroupOverviewStats`, `computeGroupOverview`), `lib/services/dashboard_store.dart`. Cards de partidas jogadas, sessões realizadas, jogadores cadastrados (ativos na temporada atual) e gols marcados (média por partida), com indicador de participação pessoal no app móvel autenticado |
| Destaque do mês (calculado) × Craque do mês (selo manual `monthly_highlight`) | `dashboard_highlights.dart` (calculado); selo manual vem de `PlayersRepository.setMonthlyHighlight`. O selo guarda só o portador atual, sem mês (BACKLOG) |
| Tela de estatísticas da temporada no padrão do ranking (E1c) | `lib/screens/season_stats_screen.dart` |
| Estilos de avatar por tela, fundo ou auréola (E1d) | `lib/services/avatar_style_manager.dart` (chaves `avatar_style_ranking/dashboard/stats/match`), `lib/widgets/shared/ranking_player_bits.dart`, `lib/widgets/player/fifa_card.dart`, configuração em `lib/screens/settings_screen.dart` |
| Seção "Atualizações" do dashboard (E1d) | `lib/utils/group_milestones_calculator.dart`, `lib/models/milestone_update.dart`, card em `home_dashboard_screen.dart` |
| Sino de notificações pessoais (E1d), **só no app** (`!kIsWeb && hasAuth && _myPlayerId != null`) | `lib/widgets/shared/notifications_sheet.dart`, `group_dashboard_screen.dart`; chave `last_seen_notif_<grupo>_<jogador>` |
| Testes novos | `test/screens/home_dashboard_screen_test.dart`, `test/utils/{dashboard_highlights,player_session_summary,group_milestones_calculator}_test.dart`, `test/widgets/{player_sessions_list,notifications_sheet}_test.dart`, `test/services/avatar_style_manager_test.dart` |

A versão do app subiu para `1.2.0+3` (`pubspec.yaml`, só o número; nenhum pacote novo).

**Nota da carta (C2, branch `fix/rating-all-history`, já mesclada na `main`, merge `027fb03`):** nota e overall pela história inteira em todas as telas; gols, jogos e posição continuam respeitando o filtro de período.

## 13. Banco: o que o app e o site usam de fato

- **Site (web somente leitura):** uma única chamada, a RPC `get_group_snapshot(p_token)` (`lib/data/supabase/readonly/snapshot_source.dart:193`). Não lê tabelas direto e não escreve nada. A tabela `group_share_tokens` e as funções `get_/rotate_/revoke_group_share_token` existem no banco (T6), mas **nenhum código do app as chama**: o token é girado pelo SQL Editor (T6c adiada).
- **App personal:** tabelas do inventário (`docs/INVENTARIO_SUPABASE.md`), as RPCs `approve_join_request`, `reject_join_request`, `claim_ghost_profile`, `find_group_by_invite_code`, e a tabela `sync_data` (só o envio ao site antigo e o teste de conexão do painel de debug; sai na T7b).
- `F2_T6_share_link.sql` (cria `group_share_tokens` e as funções) **não está no repositório** (tarefa C5). `docs/S1_players_select_rls.sql` está (S1, nada aplicado no banco).

## 14. T7b: lista de dependências do envio ao site antigo (conferida no código)

A T7b continua **por último**. O que a remoção precisa tratar: `_siteSyncTimer` e `_scheduleSiteSync` (`match_screen.dart:70, 3713-3725`), `dispose` (137-140), `_triggerBackgroundSync` (4301), `_recordSyncHistory` (4318), `hasSiteSync` (`app_features.dart:40, 66`), `SiteSyncService` (interface), `SupabaseSiteSyncService` (inclui `_normalizeUuidData` e `_normalizeSessionIds`), `my_sync_code`, `sync_history`, `SiteDataGenerator`, tabela `sync_data`, `AppServices.siteSync`, `bootstrap_personal.dart:44, 71` (criação e registro; o `bootstrap_web.dart:161` passa `null`), `admin_debug_screen.dart:36-40`. Mexe no `match_screen`: exige revisão e teste de modo avião.

## 15. Decisões novas da fase C (15/11/2026)

- **C2:** nota e overall pela história inteira em todas as telas (feito).
- **C3:** todos veem a lista de partidas do histórico; só o admin altera (lixeira "Limpar tudo", lápis, toque longo de debug); mesmo o admin precisa de confirmação para alterar o histórico. Menu ⋮ do grupo (Editar/Excluir) só admin (o código já exige admin ao salvar: `groups_repository.dart:320, 349`). A confirmação dentro do app é atrito contra clique acidental, não segurança: a proteção real é o RLS exigir admin. RLS conferido em 16/11/2026 (C3b): `matches`, `match_events`, `match_lineups`, `rating_history` e `sessions` têm RLS ligado e uma policy `ALL` que exige `is_group_admin(...)`; membro comum não altera nem pelo banco. Na C3c (concluída em 16/11/2026), a senha `"0101"` fixa foi completamente removida: o admin escolhe nas Configurações entre "Usar autenticação do aparelho (recomendado)" (digital ou PIN do celular, via `local_auth`) e "Usar senha" (senha do app com hash SHA-256 e sal aleatório via `crypto` em SharedPreferences); a confirmação protege todas as ações destrutivas (lixeira, lápis, Editar/Excluir grupo, excluir pelada).
- **C1:** preview "Entra:" do diálogo de fim de partida (`match_screen.dart:3682-3702`); exige teste de modo avião.
- **C5:** mover `F2_T6_share_link.sql` para `docs/sql/`, sem token.
- **Ordem das frentes:** C2 ✅, C4 ✅, C3 ✅, C3b ✅, C3a ✅, C3c ✅, C1, C5; depois pendências da Fase 2 e S1; depois Fase 3; T7b por último.
