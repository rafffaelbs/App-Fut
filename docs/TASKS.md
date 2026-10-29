# TASKS.md — Plano de tarefas (v2, após INVENTARIO_OFFLINE)

Legenda de quem faz: **AG** = Antigravity (executa) · **CLAUDE** = Claude (desenha ou revisa).
Fluxo de cada tarefa: criar a branch → fazer → `flutter analyze` + `flutter test` → commit → (se houver revisão) mandar para o Claude → merge na `main` → teste manual (checklist da seção 8 do `ARCHITECTURE.md`) quando indicado.

## Cabeçalho a colar no INÍCIO de todo prompt

```
Contexto: leia docs/ARCHITECTURE.md e docs/INVENTARIO_SUPABASE.md (e docs/INVENTARIO_OFFLINE.md
quando a tarefa tocar fila, cache ou match_screen) antes de começar.
Regras: não mude comportamento visível do app; não altere fórmulas dos calculators,
nomes de tabelas/colunas do Supabase, RLS ou RPCs; não altere chaves de SharedPreferences;
não adicione pacotes; preserve os textos de erro existentes. Se encontrar algo que o
documento não cobre, NÃO decida: registre em docs/DUVIDAS.md (arquivo, linha, o que viu)
e continue com o resto.
Ao terminar: rode `flutter analyze` e `flutter test`, faça commits pequenos e
me diga em 5 linhas o que mudou e o que ficou pendente.
```

---

## FASE 0 — Rede de segurança e limpeza (todas podem rodar em paralelo)

### T0 · Testes de caracterização dos cálculos — AG
Branch: `test/characterization-calculators` · Revisão: não precisa

```
[cabeçalho]
Tarefa: criar testes de caracterização para lib/utils/rating_calculator.dart,
overall_calculator.dart e stats_calculator.dart, em test/utils/.
NÃO altere nenhum arquivo em lib/.
Para cada função pública: no mínimo 5 casos com entradas fixas e variadas
(incluindo: zero eventos, sequência de vitórias, goleiro, nota nos limites 0.0 e 10.0,
jogador sem nota da comunidade). O valor esperado é o resultado ATUAL do código:
rode, copie o valor e fixe no teste. Não "corrija" nada que pareça estranho: apenas
registre em docs/DUVIDAS.md.
Se alguma função não for testável sem Flutter binding ou Supabase, anote no DUVIDAS.md.
Atenção: stats_calculator.dart lê SharedPreferences direto (getAllGroupMatches, ~linhas 100-124).
Para testar essas funções use SharedPreferences.setMockInitialValues({...}) com dados fixos
(não precisa de Supabase).
Aceite: flutter test passa; flutter analyze sem erros novos; lib/ sem alterações (git diff main --stat).
```

### T0b · Mover scripts de migração antigos — AG
Branch: `chore/move-legacy-scripts` · Revisão: não · **Confirmado pelo Enzo: não são mais usados**

```
[cabeçalho]
Mova (git mv) lib/services/data_migration_service.dart e
lib/services/fix_event_times_service.dart para tool/legacy/. Eles são scripts de
migração antigos e não devem fazer parte do app. Remova qualquer import/uso deles em
lib/ (telas, botões de debug, main). Se algo no app depender deles, liste em
docs/DUVIDAS.md e NÃO apague a funcionalidade: apenas deixe um comentário TODO.
Aceite: flutter analyze sem erros; app compila; grep por "data_migration_service" e
"fix_event_times_service" em lib/ retorna nada.
```

### T0c · Remover código morto do sync — AG
Branch: `chore/remove-dead-sync-code` · Revisão: não

Motivo (do `INVENTARIO_OFFLINE.md`): a `SyncScreen` não é alcançável por nenhuma rota; o campo `_syncService` em `main.dart` nunca é usado; `importDataFromSupabase` (que apaga todo o `SharedPreferences` antes de restaurar) só é chamado pela tela órfã; `exportToFile`/`importFromFile` não têm chamadores. Remover isso também elimina o problema do `file_picker` v11 e os usos de `dart:io` desse arquivo.

