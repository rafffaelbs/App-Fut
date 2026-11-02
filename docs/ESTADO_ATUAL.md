# ESTADO_ATUAL.md — Levantamento do Estado Atual do Código

> **Data do levantamento:** 02/11/2026  
> **Branch analisada:** `main`  
> **Modo de execução:** Somente leitura (inspeção estática e caracterização, sem alterações de lógica ou comportamento).

---

## 1. Git

### 1.1 `git log main --oneline | head -40`

```text
ea08813 feat: novas estatisticas
cce55c0 fix(screens): alinhar acoes de escrita com main e documentar em DUVIDAS.md #19
9b5fe6a style(manage_badges_screen): restaurar const em SizedBox(height: 12)
889fd7b fix(screens): trocar canAdminister por isReadOnly em trofeus de manage_badges_screen
1d67ac6 feat(screens): condicionar acoes de escrita sem admin a isReadOnly e documentar em DUVIDAS.md
d6cbbb6 feat(screens): aplicar feature flags e canAdminister nas condicoes de exibicao das telas
0c5ece2 feat(app): criar AppFeatures com flags do ARCHITECTURE e registrar no AppServices
6dcf0b8 fix(prefs): preservar semântica de containsKey com hasSession e hasCustomBadges
8b07125 refactor(screens): usar MatchHistoryStore e CustomBadgesRepository via AppServices
1431c0d feat(prefs): implementar PrefsMatchHistoryStore e PrefsCustomBadgesRepository
99fe2bf test(utils): adicionar testes de caracterização para getAllGroupMatches
cad0bb6 refactor(utils): tornar getAllGroupMatches testável com injeção de dependências
bb9b245 docs: atualização Plano de ação e arquitetura
a95275d docs: registrar item 15 sobre teste de conexão do admin_debug em DUVIDAS.md
38752d4 test(data): adicionar testes unitários para SupabaseDiagnosticsService e SupabaseSiteSyncService
9848dfe refactor(screens): usar AppServices para siteSync e diagnostics em match_screen e admin_debug_screen
4c45a67 refactor(app): registrar siteSync e diagnostics no AppServices e bootstrap_personal
a1dd8c2 feat(data): implementar SiteSyncService e DiagnosticsService no Supabase
bd2c181 docs: registrar item 14 sobre gatilhos da fila de envio em DUVIDAS.md
72bb29f test: adicionar testes unitários para SupabaseMatchOutbox
74f7d21 refactor(screens): trocar PendingMatchQueue por AppServices.instance.outbox em match_screen
b6afcbb refactor(app): registrar outbox no AppServices e bootstrap_personal
8b16fab feat(data): implementar SupabaseMatchOutbox e atualizar MatchesRepository
786940d feat(domain): criar interface MatchOutbox
734a74a refactor: trocar SupabaseService por AppServices e remover supabase_service.dart
72fe782 refactor: criar AppServices, bootstrap_personal e main_personal
38ba43f docs: atualizar checklist da tarefa T3a em TASKS.md
cc15135 refactor: integrar SupabaseService e match_screen com novos repositórios e getRuntimeState
2e9c405 refactor: renomear repositórios com prefixo Supabase e implementar interfaces de domínio
c9e1be9 refactor: mover supabase_config e cache_store para lib/data/supabase
158281f chore: remover telas inalcançáveis (T0g)
b24711f Merge branch 'refactor/auth-permission'
f737721 feat: campo tatical_pitch horizontal por padrao e nova tela de configuracoes
e8b5be1 docs: adiciona backlog
d78d62a refactor(auth): adicionar currentUserEmail em AuthService e remover getter currentUser
2f19a3a refactor(permissions): desacoplar PermissionDataSource e testar SupabasePermissionService real
efd9c77 refactor(permissions): migrar telas para PermissionService.isAdmin
3403c88 refactor(permissions): injetar PermissionService e remover isCurrentUserAdmin dos repositorios
3fa80cb refactor(auth): substituir chamadas diretas de auth por AuthService
026aaab feat(services): expor auth e permissions em SupabaseService e SupabaseConfig
```

### 1.2 Branches integradas (`git branch --merged main`)

- **Local:** `* main`
- **Remotas integradas:**
  - `origin/HEAD -> origin/main`
  - `origin/feature/calibracao-sofascore`
  - `origin/fixed_goalkeeper`
  - `origin/fluid_goalkeeper`
  - `origin/main`
  - `origin/migration`

Todas as branches de trabalho conhecidas estão totalmente integradas na `main`.

### 1.3 Confirmação dos commits da Tarefa T4

Os 3 commits da Tarefa T4 estão confirmados e presentes na `main`:
1. `889fd7b`: `fix(screens): trocar canAdminister por isReadOnly em trofeus de manage_badges_screen`
2. `9b5fe6a`: `style(manage_badges_screen): restaurar const em SizedBox(height: 12)`
3. `cce55c0`: `fix(screens): alinhar acoes de escrita com main e documentar em DUVIDAS.md #19`

Eles antecedem diretamente o commit `ea08813` (`feat: novas estatisticas`).

---

## 2. Estrutura de `lib/`

Estrutura completa das pastas e arquivos de `lib/` (uma linha cada):

- `lib/`
  - `lib/main.dart`: Ponto de entrada de compatibilidade que repassa a execução para `mainPersonal()`.
  - `lib/main_personal.dart`: Ponto de entrada do app personal, login, listagem e seleção de grupos.
  - `lib/bootstrap_personal.dart`: Inicialização do cliente Supabase e instanciação de `AppServices.instance`.
- `lib/app/`
  - `lib/app/app_features.dart`: Definição da classe `AppFeatures` e do perfil `AppFeatures.personal()`.
  - `lib/app/app_services.dart`: Container global de injeção de dependências contendo as interfaces do domínio.
- `lib/constants/`
  - `lib/constants/app_colors.dart`: Paleta de cores oficial do app (tema escuro Blue Lock).
  - `lib/constants/cosmetic_effects.dart`: Definições visuais de efeitos cosméticos (brilhos, auras, cores).
- `lib/data/prefs/`
  - `lib/data/prefs/prefs_custom_badges_repository.dart`: Persistência de insígnias customizadas em `SharedPreferences`.
  - `lib/data/prefs/prefs_match_history_store.dart`: Persistência do histórico local de partidas em `SharedPreferences`.
- `lib/data/supabase/`
  - `lib/data/supabase/action_logs_repository.dart`: Gravação de logs de auditoria administrativa no Supabase.
  - `lib/data/supabase/cache_store.dart`: Cache read-through genérico baseado em SharedPreferences para dados de rede.
  - `lib/data/supabase/group_members_repository.dart`: Repositório de membros, papéis de admin e solicitações de entrada.
  - `lib/data/supabase/groups_repository.dart`: Criação, consulta e edição de grupos no Supabase.
  - `lib/data/supabase/matches_repository.dart`: Repositório de partidas, escalações e eventos de jogo.
  - `lib/data/supabase/players_repository.dart`: Repositório de atletas, contas de usuário e atributos de comunidade.
  - `lib/data/supabase/ratings_repository.dart`: Repositório legado de notas (sem interface ativa).
  - `lib/data/supabase/seasons_repository.dart`: Gestão de temporadas ativas e arquivadas no Supabase.
  - `lib/data/supabase/session_arrivals_repository.dart`: Gestão da lista de presença/chegada de atletas nas peladas.
  - `lib/data/supabase/sessions_repository.dart`: Gestão de sessões de pelada e sincronização de estado em andamento.
  - `lib/data/supabase/site_data_generator.dart`: Geração do dump JSON consolidado para o site legado.
  - `lib/data/supabase/supabase_auth_service.dart`: Implementação do serviço de autenticação via Supabase Auth.
  - `lib/data/supabase/supabase_config.dart`: Ponto de inicialização do cliente Supabase e chaves de API.
  - `lib/data/supabase/supabase_diagnostics_service.dart`: Diagnóstico de latência, integridade e inspeção de cache.
  - `lib/data/supabase/supabase_match_outbox.dart`: Fila assíncrona com persistência local de partidas finalizadas.
  - `lib/data/supabase/supabase_permission_service.dart`: Verificação de privilégios de administrador de grupo.
  - `lib/data/supabase/supabase_site_sync_service.dart`: Sincronização periódica do pacote do site com a tabela `sync_data`.
- `lib/domain/repositories/`
  - `lib/domain/repositories/action_logs_repository.dart`: Interface para log de ações administrativas.
  - `lib/domain/repositories/custom_badges_repository.dart`: Interface para insígnias customizadas do grupo.
  - `lib/domain/repositories/groups_repository.dart`: Interface para CRUD de grupos.
  - `lib/domain/repositories/matches_repository.dart`: Interface para persistência e consulta de partidas.
  - `lib/domain/repositories/match_history_store.dart`: Interface para gravação da súmula local de partidas da sessão.
  - `lib/domain/repositories/membership_repository.dart`: Interface para membros, convites e moderação.
  - `lib/domain/repositories/player_account_repository.dart`: Interface para vínculo de perfis com contas de usuário.
  - `lib/domain/repositories/players_repository.dart`: Interface para operações sobre jogadores do grupo.
  - `lib/domain/repositories/seasons_repository.dart`: Interface para controle de temporadas.
  - `lib/domain/repositories/session_arrivals_repository.dart`: Interface para registros de presença.
  - `lib/domain/repositories/sessions_repository.dart`: Interface para controle de sessões de pelada.
- `lib/domain/services/`
  - `lib/domain/services/auth_service.dart`: Interface de controle de autenticação e sessão de usuário.
  - `lib/domain/services/diagnostics_service.dart`: Interface de diagnóstico de conectividade e status de cache.
  - `lib/domain/services/match_outbox.dart`: Interface da fila de envio de partidas finalizadas.
  - `lib/domain/services/permission_service.dart`: Interface de verificação de permissão administrativa.
  - `lib/domain/services/site_sync_service.dart`: Interface para exportação periódica de dados para o site.
- `lib/models/`
  - `lib/models/cosmetic_effect.dart`: Modelo de representação de cosméticos visuais.
  - `lib/models/group_member_model.dart`: Modelo de vínculo entre usuário/atleta e grupo.
  - `lib/models/group_model.dart`: Modelo de dados de grupo.
  - `lib/models/match_event_model.dart`: Modelo de eventos ocorridos em partida (gols, assistências, cartões).
  - `lib/models/match_lineup_model.dart`: Modelo de escalações de times por partida.
  - `lib/models/match_model.dart`: Modelo de partida finalizada.
  - `lib/models/player_badge_model.dart`: Modelo de insígnia ou medalha associada a jogador.
  - `lib/models/player_model.dart`: Modelo de atleta com estatísticas e atributos.
  - `lib/models/player_stat_distribution.dart`: Modelo de distribuição estatística por categorias e itens (commit `ea08813`).
  - `lib/models/rating_history_model.dart`: Modelo de histórico de notas por partida.
  - `lib/models/season_model.dart`: Modelo de temporada.
  - `lib/models/session_model.dart`: Modelo de sessão de pelada.
- `lib/screens/`
  - `lib/screens/admin_debug_screen.dart`: Painel administrativo de teste de conexão e diagnóstico.
  - `lib/screens/complete_profile_screen.dart`: Tela inicial de definição de nome do perfil.
  - `lib/screens/draft_screen.dart`: Tela de escolha/sorteio de times da pelada.
  - `lib/screens/edit_match_screen.dart`: Tela de edição de súmula de partidas passadas.
  - `lib/screens/group_dashboard_screen.dart`: Painel central do grupo com navegação entre peladas, elenco e ranking.
  - `lib/screens/history_screen.dart`: Tela de listagem e detalhes do histórico de partidas de uma pelada.
  - `lib/screens/join_group_screen.dart`: Tela de solicitação de entrada em grupo via código de convite.
  - `lib/screens/login_screen.dart`: Tela de login e cadastro com e-mail e senha.
  - `lib/screens/manage_badges_screen.dart`: Gestão e concessão de insígnias e troféus aos atletas.
  - `lib/screens/manage_join_requests_screen.dart`: Moderação de pedidos de adesão ao grupo.
  - `lib/screens/manage_members_screen.dart`: Gestão de permissões de membros e promoção a admin.
  - `lib/screens/manage_seasons_screen.dart`: Criação, ativação e exclusão de temporadas.
  - `lib/screens/match_screen.dart`: Tela principal da partida em andamento (cronômetro, placar, fila de espera).
  - `lib/screens/player_comparison_screen.dart`: Tela de comparação estatística e gráfica entre dois atletas.
  - `lib/screens/player_detail.dart`: Tela de perfil completo, estatísticas avançadas e curiosidades do atleta.
  - `lib/screens/players_screen.dart`: Tela de visualização e adição de jogadores do elenco.
  - `lib/screens/ranking_screen.dart`: Tela de exibição dos rankings de pontuação, artilharia e notas.
  - `lib/screens/season_stats_screen.dart`: Painel consolidado de métricas da temporada inteira.
  - `lib/screens/sessions_screen.dart`: Tela de listagem de peladas com histórico e filtros.
  - `lib/screens/settings_screen.dart`: Tela de configurações gerais do grupo e do dispositivo.
  - `lib/screens/tournament_dashboard_screen.dart`: Painel de visualização de torneios.