```
[cabeçalho]
Remova código morto confirmado em docs/INVENTARIO_OFFLINE.md. Antes de apagar cada item,
confirme com grep em lib/ que não há outro uso. Se houver, NÃO apague e registre em
docs/DUVIDAS.md.
1) lib/screens/sync_screen.dart (sem rota que leve a ela) e seus imports.
2) lib/main.dart (~linha 154): o campo `_syncService` de _HomePageState, que nunca é usado
   (e o import, se ficar sem uso).
3) lib/services/sync_service.dart: remova importDataFromSupabase, exportToFile e
   importFromFile, e os imports que ficarem sem uso (dart:io, file_picker, share_plus,
   path_provider, se só esses métodos os usavam).
MANTENHA: exportDataToSupabase e getOrCreateSyncCode (usados por
match_screen._triggerBackgroundSync e admin_debug_screen) e as chamadas a
CacheSyncManager.recordCloudSyncSuccess.
MANTENHA a dependência file_picker no pubspec.yaml (será usada de novo mais adiante).
Aceite: analyze/test ok; checklist manual itens 1 a 4; 
`grep -rn "SyncScreen\|importDataFromSupabase\|exportToFile\|importFromFile" lib` retorna nada.
```

### T0d · Inventário de SharedPreferences (somente leitura) — AG
Branch: `docs/inventario-sharedprefs` · Revisão: **CLAUDE** (me mande o `.md`)

```
Tarefa somente de leitura. NÃO altere arquivos em lib/.
Gere docs/INVENTARIO_SHAREDPREFS.md. Liste TODAS as chaves usadas em SharedPreferences
(getString/setString/getInt/setInt/getBool/setBool/remove/containsKey e prefixos como
cache:, players_$groupId, match_history_$id, present_players_$id, pending_matches_v1,
ratings_snapshot_at_$groupId...). Para cada chave ou prefixo informe: arquivo e linha de
quem ESCREVE, quem LÊ, o que contém e a categoria:
 (a) cache de algo que também existe no Supabase
 (b) estado temporário de partida em andamento
 (c) fila de envio
 (d) preferência de configuração
 (e) dado que SÓ existe localmente (não está no Supabase)
Responda também:
1. Quais telas leem match_history_* (histórico local) em vez de repositórios?
2. Onde rating_history é gravado no fluxo de finalizar partida (savePendingMatch não
   grava rating_history)? Quem chama recordRatingsBatch, saveFullMatch e updateFullMatch, e quando?
3. Existe algum dado exibido nas telas que NÃO venha de repositório (só de SharedPreferences)?
Apenas fatos, com arquivo e número de linha. Não proponha mudanças.
```

### T0e · Código morto e telas inalcançáveis (somente leitura) — AG
Branch: `docs/codigo-morto` · Revisão: não (me mande só o resumo) · **Fazer antes da T1**

```
Tarefa somente de leitura. NÃO altere arquivos em lib/.
Gere docs/CODIGO_MORTO.md com:
1. Para CADA método público das classes em lib/repositories/ (actions_logs, group_members,
   groups, matches, players, ratings, seasons, session_arrivals, sessions): o número de
   chamadores FORA da própria classe, com arquivo:linha de cada um. Escreva "0 CHAMADORES"
   quando não houver nenhum. Considere chamadas via SupabaseService.instance.<repo>.<método>,
   por campos injetados e por outros repositórios.
2. Para CADA arquivo em lib/screens/: quem o abre (Navigator.push, rotas nomeadas,
   MaterialPageRoute, home:), com arquivo:linha. Escreva "INALCANÇÁVEL" se nenhuma rota ou
   botão chega nele. Atenção especial: group_ranking_screen.dart, ranking_screen.dart,
   expanded_ranking_screen.dart, season_stats_screen.dart, history_screen.dart,
   blank_screen.dart.
3. Para cada tela ALCANÇÁVEL de ranking ou estatística: de onde vêm os dados (repositório,
   SharedPreferences ou ambos), em uma linha por tela.
Apenas fatos, com arquivo e número de linha. Não proponha mudanças.
```

---

### T0g · Remover telas inalcançáveis (parte da Fase 0) — AG
Branch: `chore/remove-unreachable-screens` · Revisão: não · **Só rodar se o Enzo confirmar** (pergunta em aberto 3) · Pode rodar antes ou depois da T1; precisa estar pronta antes da T3e