- `lib/services/`
  - `lib/services/group_bootstrap.dart`: Serviço de carga rápida inicial do grupo e cache local do elenco.
- `lib/theme/`
  - `lib/theme/app_theme.dart`: Configuração do tema visual escuro com base em Material 3.
- `lib/utils/`
  - `lib/utils/bench_time_calculator.dart`: Lógica de cálculo do tempo de espera no banco.
  - `lib/utils/constants.dart`: Constantes globais do app (pontuações base, pesos e timeouts).
  - `lib/utils/cosmetic_resolver.dart`: Utilitário para montagem de cosméticos visuais.
  - `lib/utils/match_dialogs.dart`: Modais e caixas de diálogo auxiliares da partida.
  - `lib/utils/overall_calculator.dart`: Cálculo da força geral do atleta (Overall 0-99).
  - `lib/utils/pitch_layout.dart`: Coordenadas e proporções para desenho dos atletas no campo tático.
  - `lib/utils/player_identity.dart`: Utilitário de normalização de IDs de jogadores em estruturas variadas.
  - `lib/utils/rating_calculator.dart`: Algoritmo matemático de cálculo das notas individuais de linha e goleiro.
  - `lib/utils/roster_utils.dart`: Utilitários para ordenação e manipulação de listas de atletas.
  - `lib/utils/session_grouping.dart`: Agrupador de sessões por mês e por temporada.
  - `lib/utils/stats_board_utils.dart`: Utilitários visuais para as placas e cards de estatísticas.
  - `lib/utils/stats_calculator.dart`: Cálculo de estatísticas agregadas e consulta de histórico completo do grupo.
  - `lib/utils/tactical_formation.dart`: Definições táticas e posições dos jogadores em campo.
  - `lib/utils/team_balancer.dart`: Algoritmo de balanceamento de times por média de nota/overall.
- `lib/widgets/`
  - `lib/widgets/match/`: Widgets do módulo de partida (`arrival_swipe.dart`, `match_events_panel.dart`, `match_finish_confirmation_dialog.dart`, `match_pitch_player.dart`, `match_player_tile.dart`, `match_scoreboard.dart`, `player_field_slot.dart`, `tactical_pitch.dart`, `team_logo.dart`, `waiting_player_card.dart`, `waitlist_card.dart`).
  - `lib/widgets/player/`: Widgets de cartões de atletas (`fifa_card.dart`, `player_card.dart`).
  - `lib/widgets/session/`: Widgets do módulo de sessão (`session_delete_dialog.dart`, `session_form_sheet.dart`, `session_list_tile.dart`, `stacked_avatars.dart`).
  - `lib/widgets/shared/`: Componentes visuais compartilhados (`cosmetic_frame.dart`, `icon_picker_modal.dart`, `player_avatar_frame.dart`, `player_name_text.dart`, `ranking_player_bits.dart`, `stars_badge.dart`).
  - `lib/widgets/stats/`: Widgets de visualização de estatísticas (`duos_donut.dart`, `evolution_chart.dart`, `full_ranking_sheet.dart`, `player_picker_sheet.dart`, `player_stat_distribution_card.dart`, `stat_board_card.dart`, `stat_row.dart`).

---

## 3. Interfaces em `lib/domain/` e `AppServices`

### 3.1 Interfaces de Repositório (`lib/domain/repositories/`)

1. **`ActionLogsRepository`**
   - Implementação: `SupabaseActionLogsRepository` (`lib/data/supabase/action_logs_repository.dart:10`)
   - Métodos:
     - `Future<void> log({required String groupId, required String action, String? targetPlayerId, Map<String, dynamic> details = const {}})`

2. **`CustomBadgesRepository`**
   - Implementação: `PrefsCustomBadgesRepository` (`lib/data/prefs/prefs_custom_badges_repository.dart:9`)
   - Métodos:
     - `Future<bool> hasCustomBadges(String groupId)`
     - `Future<List<Map<String, dynamic>>> getCustomBadges(String groupId)`
     - `Future<void> saveCustomBadges(String groupId, List<Map<String, dynamic>> badges)`

3. **`GroupsRepository`**
   - Implementação: `SupabaseGroupsRepository` (`lib/data/supabase/groups_repository.dart:13`)
   - Métodos:
     - `Future<List<GroupModel>> getMyGroups()`
     - `Future<GroupModel> createGroup({required String name, String? adminPlayerName})`
     - `Future<GroupModel> updateGroup(GroupModel group)`
     - `Future<void> deleteGroup(String groupId)`

4. **`MatchesRepository`**
   - Implementação: `SupabaseMatchesRepository` (`lib/data/supabase/matches_repository.dart:12`)
   - Métodos:
     - `Future<List<MatchModel>> getMatchesBySession(String sessionId)`
     - `Future<List<MatchModel>> getMatchesByGroup(String groupId)`
     - `Future<void> savePendingMatch({required String matchId, required Map<String, dynamic> match, required List<Map<String, dynamic>> lineups, required List<Map<String, dynamic>> events, bool isRetry = false})`
     - `Future<MatchModel> updatePartialMatch({required String matchId, required int teamAScore, required int teamBScore, required List<MatchEventModel> events})`
     - `Future<void> deleteMatch(String matchId)`

5. **`MatchHistoryStore`**
   - Implementação: `PrefsMatchHistoryStore` (`lib/data/prefs/prefs_match_history_store.dart:9`)
   - Métodos:
     - `Future<bool> hasSession(String sessionId)`
     - `Future<List<Map<String, dynamic>>> readSession(String sessionId)`
     - `Future<void> appendToSession(String sessionId, Map<String, dynamic> record)`

6. **`MembershipRepository`**
   - Implementação: `SupabaseGroupMembersRepository` (`lib/data/supabase/group_members_repository.dart:11`)
   - Métodos:
     - `Future<List<GroupMemberModel>> getMembers(String groupId)`
     - `Future<GroupMemberModel?> getMyMembership(String groupId)`
     - `Future<void> promoteToAdmin({required String groupId, required String playerId})`
     - `Future<void> demoteToMember({required String groupId, required String playerId})`
     - `Future<GroupModel?> findGroupByCode(String code)`
     - `Future<void> requestToJoin({required String inviteCode, required String desiredName})`
     - `Future<List<Map<String, dynamic>>> listPendingRequests(String groupId)`
     - `Future<void> approveRequest(String requestId, {String? existingPlayerId})`
     - `Future<void> rejectRequest(String requestId)`

7. **`PlayerAccountRepository`**
   - Implementação: `SupabasePlayersRepository` (`lib/data/supabase/players_repository.dart:23`)
   - Métodos:
     - `Future<List<PlayerModel>> claimGhostProfiles()`
     - `Future<List<PlayerModel>> getMyPlayers()`

8. **`PlayersRepository`**
   - Implementação: `SupabasePlayersRepository` (`lib/data/supabase/players_repository.dart:23`)
   - Métodos:
     - `Future<List<PlayerModel>> getPlayersByGroup(String groupId)`
     - `Future<PlayerModel> createGhostPlayer({required String groupId, required String name, String? avatarUrl, List<PlayerBadgeModel> badges = const []})`
     - `Future<PlayerModel> updatePlayer(PlayerModel player)`
     - `Future<PlayerModel> setPlayerIcon({required String playerId, required String? iconPath})`
     - `Future<PlayerModel> setGoalSound({required String playerId, required String? audioFileName, String? groupId})`
     - `Future<void> removePlayerFromGroup({required String groupId, required String playerId})`
     - `Future<PlayerModel?> getPlayerById(String playerId)`
     - `Future<PlayerModel> setNameEffect({required String groupId, required String playerId, required String? effect})`
     - `Future<PlayerModel> setMonthlyHighlight({required String groupId, required String playerId, required bool value})`
     - `Future<PlayerModel> setCommunityAttributes({required String groupId, required String playerId, required CommunityAttributes attributes})`
     - `Future<PlayerModel> setAdvancedStat({required String groupId, required String playerId, required Map<String, dynamic> patch})`

9. **`SeasonsRepository`**
   - Implementação: `SupabaseSeasonsRepository` (`lib/data/supabase/seasons_repository.dart:9`)
   - Métodos:
     - `Future<List<SeasonModel>> getSeasons(String groupId)`
     - `Future<SeasonModel?> getCurrentSeason(String groupId)`
     - `Future<SeasonModel> createSeason({required String groupId, required String name, DateTime? startDate, DateTime? endDate, bool isActive = true})`
     - `Future<SeasonModel> updateSeason(SeasonModel season)`
     - `Future<void> deleteSeason({required String groupId, required String seasonId})`

10. **`SessionArrivalsRepository`**
    - Implementação: `SupabaseSessionArrivalsRepository` (`lib/data/supabase/session_arrivals_repository.dart:14`)
    - Métodos:
      - `Future<List<Map<String, dynamic>>> getArrivals(String sessionId)`
      - `Future<Map<String, List<String>>> getPlayerIdsBySessions(List<String> sessionIds)`
      - `Future<void> replaceArrivals(String sessionId, List<Map<String, dynamic>> players)`

11. **`SessionsRepository`**
    - Implementação: `SupabaseSessionsRepository` (`lib/data/supabase/sessions_repository.dart:8`)
    - Métodos:
      - `Future<SessionModel?> getCachedSession(String sessionId)`
      - `Future<SessionModel?> getSessionById(String sessionId)`
      - `Future<List<SessionModel>> getSessionsByGroup(String groupId)`
      - `Future<SessionModel> createSession(SessionModel session)`
      - `Future<SessionModel> updateSession(SessionModel session)`
      - `Future<void> updateRuntimeState(String sessionId, {bool? isRunning, int? secondsPlayed, int? scoreRed, int? scoreWhite, int? redStreak, int? whiteStreak, bool? isOvertime, DateTime? startedAt, String? status})`
      - `Future<void> deleteSession(String sessionId)`
      - `Future<Map<String, dynamic>?> getRuntimeState(String sessionId)`

### 3.2 Interfaces de Serviço (`lib/domain/services/`)

12. **`AuthService`**
    - Implementação: `SupabaseAuthService` (`lib/data/supabase/supabase_auth_service.dart:5`)
    - Métodos / Getters:
      - `String? get currentUserId`
      - `String? get currentUserEmail`
      - `bool get isSignedIn`
      - `Stream<bool> get signedInChanges`
      - `Future<void> signIn(String email, String password)`
      - `Future<void> signUp(String email, String password)`
      - `Future<void> signOut()`

13. **`DiagnosticsService`**
    - Implementação: `SupabaseDiagnosticsService` (`lib/data/supabase/supabase_diagnostics_service.dart:6`)
    - Métodos:
      - `Future<void> markDirty()`
      - `Future<void> recordCloudSyncSuccess()`
      - `Future<void> recordCloudFetchSuccess()`
      - `Future<Map<String, dynamic>> testSupabaseConnection()`
      - `Future<CacheSyncStatus> getStatus()`
      - `Future<Map<String, String>> getDebugStorageDump()`