```
[cabeçalho]
Conforme docs/CODIGO_MORTO.md, estas telas não são abertas por nenhuma rota ou botão:
lib/screens/expanded_ranking_screen.dart, group_ranking_screen.dart, tournament_screen.dart
e blank_screen.dart (esta só é aberta por tournament_screen).
1) Confirme com grep em lib/ e test/ que continuam sem uso. Se houver uso, NÃO apague e
   registre em docs/DUVIDAS.md.
2) Apague os 4 arquivos, o import não utilizado em lib/main.dart (~linha 5) e quaisquer
   imports que ficarem sem uso.
3) Widgets, utils ou constantes que ficarem sem NENHUM uso depois disso: NÃO apague; liste-os
   em docs/DUVIDAS.md.
Aceite: flutter analyze sem erros novos e flutter test ok;
`grep -rnw "ExpandedRankingScreen\|GroupRankingScreen\|TournamentScreen\|BlankScreen" lib test`
retorna nada; checklist manual itens 1 a 4.
```

---

## FASE 1 — Interfaces (o app personal continua idêntico)

### T1 · Criar as interfaces de repositório — AG, revisão CLAUDE
Branch: `refactor/domain-interfaces` · T0e concluída (o `docs/CODIGO_MORTO.md` já existe)

```
[cabeçalho]
Crie classes abstratas em lib/domain/repositories/ (um arquivo por interface, nome em
snake_case, ex.: players_repository.dart) seguindo EXATAMENTE a seção 4 do
docs/ARCHITECTURE.md:
GroupsRepository, SeasonsRepository, SessionsRepository, MatchesRepository,
SessionArrivalsRepository, PlayersRepository,
PlayerAccountRepository, MembershipRepository,
ActionLogsRepository.
Copie as assinaturas públicas dos repositórios atuais em lib/repositories/
(mesmos nomes, parâmetros, valores padrão e tipos de retorno). Distribua os métodos
entre as interfaces conforme o mapa da seção 4. Não inclua isCurrentUserAdmin em
MembershipRepository. Em SessionsRepository adicione:
  Future<Map<String, dynamic>?> getRuntimeState(String sessionId);
Crie também lib/domain/services/auth_service.dart e permission_service.dart com as
assinaturas da seção 4.3 (e a classe AppAuthException(String message)).
Regras novas (vieram dos inventários):
- Leia docs/CODIGO_MORTO.md (já existe na main). Método marcado "0 CHAMADORES" NÃO entra em
  nenhuma interface. Não apague
  esses métodos das classes atuais; só não os liste nas interfaces e anote em docs/DUVIDAS.md.
  LISTA EXATA do que ENTRA em cada interface (nada a mais, nada a menos):
    GroupsRepository: getMyGroups, createGroup, updateGroup, deleteGroup
    SeasonsRepository: getSeasons, getCurrentSeason, createSeason, updateSeason, deleteSeason
    SessionsRepository: getCachedSession, getSessionById, getSessionsByGroup, createSession,
      updateSession, updateRuntimeState, deleteSession + getRuntimeState (novo)
    MatchesRepository: getMatchesBySession, getMatchesByGroup, savePendingMatch,
      updatePartialMatch, deleteMatch
    SessionArrivalsRepository: getArrivals, getPlayerIdsBySessions, replaceArrivals
    PlayersRepository: getPlayersByGroup, createGhostPlayer, updatePlayer, setPlayerIcon,
      setGoalSound, removePlayerFromGroup, getPlayerById, setNameEffect,
      setMonthlyHighlight, setCommunityAttributes, setAdvancedStat
    PlayerAccountRepository: claimGhostProfiles, getMyPlayers
    MembershipRepository: getMembers, getMyMembership, promoteToAdmin, demoteToMember,
      findGroupByCode, requestToJoin, listPendingRequests, approveRequest, rejectRequest
    ActionLogsRepository: log
  NÃO crie GoalSoundRepository nem RatingsRepository (todos os métodos de Ratings têm 0
  chamadores; setGoalSound fica em PlayersRepository). isCurrentUserAdmin NÃO entra em
  nenhuma interface repositório (vai para PermissionService).
- Crie CustomBadgesRepository em lib/domain/repositories/custom_badges_repository.dart:
    Future<List<Map<String, dynamic>>> getCustomBadges(String groupId);
    Future<void> saveCustomBadges(String groupId, List<Map<String, dynamic>> badges);
  (hoje essa lista vive em SharedPreferences, chave custom_badges_<groupId>, usada em
  manage_badges_screen e player_detail).
- Crie MatchHistoryStore em lib/domain/repositories/match_history_store.dart:
    Future<List<Map<String, dynamic>>> readSession(String sessionId);
    Future<void> appendToSession(String sessionId, Map<String, dynamic> record);
  (hoje: SharedPreferences, chave match_history_<sessionId>). Só a interface: quem a usa
  será decidido na T3e.
Somente arquivos NOVOS: não altere nenhum arquivo existente nesta tarefa.
Aceite: flutter analyze ok; git diff main --stat mostra apenas arquivos novos em lib/domain/.
```