14. **`MatchOutbox`**
    - Implementação: `SupabaseMatchOutbox` (`lib/data/supabase/supabase_match_outbox.dart:16`)
    - Métodos / Getters:
      - `ValueListenable<int> get pending`
      - `ValueListenable<String?> get lastError`
      - `Future<void> enqueue(Map<String, dynamic> job)`
      - `Future<void> flush()`

15. **`PermissionService`**
    - Implementação: `SupabasePermissionService` (`lib/data/supabase/supabase_permission_service.dart:42`)
    - Métodos:
      - `Future<bool> isAdmin(String groupId)`
      - `Future<void> requireAdmin(String groupId, [String? message])`

16. **`SiteSyncService`**
    - Implementação: `SupabaseSiteSyncService` (`lib/data/supabase/supabase_site_sync_service.dart:11`)
    - Métodos:
      - `Future<String> getOrCreateSyncCode()`
      - `Future<void> exportDataToSupabase(String syncCode)`

### 3.3 Campos de `AppServices` (`lib/app/app_services.dart`)

Todos os 17 campos da classe `AppServices`:

| Campo | Tipo | Descrição |
|---|---|---|
| `features` | `AppFeatures` | Conjunto de feature flags da variante em execução |
| `groups` | `GroupsRepository` | Operações CRUD e listagem de grupos |
| `members` | `MembershipRepository` | Gestão de membros, papéis e pedidos de entrada |
| `seasons` | `SeasonsRepository` | Controle de temporadas ativas e históricas |
| `players` | `PlayersRepository` | CRUD de jogadores, efeitos e atributos |
| `playerAccounts` | `PlayerAccountRepository` | Consulta de atletas vinculados à conta autenticada |
| `sessions` | `SessionsRepository` | Controle de peladas e sincronização de rascunho |
| `matches` | `MatchesRepository` | Consulta e gravação de partidas |
| `sessionArrivals` | `SessionArrivalsRepository` | Presença e fila de chegada da pelada |
| `actionLogs` | `ActionLogsRepository` | Log de auditoria de alterações administrativas |
| `auth` | `AuthService` | Gestão de autenticação do usuário |
| `permissions` | `PermissionService` | Checagem de permissão de administrador no grupo |
| `outbox` | `MatchOutbox` | Fila assíncrona local de envio de partidas finalizadas |
| `matchHistory` | `MatchHistoryStore` | Súmula local das partidas da sessão |
| `customBadges` | `CustomBadgesRepository` | Catálogo de insígnias customizadas |
| `siteSync` | `SiteSyncService?` | Exportação de pacote de dados para o site (opcional) |
| `diagnostics` | `DiagnosticsService?` | Diagnóstico de conexão e cache (opcional) |

---

## 4. `AppFeatures`: flags, valores e uso

Perfil verificado: `AppFeatures.personal()` (`lib/app/app_features.dart:55-69`).

| Flag | Valor em `personal()` | Arquivo e Linha onde é Usada |
|---|---|---|
| `hasAuth` | `true` | **Não usada** fora de `app_features.dart`. |
| `hasMembershipManagement` | `true` | - `lib/main_personal.dart:497` (item de menu "Entrar em grupo existente")<br>- `lib/main_personal.dart:574` (diálogo de inserção de código de convite)<br>- `lib/screens/settings_screen.dart:203` (opção "Gerenciar Membros")<br>- `lib/screens/settings_screen.dart:234` (opção "Solicitações de Entrada") |
| `hasCosmetics` | `true` | - `lib/screens/manage_badges_screen.dart:34` (`_canManageCosmetics`) |
| `hasGoalSounds` | `true` | - `lib/screens/manage_badges_screen.dart:36` (`_canManageSounds`)<br>- `lib/screens/player_detail.dart:1277` (guarda ao subir áudio)<br>- `lib/screens/player_detail.dart:1330` (guarda ao remover áudio)<br>- `lib/screens/player_detail.dart:3930` (renderização do botão de áudio de gol) |
| `hasAuditLog` | `true` | **Não usada** fora de `app_features.dart`. |
| `hasSiteSync` | `true` | - `lib/screens/match_screen.dart:136` (export inicial em `_loadInitialData`)<br>- `lib/screens/match_screen.dart:3662` (export após finalizar partida)<br>- `lib/screens/match_screen.dart:4004` (export após reset de sessão) |
| `hasCloudDraftSync` | `true` | - `lib/screens/match_screen.dart:269` (polling de runtime state)<br>- `lib/screens/match_screen.dart:378` (gravação remota do rascunho da partida) |
| `hasAdminDebug` | `true` | - `lib/screens/settings_screen.dart:187` (botão "Diagnóstico do Banco") |
| `hasDbExportImport` | `false` | **Não usada** fora de `app_features.dart`. |
| `isReadOnly` | `false` | - `lib/app/app_features.dart:52` (utilizada no método `canAdminister`)<br>- `lib/main_personal.dart:187, 313, 644, 677` (guard e visibilidade de criar/excluir grupo)<br>- `lib/screens/join_group_screen.dart:21, 106` (guard e botão de solicitar entrada)<br>- `lib/screens/edit_match_screen.dart:406, 500` (guard e botão salvar edição de partida)<br>- `lib/screens/manage_badges_screen.dart:1154, 1558, 1667, 1737` (ações de insígnias)<br>- `lib/screens/match_screen.dart:1049, 3364` (guard e botão de finalizar pelada)<br>- `lib/screens/history_screen.dart:168, 191, 263, 327` (editar/excluir partida e histórico)<br>- `lib/screens/player_detail.dart:62, 1208, 1851, 3896` (edição de perfil e foto) |

### Helper `canAdminister(bool isAdmin)`
- Definição: `lib/app/app_features.dart:52`: `bool canAdminister(bool isAdmin) => !isReadOnly && isAdmin;`
- Locais de uso:
  - `lib/screens/manage_members_screen.dart:55, 154`
  - `lib/screens/settings_screen.dart:151`
  - `lib/screens/group_dashboard_screen.dart:120`
  - `lib/screens/players_screen.dart:49, 438, 462, 497, 798`
  - `lib/screens/manage_badges_screen.dart:32, 34, 36`
  - `lib/screens/sessions_screen.dart:25, 165, 166, 213`
  - `lib/screens/manage_seasons_screen.dart:19, 40, 201, 314, 335`
  - `lib/screens/manage_join_requests_screen.dart:20, 45, 79, 100, 239`
  - `lib/screens/player_detail.dart:58, 61, 1599, 2204, 2845, 2982, 3530, 3918`

### Flags não usadas hoje no código
- `hasAuth` (a autenticação no personal está ativa diretamente por `AppServices.instance.auth` em `main_personal.dart`).
- `hasAuditLog` (a gravação de auditoria em `action_logs` está diretamente injetada no repositório de jogadores).
- `hasDbExportImport` (prevista para o flavor público offline com SQLite).

---

## 5. Diferenças entre `docs/ARCHITECTURE.md` e o Código Atual

1. **Estado de Execução das Tarefas da Fase 1 (T1 a T4):**
   - O documento trata as tarefas T1, T2, T3a, T3b, T3c, T3d, T3e e T4 como passos futuros ou em planejamento.
   - No código atual, todas essas tarefas foram completamente implementadas, testadas e mescladas na `main`.

2. **Novos métodos nas interfaces criadas na T3e:**
   - `MatchHistoryStore`: o documento descreve apenas `readSession` e `appendToSession`. A interface real possui também `hasSession(String sessionId)` (necessária para preservar a semântica de `containsKey` do `SharedPreferences`, commit `6dcf0b8`).
   - `CustomBadgesRepository`: o documento descreve apenas `getCustomBadges` e `saveCustomBadges`. A interface real possui também `hasCustomBadges(String groupId)` (pelo mesmo motivo, commit `6dcf0b8`).
   - `ActionLogsRepository`: o documento cita apenas o método `log`. A interface em Dart também padroniza constantes públicas de log (`actionBadgeGrant`, `actionRoleChange`, etc.).

3. **Helper `canAdminister` em `AppFeatures`:**
   - O documento prevê em texto corrido (seção 5): *"tela de admin/engrenagem/edição aparece se AppFeatures permitir e PermissionService.isAdmin for true (e isReadOnly for false)"*.
   - No código, essa regra foi formalizada como método de instância `bool canAdminister(bool isAdmin) => !isReadOnly && isAdmin;` em `AppFeatures` e consumida em 9 telas.

4. **Enumeração dos campos de `AppServices`:**
   - O documento menciona `AppServices` substituindo `SupabaseService.instance`, mas não lista a tabela completa de seus 17 membros (incluindo `features`, `outbox`, `matchHistory`, `customBadges`, `siteSync`, `diagnostics`).

5. **Pasta `lib/config/` inexistente:**
   - A seção 3 do documento cita `(config, constants, models, screens, utils, widgets: como estão)`.
   - No código, não existe pasta `lib/config/`. O arquivo `supabase_config.dart` foi movido para `lib/data/supabase/supabase_config.dart`.

6. **Leituras diretas de `SharedPreferences` em `stats_calculator` e `site_data_generator`:**
   - O documento (seção 2, regra 4) afirmava: *"stats_calculator.dart (~linhas 100-124) e site_data_generator.dart leem SharedPreferences direto... tratar na T3e"*.
   - Na T3e, a função `getAllGroupMatches` foi parametrizada e passou a suportar injeção, mas o corpo legado de `stats_calculator.dart` (linhas 106-120) e `site_data_generator.dart` (linhas 35-43) ainda realiza leituras diretas em `SharedPreferences` para chaves legadas (`sessions_*`, `seasons_*`).

7. **Novas telas e componentes pós-refatoração (commit `ea08813`):**
   - O commit recente `ea08813` introduziu a funcionalidade de distribuição estatística (`PlayerStatDistribution`, `PlayerStatDistributionCard`, `lib/models/player_stat_distribution.dart`, `lib/widgets/stats/player_stat_distribution_card.dart`), que não consta no `ARCHITECTURE.md`.

---

## 6. Resultados de Verificação Automatizada

### 6.1 `flutter analyze`
- **Total de issues:** 270 issues encontradas
  - **Erros:** 0
  - **Avisos (warnings):** 14 (variáveis e funções não utilizadas herdadas do código legado)
  - **Informativos (infos):** 256 (estilos de bloco, `withOpacity` depreciado, convenções de documentação)
- O código compila sem nenhum erro estático.

### 6.2 `flutter test`
- **Total de testes:** 162 testes
- **Resultado:** 162 passaram, 0 falhas (`All tests passed!`).

### 6.3 Grep de Isolamento do `supabase_flutter`

Comando de verificação oficial do `ARCHITECTURE.md`:
```bash
grep -rl "supabase_flutter" lib | grep -v "^lib/data/supabase/" | grep -v "^lib/bootstrap_personal.dart"
```
- **Saída:** Vazio (0 arquivos).
- **Detalhamento:** Todos os 14 arquivos que importam `supabase_flutter` residem estritamente em `lib/data/supabase/`:
  - `lib/data/supabase/action_logs_repository.dart`
  - `lib/data/supabase/group_members_repository.dart`
  - `lib/data/supabase/groups_repository.dart`
  - `lib/data/supabase/matches_repository.dart`
  - `lib/data/supabase/players_repository.dart`
  - `lib/data/supabase/ratings_repository.dart`
  - `lib/data/supabase/seasons_repository.dart`
  - `lib/data/supabase/session_arrivals_repository.dart`
  - `lib/data/supabase/sessions_repository.dart`
  - `lib/data/supabase/supabase_auth_service.dart`
  - `lib/data/supabase/supabase_config.dart`
  - `lib/data/supabase/supabase_diagnostics_service.dart`
  - `lib/data/supabase/supabase_permission_service.dart`
  - `lib/data/supabase/supabase_site_sync_service.dart`

Nenhum arquivo em `lib/domain/`, `lib/screens/`, `lib/widgets/`, `lib/utils/` ou `lib/app/` importa o pacote `supabase_flutter`.

---

## 7. Investigação dos Bugs de `docs/BACKLOG.md` (Seção 0)

> Investigação estritamente baseada em leitura de código e histórico do repositório, **sem alterações na implementação**.

### 7.1 Bug B1: Falha ao criar grupo (temporada nula e grupos órfãos)