Revisão CLAUDE: o Enzo me manda o conteúdo de `lib/domain/` (só essa pasta).

### T2 · AuthService e PermissionService — AG, revisão CLAUDE (só o PermissionService)
Branch: `refactor/auth-permission` · Depende de T1

```
[cabeçalho]
1) Crie lib/data/supabase/supabase_auth_service.dart (implements AuthService) usando o
   cliente Supabase atual. Converta AuthException em AppAuthException(message) com a
   mesma mensagem que as telas mostram hoje.
2) Crie lib/data/supabase/supabase_permission_service.dart (implements PermissionService)
   movendo a lógica atual de GroupMembersRepository.isCurrentUserAdmin (creator_id do
   grupo OU role == 'admin'). requireAdmin lança a MESMA exceção e mensagem que os
   repositórios lançam hoje.
3) Substitua os usos diretos de auth:
   - lib/main.dart linhas ~68, 70, 589 (AuthGate e logout)
   - lib/screens/login_screen.dart linhas ~30, 35 (signUp/signInWithPassword) e o import
     de supabase_flutter
   - lib/screens/complete_profile_screen.dart linha ~94 (signOut)
   - supabase_config.dart: currentUser/currentUserId passam a vir do AuthService
4) Todo uso de isCurrentUserAdmin (repositórios e telas listados na seção 5 do
   inventário) passa a chamar PermissionService.isAdmin / requireAdmin. Nos
   repositórios, receba PermissionService no construtor.
5) Remova isCurrentUserAdmin de GroupMembersRepository.
Por enquanto o acesso aos serviços pode ser por um campo estático temporário em
SupabaseService (será substituído na T3b).
Aceite: flutter analyze e flutter test ok; grep "isCurrentUserAdmin" em lib/ retorna
nada; comportamento idêntico (checklist manual itens 1, 7 e 8).
```

Revisão CLAUDE: `supabase_permission_service.dart` + o diff de um repositório (ex.: `seasons_repository.dart`).

### T3a · Mover e renomear os repositórios Supabase — AG
Branch: `refactor/supabase-data-layer` · Depende de T1 e T2

```
[cabeçalho]
1) Mova (git mv) cada arquivo de lib/repositories/*_repository.dart para
   lib/data/supabase/ e renomeie a classe com prefixo Supabase
   (PlayersRepository -> SupabasePlayersRepository, etc.).
2) Cada classe passa a "implements" a(s) interface(s) de lib/domain/repositories/
   conforme o mapa da seção 4. SupabasePlayersRepository implementa
   PlayersRepository e PlayerAccountRepository;
   SupabaseGroupMembersRepository implementa MembershipRepository.
3) Implemente SessionsRepository.getRuntimeState com a consulta que hoje está em
   match_screen.dart linhas ~410-415 (mesmas colunas, mesmo comportamento).
4) Mova lib/config/supabase_config.dart para lib/data/supabase/supabase_config.dart.
5) Mova lib/services/cache_store.dart para lib/data/supabase/cache_store.dart (só os
   repositórios o usam). Mantenha o prefixo de chaves "cache:".
6) Atualize os imports. Não mude a lógica interna dos métodos (inclusive o uso de
   CacheStore como fallback e de PendingMatchQueue.readAll em _pendingMatches).
Aceite: flutter analyze ok; flutter test ok; app compila.
```

### T3b · AppServices no lugar do SupabaseService.instance — AG
Branch: `refactor/app-services` · Depende de T3a

```
[cabeçalho]
1) Crie lib/app/app_services.dart: uma classe que guarda as INTERFACES
   (groups, members, seasons, players, playerAccounts, sessions, matches,
   sessionArrivals, actionLogs, auth, permissions) e um acesso estático
   AppServices.instance (definido uma vez na inicialização). Deixe campos previstos mas
   ainda nulos/vazios para outbox, siteSync e diagnostics (serão preenchidos na T3c e T3d).
2) Crie lib/bootstrap_personal.dart que inicializa o Supabase (o que hoje está em
   SupabaseConfig/ main) e monta o AppServices com as implementações Supabase*.
3) Crie lib/main_personal.dart chamando o bootstrap e rodando o app. lib/main.dart
   passa a apenas chamar main_personal.
4) Substitua em TODO o código fora de lib/data/supabase/ os usos de
   SupabaseService.instance.* por AppServices.instance.* (tipados pelas interfaces).
   Isso inclui lib/services/pending_match_queue.dart (que chama
   SupabaseService.instance.matches).
5) Apague lib/repositories/supabase_service.dart e a pasta lib/repositories/ se vazia.
Aceite: flutter analyze ok; flutter test ok; a verificação de isolamento do Supabase
(seção 2, regra 2 do ARCHITECTURE.md) imprime apenas os serviços que a T3c e a T3d vão tratar
(sync_service, cache_sync_manager e, se a T0b ainda não foi feita, data_migration_service e
fix_event_times_service); checklist manual completo.
```

### T3c · SiteSyncService e DiagnosticsService — AG
Branch: `refactor/site-sync-diagnostics` · Depende de T3b · Pode rodar em paralelo com a T3d

Contexto: `sync_service` e `cache_sync_manager` **não** são a proteção contra queda de internet. Servem para (a) enviar o "pacote do site" para `sync_data` em segundo plano e (b) o painel de debug do admin.

```
[cabeçalho]
1) Crie lib/domain/services/site_sync_service.dart com a interface
   SiteSyncService { Future<String> getOrCreateSyncCode();
                     Future<void> exportDataToSupabase(String syncCode); }
   Mova o que restou de lib/services/sync_service.dart para
   lib/data/supabase/supabase_site_sync_service.dart (class SupabaseSiteSyncService
   implements SiteSyncService), levando junto o SiteDataGenerator se ele só serve a isso.
2) Crie lib/domain/services/diagnostics_service.dart com a interface DiagnosticsService,
   expondo os métodos públicos de CacheSyncManager (markDirty, recordCloudSyncSuccess,
   recordCloudFetchSuccess, testSupabaseConnection, getStatus, getDebugStorageDump), e
   mova a classe CacheSyncStatus para esse arquivo. Mova a implementação para
   lib/data/supabase/supabase_diagnostics_service.dart. SupabaseSiteSyncService usa
   DiagnosticsService nas chamadas record*.
3) Registre ambos no AppServices como siteSync e diagnostics (nuláveis).
4) match_screen (_triggerBackgroundSync e _scheduleSiteSync) e admin_debug_screen passam a
   usar AppServices.instance.siteSync / diagnostics. Nulo = recurso desligado (não faz nada
   ou esconde o item).
5) NÃO altere chaves de SharedPreferences: my_sync_code, cache_has_pending_cloud_sync,
   cache_last_cloud_sync_at, cache_last_cloud_fetch_at.
Aceite: analyze/test ok; a verificação de isolamento não lista mais sync_service nem
cache_sync_manager; checklist manual completo, incluindo abrir o painel de debug do admin
e tocar "TESTAR CONEXÃO AGORA".
```

### T3d · MatchOutbox (a fila de envio) — AG, revisão CLAUDE
Branch: `refactor/match-outbox` · Depende de T3b · **Teste extra do Enzo obrigatório (modo avião)**