#### Fluxo completo
1. **Tela:** Em `lib/main_personal.dart:275-279`, o usuário toca no botão "CRIAR GRUPO". O app invoca `await AppServices.instance.groups.createGroup(...)`.
2. **Repositório:** O método `createGroup` é executado em `lib/data/supabase/groups_repository.dart:77-141`:
   - Passo 1: Executa `insert` na tabela `groups` com ID `'grupo_${DateTime.now().millisecondsSinceEpoch}'` e código de convite. **O grupo é gravado com sucesso no Supabase.**
   - Passo 2: Executa `select` / `insert` na tabela `players` gerando ID com `const Uuid().v4()` caso o criador não tenha atleta vinculado.
   - Passo 3: Executa `insert` na tabela `group_members` associando o criador como `admin`.
   - Passo 4: Executa `insert` na tabela `seasons`:
     ```dart
     await _client.from('seasons').insert({
       'group_id': group.id,
       'name': 'Temporada 1',
       'is_active': true,
     });
     ```
3. **Causa da falha:**
   - Na tabela `seasons` do PostgreSQL/Supabase, a coluna `id` possui restrição `NOT NULL` e **não possui gerador de valor default** (`DEFAULT gen_random_uuid()`).
   - Como o payload Dart não envia a chave `'id'`, o Postgres acusa violação:  
     `PostgrestException: null value in column "id" of relation "seasons" violates not-null constraint (23502)`.
   - Como as operações REST não estão agrupadas em transação atômica, o passo 1 já foi confirmado no banco. A falha no passo 4 aborta o método, a tela captura a exceção exibindo o SnackBar de erro, e o grupo permanece gravado no Supabase sem nenhuma temporada associada (**grupo órfão**).

#### Comparação com `pre-refactor` e histórico
- Comparando com `git show pre-refactor:lib/repositories/groups_repository.dart:126-130`:
  ```dart
  await _client.from('seasons').insert({
    'group_id': group.id,
    'name': 'Temporada 1',
    'is_active': true,
  });
  ```
  O código era **rigorosamente idêntico** na tag `pre-refactor`.
- **É regressão?** **NÃO.** Não foi introduzido pelas tarefas de refatoração T1, T2, T3 ou T4.
- **Commit original:** O trecho foi introduzido no commit `4f287b5` (*"changes"*, de 13/09/2026) por Enzo. Em contrapartida, no script de migração (`tool/legacy/data_migration_service.dart:327`), o `id` da temporada padrão era explicitamente gerado via `_uuid.v4()`.

---

### 7.2 Bugs B2 e B3: Jogador novo não aparece em pelada existente e nome editado não atualiza

#### De onde as telas leem o elenco?
1. **Tela "Adicionar Jogadores" na partida (`MatchScreen`):**
   - Em `lib/screens/match_screen.dart:2806-2827` (`_showMultiSelectDialog`):
     ```dart
     final prefs = await SharedPreferences.getInstance();
     final String? dbData = prefs.getString('players_${widget.groupId}');
     if (dbData != null) {
       setState(() {
         allSavedPlayers = List<Map<String, dynamic>>.from(jsonDecode(dbData));
       });
     }
     if (allSavedPlayers.isEmpty && widget.groupId.isNotEmpty) {
       // só busca no Supabase se allSavedPlayers estiver VAZIO!
       final fetched = await AppServices.instance.players.getPlayersByGroup(widget.groupId);
       ...
     }
     ```
   - O modal lê o elenco da variável `allSavedPlayers`, alimentada primariamente pela chave `players_${widget.groupId}` em `SharedPreferences`. Se essa chave contiver dados (mesmo que defasados), a chamada remota ao Supabase **nunca é realizada**.
2. **Tela de Elenco (`PlayersScreen`):**
   - Em `lib/screens/players_screen.dart:71-97` (`_loadPlayers`): busca do Supabase via `AppServices.instance.players.getPlayersByGroup(widget.groupId)` (com fallback do `CacheStore`).
3. **Tela de Detalhes do Jogador (`PlayerDetail`):**
   - Em `lib/screens/player_detail.dart:134-165` (`_loadPlayerDetails`): busca via `AppServices.instance.players.getPlayersByGroup(widget.groupId)`, caindo em `players_${widget.groupId}` apenas se a lista remota vier vazia. O título inicial da AppBar recebe `widget.initialPlayerName` vindo da tela chamadora.
4. **Tela de Comparação (`PlayerComparisonScreen`):**
   - Em `lib/screens/player_comparison_screen.dart:49-60`: lê exclusivamente de `players_${widget.groupId}` no `SharedPreferences`.

#### O que a criação de jogador invalida ou atualiza? (Bug B2)
- Em `lib/screens/players_screen.dart:140-159` (`_addNewPlayer`) e `lib/data/supabase/players_repository.dart:93-120` (`createGhostPlayer`):
  - O jogador é inserido em `players` e `group_members` no Supabase.
  - **O que NÃO faz:** NÃO atualiza o snapshot `players_${widget.groupId}` no `SharedPreferences` e NÃO invalida o cache `players:group:$groupId` do `CacheStore`.
  - **Consequência (B2):** O jogador aparece em `PlayersScreen` (que consulta o Supabase na hora), mas a `MatchScreen` da pelada em andamento continua lendo o snapshot estático de `players_${widget.groupId}` sem o novo jogador. O atleta só aparece após um novo `GroupBootstrap.prefetch` (ex.: ao reiniciar ou criar nova pelada).

#### O que `_savePlayerName` invalida ou atualiza? (Bug B3)
- Em `lib/screens/player_detail.dart:1207-1225`:
  ```dart
  Future<void> _savePlayerName(String newName) async {
    final prefs = await SharedPreferences.getInstance();
    final String key = 'players_${widget.groupId}';
    if (!prefs.containsKey(key)) return;
    ...
    players[index]['name'] = newName;
    await prefs.setString(key, jsonEncode(players));
    setState(() {
      playerName = newName;
      playerStats['name'] = newName;
    });
  }
  ```
  - **O que faz:** Atualiza apenas a string JSON na chave local `players_${widget.groupId}` do `SharedPreferences`.
  - **O que NÃO faz:** **NUNCA chama `AppServices.instance.players.updatePlayer(...)` no Supabase** e não altera o `CacheStore`.
  - **Consequência (B3):** O nome no Supabase permanece o antigo. Sempre que `_loadPlayerDetails` recarrega ou quando o usuário volta para a `PlayersScreen`, a consulta remota sobrescreve o nome com o valor original do banco. Em telas como comparação, se o jogador não estiver na chave local, `firstWhere` retorna `{}` e o nome vira "Desconhecido".