```
[cabeçalho]
Objetivo: abstrair a fila de envio de partidas (PendingMatchQueue), que protege contra
queda de internet. O COMPORTAMENTO deve ficar idêntico.
1) Crie lib/domain/services/match_outbox.dart:
     abstract class MatchOutbox {
       ValueListenable<int> get pending;
       ValueListenable<String?> get lastError;
       Future<void> enqueue(Map<String, dynamic> job);
       Future<void> flush();
     }
2) Mova PendingMatchQueue para lib/data/supabase/supabase_match_outbox.dart
   (class SupabaseMatchOutbox implements MatchOutbox). PRESERVE: chave
   'pending_matches_v1', formato do job, backoff 5/10/20/40/60s, timeout de 25s,
   reenvio ao voltar do background e demais gatilhos. O método estático readAll continua
   existindo e é usado por SupabaseMatchesRepository (mesma camada).
3) Registre no AppServices como outbox. Em match_screen (linhas ~129, 605, 1705, 3418, 3660,
   3676, 3678, 3690), troque PendingMatchQueue.instance por AppServices.instance.outbox.
4) Evite a dependência circular: SupabaseMatchOutbox recebe por construtor a implementação
   de savePendingMatch (SupabaseMatchesRepository), em vez de buscar em um singleton.
5) Registre em docs/DUVIDAS.md qualquer outro ponto que enfileire/reenvie partidas.
Aceite: analyze/test ok; checklist manual completo; teste do modo avião (item 9 do checklist).
```

Revisão CLAUDE: `supabase_match_outbox.dart` (o diff completo dele; é crítico para não perder partidas).

### T3e · Histórico de partidas e insígnias via interfaces — AG, revisão CLAUDE
Branch: `refactor/local-only-data` · Depende de T3b e da T0g · **Prompt detalhado: eu escrevo depois da T1**

Objetivo: telas e cálculos deixam de ler `match_history_*` e `custom_badges_*` direto do `SharedPreferences` e passam a usar `MatchHistoryStore` e `CustomBadgesRepository` (implementação do personal = SharedPreferences, **comportamento idêntico**). A T0e confirmou que `GroupRankingScreen` é inalcançável (removida na T0g). Ainda leem `match_history_*`: `RankingScreen` (fallback), `MatchScreen` (fallback e gravação), `PlayerDetail` e `getAllGroupMatches` (usado por `PlayerComparisonScreen`). Leem `custom_badges_*`: `ManageBadgesScreen` e `PlayerDetail`. As chaves legadas (`sessions_*`, `seasons_*`, `app_groups`, `players_grupo_`) ficam sem leitores depois da T0g e podem ser limpas aqui. Antes de refatorar, escreva o teste de caracterização de `getAllGroupMatches` usando repositórios falsos (via `AppServices`): hoje ele não tem teste (DUVIDAS.md item 3).

### T4 · AppFeatures e flavor personal — AG
Branch: `feat/app-features` · Depende de T3c, T3d e T3e

```
[cabeçalho]
1) Crie lib/app/app_features.dart com as flags da seção 5 do ARCHITECTURE.md
   (hasAuth, hasMembershipManagement, hasCosmetics, hasGoalSounds, hasAuditLog,
   hasSiteSync, hasCloudDraftSync, hasAdminDebug, hasDbExportImport, isReadOnly)
   e a configuração "personal" (como na coluna personal).
2) Registre em AppServices.
3) Nas telas, a visibilidade de recursos passa a ser: AppFeatures permite E
   PermissionService.isAdmin (quando aplicável) E !isReadOnly. Cobrir: engrenagem do
   GroupDashboardScreen (ManageJoinRequests, ManageMembers, ManageBadges, ManageSeasons,
   AdminDebug), FAB de SessionsScreen e PlayersScreen, opções de cosméticos/atributos no
   PlayerDetail e ManageBadgesScreen, upload de som de gol, tela de login/AuthGate (hasAuth).
4) Em match_screen, condicione por flag: o envio do pacote do site
   (_scheduleSiteSync/_triggerBackgroundSync -> hasSiteSync), o rascunho em nuvem
   (_scheduleCloudSync e a restauração remota do _loadMatchState -> hasCloudDraftSync).
No personal tudo continua aparecendo e funcionando exatamente como hoje.
Aceite: analyze/test ok; checklist manual completo (inclui item 9, modo avião).
```

**Gate:** Enzo roda o checklist manual no celular → merge na `main` → me avisa. A partir daqui eu entrego os prompts detalhados das Fases 2 e 3.

---

## FASE 2 — Site somente leitura (iPhone), link sem login  ·  *detalhar depois do gate*

Decisão tomada: **link secreto, sem login**. Segurança por token + funções no banco, e não por leitura pública das tabelas (a chave `anon` fica embutida no site).