#### Comparação com `pre-refactor`
- Em `pre-refactor:lib/screens/player_detail.dart:983-1000`, `_savePlayerName` já alterava unicamente `SharedPreferences`, sem persistência no Supabase.
- Ambos os comportamentos **já existiam antes da refatoração** (não são regressões).

---

### 7.3 Bug B4: Denominador e cálculo do "jogador com quem mais perdeu"

#### Localização no código
- Arquivo: `lib/screens/player_detail.dart`
- Linhas:
  - `lossesWith`: acumulado nas linhas 852-858 (incrementa +1 para cada companheiro presente em uma derrota).
  - `myTotalLosses`: obtido nas linhas 931-932 (`(currentStats?['losses'] as int?) ?? myCalculatedLosses`).
  - `buildDistributionList`: linhas 948-949 (`final double pct = totalReference > 0 ? (e.value / totalReference) * 100 : 0.0;`).
  - Configuração da categoria: linhas 1024-1038 (`categoryPerdeuJunto`).
  - Ranqueamento Top 1 (`findMax`): linhas 1121-1153 e 1161-1165.

#### Apontamento do denominador errado
1. **No card de distribuição (`categoryPerdeuJunto`, linhas 1034 e 1037):**
   ```dart
   totalReference: myTotalLosses,
   items: buildDistributionList(lossesWith, totalReference: myTotalLosses),
   ```
   - O denominador utilizado é `myTotalLosses` (total absoluto de derrotas sofridas pelo atleta).
   - **Problema estrutural:** Em partidas coletivas (5v5 ou 6v6), **cada derrota possui múltiplos companheiros de equipe simultâneos**. Se o jogador perdeu 5 partidas e atuou sempre com os mesmos 4 companheiros, cada um deles terá `count = 5`. Com `totalReference = 5`, cada um deles terá `percentage = 100%`, fazendo com que a soma das fatias percentuais atinja **500%**. O conceito de "distribuição" (partição proporcional que soma 100%, como em assistências) é violado.
2. **Divergência com a lógica do Top 1 em `findMax` (linhas 1161-1165):**
   ```dart
   'mostLossesWith': findMax(
     lossesWith,
     ratioBaseMap: gamesWith,
     minBase: 5,
   ),
   ```
   - No algoritmo de ordenação de `findMax` (e no formato antigo pré-commit `ea08813`), o denominador utilizado era `gamesWith` (o total de partidas jogadas em conjunto com aquele parceiro específico), calculando a **taxa de derrotas conjuntas** (`lossesWith / gamesWith`).
   - Há uma incompatibilidade conceitual direta entre o percentual exibido na lista (`derrotas_com_parceiro / total_derrotas_minhas`) e o critério de quem é o parceiro mais derrotado (`derrotas_com_parceiro / jogos_com_parceiro`).

---

### 7.4 Bug B5: Tratamento de erros na fila `SupabaseMatchOutbox`

#### Localização no código
- Arquivo: `lib/data/supabase/supabase_match_outbox.dart`
- Método: `flush()` (linhas 81-132)

#### Análise do tratamento de erros
```dart
while (true) {
  final jobs = _read(prefs);
  if (jobs.isEmpty) break;
  final job = jobs.first;
  final matchId = job['match_id'].toString();
  final attempts = (job['attempts'] as num?)?.toInt() ?? 0;

  try {
    await _matchesRepository.savePendingMatch(...).timeout(const Duration(seconds: 25));
    // Sucesso: remove da fila
    ...
  } catch (e) {
    debugPrint('SupabaseMatchOutbox: falha ao enviar $matchId: $e');
    final fresh = _read(prefs);
    for (final j in fresh) {
      if (j['match_id'].toString() == matchId) {
        j['attempts'] = attempts + 1;
      }
    }
    await _write(prefs, fresh);
    lastError.value = e.toString();
    _scheduleRetry();
    break;
  }
}
```

#### Falha identificada
- O bloco `catch (e)` captura qualquer `Object`/`Exception` indistintamente.
- **NÃO EXISTE NENHUMA DIFERENCIAÇÃO** entre:
  1. **Erros transitórios de rede:** `SocketException`, `TimeoutException`, HTTP 500/503.
  2. **Erros permanentes de banco de dados:** `PostgrestException` código `23503` (violação de foreign key, ex.: atleta excluído do banco após a partida), erro `23505` (duplicação não idempotente), payload com dados inválidos ou nulos.
- **Consequência grave (Head-of-Line Blocking):**
  - Diante de um erro permanente, o job nunca é descartado nem isolado.
  - O método incrementa `attempts` e invoca `_scheduleRetry()`, tentando reenviar a mesma partida a cada 60 segundos indefinidamente.
  - Como a fila é processada estritamente pelo primeiro elemento (`final job = jobs.first;`), essa partida inválida **bloqueia todas as partidas subsequentes** que venham a ser enfileiradas.
  - Além disso, como `SupabaseMatchOutbox.readAll()` mescla as partidas pendentes no histórico e nas estatísticas, o evento com erro permanente (ex.: gol do jogador apagado) continua sendo computado a cada inicialização do app.

---

## 8. Novas Dúvidas Registradas em `docs/DUVIDAS.md`

Três novas dúvidas foram formalmente registradas em `docs/DUVIDAS.md`:

1. **Item 20:** Denominador e conceito de percentual em "Mais Perdeu Junto" (`player_detail.dart`) — Bug B4.
2. **Item 21:** `id` nulo na criação da temporada padrão em `createGroup` (`groups_repository.dart`) — Bug B1.
3. **Item 22:** Desconexão entre cache local (`players_<groupId>`) e Supabase na edição e criação de jogadores — Bugs B2 e B3.