| # | Tarefa | Quem |
|---|---|---|
| T5 | Proteger `dart:io`/`path_provider`/`screenshot`/`share_plus` nas 3 telas de ranking/histórico (import condicional ou `kIsWeb`); `main_web.dart` com `isReadOnly = true`; esconder todo recurso de escrita | AG |
| T6 | Token por grupo (`share_token`) + funções `SECURITY DEFINER` que devolvem só os dados daquele grupo (sem e-mail de jogadores, sem logs de admin); `anon` sem `SELECT` direto nas tabelas; como girar/revogar o token | **CLAUDE** |
| T6b | Repositórios "somente leitura via token" (implementam as interfaces de leitura) e `AuthService` nulo | **CLAUDE** (interfaces) + AG (tela) |
| T7 | Build web, hospedagem e checagem no Safari do iPhone | AG |
| T7b | **Aposentar o site antigo:** depois que o site novo estiver no ar e o grupo já estiver usando, remover `SiteSyncService`, `SiteDataGenerator`, `hasSiteSync`, `_scheduleSiteSync`/`_triggerBackgroundSync` do `match_screen` e o `my_sync_code`; desligar o site React; (opcional) apagar a tabela `sync_data` no Supabase | AG (código) + Enzo (desligar o site e a tabela) |

## FASE 3 — App público offline (1 grupo)  ·  *detalhar depois do gate*

| # | Tarefa | Quem |
|---|---|---|
| T8 | Schema drift + `schemaVersion` + migrações | **CLAUDE** |
| T9 | Repositórios locais simples (CRUD) seguindo o modelo que eu entregar | AG |
| T10 | Repositórios locais com transação (`createGroup`, `saveFullMatch`, `updateFullMatch`, `updatePartialMatch`, `deleteMatch`, `savePendingMatch`, `replaceArrivals`, `createGhostPlayer`) + `LocalMatchOutbox` (grava direto, `pending` sempre 0) | **CLAUDE** |
| T11 | Exportar/importar `.db` (`VACUUM INTO`, `integrity_check`, backup antes de importar) | **CLAUDE** |
| T12 | `bootstrap_public.dart`, `main_public.dart`, auth local fixo, grupo e temporada criados no primeiro uso | AG |
| T13 | Tema neutro, nome, ícone, flags do public desligando recursos do personal | AG |
| T14 | Implementar no SQLite: tabela `custom_badges`, `MatchHistoryStore` derivado das tabelas (convertendo para o formato da súmula local), e limpar `players_*`/`cache:*` depois de importar um `.db` (decisões na seção 10 do ARCHITECTURE) | **CLAUDE** |
| T15 | Build Android do app público (assinatura, ícone, nome) | AG |

---

## Decisões já tomadas

- Site antigo (React, lê `sync_data`): será trocado pelo site novo. O site novo **não** usa `sync_data`: lê os dados reais por funções com token (T6). Os dois convivem até a T7b.
- `data_migration_service` e `fix_event_times_service`: não usados → T0b.
- Web somente leitura: link sem login (token). Login por e-mail pode ser acrescentado depois sem refazer a arquitetura.
- App público: **um grupo só** por enquanto; migrar para vários depois.
- `sync_service`/`cache_sync_manager`: não são a proteção offline; viram `SiteSyncService` e `DiagnosticsService` (T3c). A proteção offline é a fila, o cache, o estado local da partida e o snapshot do elenco (T3d e seção 9 do `ARCHITECTURE.md`).

## Perguntas em aberto

1. ~~Site antigo em React~~ **Resolvido:** será substituído pelo site novo. Até lá o envio do pacote do site continua funcionando como hoje (T3c o mantém) e é removido na T7b.
2. ~~Resultado do inventário (T0d)~~ **Recebido** (ver seção 10 do ARCHITECTURE). Pergunta que ficou: as insígnias personalizadas (`custom_badges_*`, que existem só no aparelho) são criadas só por você, ou outros admins também criam?
3. Posso apagar as 4 telas inalcançáveis (`expanded_ranking_screen`, `group_ranking_screen`, `tournament_screen`, `blank_screen`; T0g)? E o `RatingsRepository` inteiro está sem uso: se o gráfico de evolução do redesign for usar `rating_history`, avise; senão ele fica fora do SQLite e pode ser apagado depois.
