# CODIGO_MORTO.md — Mapeamento de Chamadores de Repositórios e Alcançabilidade de Telas

Este documento registra o inventário factual de chamadores para cada método público de `lib/repositories/`, o mapeamento de alcançabilidade de cada tela em `lib/screens/` e a origem dos dados das telas alcançáveis de ranking e estatísticas.

---

## 1. Métodos Públicos em `lib/repositories/` e Chamadores Externos

### 1.1 `ActionLogsRepository` (`lib/repositories/action_logs_repository.dart`)

* **`log({required String groupId, required String action, String? targetPlayerId, Map<String, dynamic> details = const {}})`**: 8 chamadores
  * `lib/repositories/players_repository.dart:205`
  * `lib/repositories/players_repository.dart:323`
  * `lib/repositories/players_repository.dart:350`
  * `lib/repositories/players_repository.dart:386`
  * `lib/repositories/players_repository.dart:415`
  * `lib/repositories/players_repository.dart:455`
  * `lib/repositories/players_repository.dart:509`
  * `lib/repositories/players_repository.dart:563`
* **`getRecentLogs(String groupId, {int limit = 100})`**: 0 CHAMADORES
* **`exportAndCleanOldLogs(String groupId, {int olderThanDays = 30})`**: 0 CHAMADORES

---

### 1.2 `GroupMembersRepository` (`lib/repositories/group_members_repository.dart`)

* **`getMembers(String groupId)`**: 1 chamador
  * `lib/screens/manage_members_screen.dart:34`
* **`getMyMembership(String groupId)`**: 2 chamadores
  * `lib/screens/group_dashboard_screen.dart:64`
  * `lib/screens/manage_members_screen.dart:35`
* **`isCurrentUserAdmin(String groupId)`**: 17 chamadores
  * `lib/repositories/groups_repository.dart:143`
  * `lib/repositories/groups_repository.dart:160`
  * `lib/repositories/players_repository.dart:296`
  * `lib/repositories/players_repository.dart:337`
  * `lib/repositories/players_repository.dart:370`
  * `lib/repositories/players_repository.dart:402`
  * `lib/repositories/players_repository.dart:434`
  * `lib/repositories/players_repository.dart:475`
  * `lib/repositories/players_repository.dart:541`
  * `lib/repositories/seasons_repository.dart:53`
  * `lib/repositories/seasons_repository.dart:88`
  * `lib/repositories/seasons_repository.dart:115`
  * `lib/screens/group_dashboard_screen.dart:49`
  * `lib/screens/manage_badges_screen.dart:114`
  * `lib/screens/player_detail.dart:111`
  * `lib/screens/players_screen.dart:61`
  * `lib/screens/sessions_screen.dart:35`
* **`promoteToAdmin({required String groupId, required String playerId})`**: 1 chamador
  * `lib/screens/manage_members_screen.dart:63`
* **`demoteToMember({required String groupId, required String playerId})`**: 1 chamador
  * `lib/screens/manage_members_screen.dart:58`
* **`addMember({required String groupId, required String playerId, String role = GroupMemberModel.roleMember})`**: 0 CHAMADORES
* **`removeMember({required String groupId, required String playerId})`**: 0 CHAMADORES
* **`findGroupByCode(String code)`**: 1 chamador
  * `lib/screens/join_group_screen.dart:32`
* **`requestToJoin({required String inviteCode, required String desiredName})`**: 1 chamador
  * `lib/screens/join_group_screen.dart:36`
* **`listPendingRequests(String groupId)`**: 1 chamador
  * `lib/screens/manage_join_requests_screen.dart:29`
* **`approveRequest(String requestId, {String? existingPlayerId})`**: 1 chamador
  * `lib/screens/manage_join_requests_screen.dart:47`
* **`rejectRequest(String requestId)`**: 1 chamador
  * `lib/screens/manage_join_requests_screen.dart:80`

---

### 1.3 `GroupsRepository` (`lib/repositories/groups_repository.dart`)

* **`getMyGroups()`**: 1 chamador
  * `lib/main.dart:174`
* **`createGroup({required String name, String? adminPlayerName})`**: 1 chamador
  * `lib/main.dart:273`
* **`updateGroup(GroupModel group)`**: 1 chamador
  * `lib/main.dart:271`
* **`deleteGroup(String groupId)`**: 1 chamador
  * `lib/main.dart:336`

---

### 1.4 `MatchesRepository` (`lib/repositories/matches_repository.dart`)

* **`getMatchesBySession(String sessionId)`**: 3 chamadores
  * `lib/screens/history_screen.dart:117`
  * `lib/screens/match_screen.dart:555`
  * `lib/screens/ranking_screen.dart:134`
* **`getMatchesByGroup(String groupId)`**: 2 chamadores
  * `lib/screens/season_stats_screen.dart:199`
  * `lib/utils/stats_calculator.dart:21`
* **`savePendingMatch({required String matchId, required Map<String, dynamic> match, required List<Map<String, dynamic>> lineups, required List<Map<String, dynamic>> events, bool isRetry = false})`**: 1 chamador
  * `lib/services/pending_match_queue.dart:86`
* **`saveFullMatch({required String sessionId, required String groupId, required int teamAScore, required int teamBScore, DateTime? startTime, DateTime? endTime, int? durationSeconds, String? status, required List<MatchLineupModel> lineups, required List<MatchEventModel> events, String? seasonId, List<RatingHistoryModel> ratingHistory = const []})`**: 0 CHAMADORES
* **`updateFullMatch({required String matchId, required String sessionId, required int teamAScore, required int teamBScore, DateTime? startTime, DateTime? endTime, int? durationSeconds, String? status, required List<MatchLineupModel> lineups, required List<MatchEventModel> events, String? seasonId, List<RatingHistoryModel> ratingHistory = const []})`**: 0 CHAMADORES
* **`updatePartialMatch({required String matchId, required int teamAScore, required int teamBScore, required List<MatchEventModel> events})`**: 1 chamador
  * `lib/screens/edit_match_screen.dart:450`
* **`deleteMatch(String matchId)`**: 1 chamador
  * `lib/screens/history_screen.dart:174`

---

### 1.5 `PlayersRepository` (`lib/repositories/players_repository.dart`)

* **`getPlayersByGroup(String groupId)`**: 12 chamadores
  * `lib/screens/edit_match_screen.dart:63`
  * `lib/screens/history_screen.dart:102`
  * `lib/screens/manage_badges_screen.dart:88`
  * `lib/screens/manage_join_requests_screen.dart:98`
  * `lib/screens/match_screen.dart:2798`
  * `lib/screens/player_detail.dart:131`
  * `lib/screens/players_screen.dart:73`
  * `lib/screens/ranking_screen.dart:87`
  * `lib/screens/season_stats_screen.dart:200`
  * `lib/screens/sessions_screen.dart:63`
  * `lib/services/group_bootstrap.dart:87`
  * `lib/utils/stats_calculator.dart:22`
* **`createGhostPlayer({required String groupId, required String name, String? avatarUrl, List<PlayerBadgeModel> badges = const []})`**: 1 chamador
  * `lib/screens/players_screen.dart:141`
* **`createPlayerWithUser({required String groupId, required String userId, required String name, String? avatarUrl, List<PlayerBadgeModel> badges = const [], String role = 'member'})`**: 0 CHAMADORES
* **`updatePlayer(PlayerModel player)`**: 2 chamadores
  * `lib/screens/player_detail.dart:1410`
  * `lib/screens/player_detail.dart:2034`
* **`setPlayerIcon({required String playerId, required String? iconPath})`**: 1 chamador
  * `lib/screens/player_detail.dart:1006`
* **`setGoalSound({required String playerId, required String? audioFileName, String? groupId})`**: 2 chamadores
  * `lib/screens/manage_badges_screen.dart:129`
  * `lib/screens/player_detail.dart:1053`
* **`removePlayerFromGroup({required String groupId, required String playerId})`**: 1 chamador
  * `lib/screens/players_screen.dart:190`
* **`linkEmailToPlayer({required String playerId, required String email})`**: 0 CHAMADORES
* **`claimGhostProfiles()`**: 1 chamador
  * `lib/main.dart:99`
* **`getMyPlayers()`**: 1 chamador
  * `lib/main.dart:100`
* **`uploadGoalSound({required String groupId, required String playerId, required Uint8List fileBytes, required String fileExtension})`**: 0 CHAMADORES
* **`clearGoalSound({required String groupId, required String playerId})`**: 0 CHAMADORES
* **`setNameEffect({required String groupId, required String playerId, required String? effect})`**: 1 chamador
  * `lib/screens/manage_badges_screen.dart:558`
* **`setMonthlyHighlight({required String groupId, required String playerId, required bool value})`**: 1 chamador
  * `lib/screens/manage_badges_screen.dart:618`
* **`setCosmetics({required String groupId, required String playerId, required bool goldenBall, required CosmeticEffect nameEffect, required int monthlyStarCount})`**: 0 CHAMADORES
* **`setCommunityAttributes({required String groupId, required String playerId, required CommunityAttributes attributes})`**: 1 chamador
  * `lib/screens/player_detail.dart:3551`
* **`getPlayerById(String playerId)`**: 2 chamadores (fora da própria classe)
  * `lib/screens/player_detail.dart:1402`
  * `lib/screens/player_detail.dart:2017`
* **`setAdvancedStat({required String groupId, required String playerId, required Map<String, dynamic> patch})`**: 1 chamador
  * `lib/screens/manage_badges_screen.dart:582`

---

### 1.6 `RatingsRepository` (`lib/repositories/ratings_repository.dart`)

* **`getPlayerHistoryBySeason({required String playerId, required String seasonId})`**: 0 CHAMADORES
* **`getFullPlayerHistory(String playerId)`**: 0 CHAMADORES
* **`getLatestRatingsBySeason(String seasonId)`**: 0 CHAMADORES
* **`recordRatingsBatch(List<RatingHistoryModel> records)`**: 0 CHAMADORES

---

### 1.7 `SeasonsRepository` (`lib/repositories/seasons_repository.dart`)

* **`getSeasons(String groupId)`**: 3 chamadores
  * `lib/screens/manage_seasons_screen.dart:28`
  * `lib/screens/player_detail.dart:209`
  * `lib/screens/season_stats_screen.dart:201`
* **`getCurrentSeason(String groupId)`**: 1 chamador
  * `lib/screens/sessions_screen.dart:89`
* **`createSeason({required String groupId, required String name, DateTime? startDate, DateTime? endDate, bool isActive = true})`**: 1 chamador
  * `lib/screens/manage_seasons_screen.dart:158`
* **`updateSeason(SeasonModel season)`**: 1 chamador
  * `lib/screens/manage_seasons_screen.dart:172`
* **`deleteSeason({required String groupId, required String seasonId})`**: 1 chamador
  * `lib/screens/manage_seasons_screen.dart:227`

---

### 1.8 `SessionArrivalsRepository` (`lib/repositories/session_arrivals_repository.dart`)

* **`getArrivals(String sessionId)`**: 1 chamador
  * `lib/screens/match_screen.dart:379`
* **`getPlayerIdsBySessions(List<String> sessionIds)`**: 1 chamador
  * `lib/screens/sessions_screen.dart:60`
* **`replaceArrivals(String sessionId, List<Map<String, dynamic>> players)`**: 1 chamador
  * `lib/screens/match_screen.dart:309`
* **`clearArrivals(String sessionId)`**: 0 CHAMADORES

---

### 1.9 `SessionsRepository` (`lib/repositories/sessions_repository.dart`)

* **`getCachedSession(String sessionId)`**: 1 chamador
  * `lib/screens/match_screen.dart:447`
* **`getSessionById(String sessionId)`**: 2 chamadores
  * `lib/screens/history_screen.dart:111`
  * `lib/screens/match_screen.dart:593`
* **`getSessionsBySeason(String seasonId)`**: 0 CHAMADORES
* **`getSessionsByGroup(String groupId)`**: 2 chamadores
  * `lib/screens/sessions_screen.dart:43`
  * `lib/services/group_bootstrap.dart:95`
* **`createSession(SessionModel session)`**: 1 chamador
  * `lib/screens/sessions_screen.dart:109`
* **`updateSession(SessionModel session)`**: 1 chamador
  * `lib/screens/sessions_screen.dart:111`
* **`updateRuntimeState(String sessionId, {bool? isRunning, int? secondsPlayed, int? scoreRed, int? scoreWhite, int? redStreak, int? whiteStreak, bool? isOvertime, DateTime? startedAt, String? status})`**: 1 chamador
  * `lib/screens/match_screen.dart:312`
* **`finalizeSession(String sessionId)`**: 0 CHAMADORES
* **`deleteSession(String sessionId)`**: 1 chamador
  * `lib/screens/sessions_screen.dart:132`

---

## 2. Arquivos em `lib/screens/` e Mapeamento de Abertura

Para cada arquivo em `lib/screens/`, mapeamento de quem o abre:

1. **`lib/screens/admin_debug_screen.dart`** (`AdminDebugScreen`)
   * Aberto por: `lib/screens/group_dashboard_screen.dart:157` (`Navigator.push` / `MaterialPageRoute`)

2. **`lib/screens/blank_screen.dart`** (`BlankScreen`)
   * Aberto por: `lib/screens/tournament_screen.dart:122` (`MaterialPageRoute`)
   * Como `tournament_screen.dart` possui 0 chamadores em todo o projeto, `BlankScreen` é **INALCANÇÁVEL** (há também um `import` não utilizado em `lib/main.dart:5`).

3. **`lib/screens/complete_profile_screen.dart`** (`CompleteProfileScreen`)
   * Aberto por: `lib/main.dart:120` (renderizado diretamente por `_ProfileCheckState.build` no fluxo inicial de autenticação)

4. **`lib/screens/draft_screen.dart`** (`DraftScreen`)
   * Aberto por: `lib/screens/match_screen.dart:1354` (`Navigator.push` / `MaterialPageRoute` em `_openDraftModal`)

5. **`lib/screens/edit_match_screen.dart`** (`EditMatchScreen`)
   * Aberto por: `lib/screens/history_screen.dart:221` (`Navigator.push` / `MaterialPageRoute` em `_showMatchOptionsModal`)

6. **`lib/screens/expanded_ranking_screen.dart`** (`ExpandedRankingScreen`)
   * **INALCANÇÁVEL** (nenhuma rota, botão, `Navigator.push` ou importador no aplicativo)

7. **`lib/screens/group_dashboard_screen.dart`** (`GroupDashboardScreen`)
   * Aberto por: `lib/main.dart:605` (`Navigator.push` / `MaterialPageRoute` ao selecionar grupo na `HomePage`)

8. **`lib/screens/group_ranking_screen.dart`** (`GroupRankingScreen`)
   * **INALCANÇÁVEL** (nenhuma rota, botão, `Navigator.push` ou importador no aplicativo)

9. **`lib/screens/history_screen.dart`** (`HistoryScreen`)
   * Aberto por: `lib/screens/tournament_dashboard_screen.dart:51` (Tab 2 do `TournamentDashboardScreen`)
   * *(Nota: também referenciado em `lib/screens/tournament_screen.dart:116`, tela inalcançável)*

10. **`lib/screens/join_group_screen.dart`** (`JoinGroupScreen`)
    * Aberto por: `lib/main.dart:164` (`Navigator.push` / `MaterialPageRoute` em `_openJoinGroupScreen`, acionado em `lib/main.dart:500` e `lib/main.dart:571`)

11. **`lib/screens/login_screen.dart`** (`LoginScreen`)
    * Aberto por: `lib/main.dart:69` (renderizado diretamente por `_AuthGateState.build` quando `session == null`)

12. **`lib/screens/manage_badges_screen.dart`** (`ManageBadgesScreen`)
    * Aberto por: `lib/screens/group_dashboard_screen.dart:147` (`Navigator.push` / `MaterialPageRoute` no menu Popup 'badges')

13. **`lib/screens/manage_join_requests_screen.dart`** (`ManageJoinRequestsScreen`)
    * Aberto por: `lib/screens/group_dashboard_screen.dart:137` (`Navigator.push` / `MaterialPageRoute` no menu Popup 'requests')

14. **`lib/screens/manage_members_screen.dart`** (`ManageMembersScreen`)
    * Aberto por: `lib/screens/group_dashboard_screen.dart:142` (`Navigator.push` / `MaterialPageRoute` no menu Popup 'members')

15. **`lib/screens/manage_seasons_screen.dart`** (`ManageSeasonsScreen`)
    * Aberto por: `lib/screens/group_dashboard_screen.dart:152` (`Navigator.push` / `MaterialPageRoute` no menu Popup 'seasons')

16. **`lib/screens/match_screen.dart`** (`MatchScreen`)
    * Aberto por: `lib/screens/tournament_dashboard_screen.dart:36` (Tab 0 do `TournamentDashboardScreen`)
    * *(Nota: também referenciado em `lib/screens/tournament_screen.dart:101`, tela inalcançável)*

17. **`lib/screens/player_comparison_screen.dart`** (`PlayerComparisonScreen`)
    * Aberto por: `lib/screens/player_detail.dart:1791` (`Navigator.push` / `MaterialPageRoute` ao selecionar rival para comparação)

18. **`lib/screens/player_detail.dart`** (`PlayerDetailScreen`)
    * Aberto por:
      * `lib/screens/group_dashboard_screen.dart:77` (`Navigator.push` / `MaterialPageRoute` em `_openMyProfile`)
      * `lib/screens/players_screen.dart:397` (`Navigator.push` / `MaterialPageRoute` em `_openPlayer`)
      * `lib/screens/season_stats_screen.dart:468` (`Navigator.push` / `MaterialPageRoute` ao tocar na linha de jogador)
      * `lib/screens/ranking_screen.dart:875` (`Navigator.push` / `MaterialPageRoute` ao tocar no pódio)
      * `lib/screens/ranking_screen.dart:1352` (`Navigator.push` / `MaterialPageRoute` em `_openPlayer`)
      * *(Nota: também referenciado nas telas inalcançáveis `expanded_ranking_screen.dart:154` e `group_ranking_screen.dart:816, 1215, 1442`)*

19. **`lib/screens/players_screen.dart`** (`PlayersScreen`)
    * Aberto por: `lib/screens/group_dashboard_screen.dart:91` (Tab 1 do `GroupDashboardScreen`: "Elenco")
    * *(Nota: também referenciado em `lib/screens/tournament_screen.dart:94`, tela inalcançável)*

20. **`lib/screens/ranking_screen.dart`** (`RankingScreen`)
    * Aberto por: `lib/screens/tournament_dashboard_screen.dart:45` (Tab 1 do `TournamentDashboardScreen`: "Ranking")

21. **`lib/screens/season_stats_screen.dart`** (`SeasonStatsScreen`)
    * Aberto por: `lib/screens/group_dashboard_screen.dart:92` (Tab 2 do `GroupDashboardScreen`: "Estatísticas")

22. **`lib/screens/sessions_screen.dart`** (`SessionsScreen`)
    * Aberto por: `lib/screens/group_dashboard_screen.dart:90` (Tab 0 do `GroupDashboardScreen`: "Peladas")

23. **`lib/screens/tournament_dashboard_screen.dart`** (`TournamentDashboardScreen`)
    * Aberto por: `lib/screens/sessions_screen.dart:154` (`Navigator.push` / `MaterialPageRoute` ao tocar em um card de sessão)

24. **`lib/screens/tournament_screen.dart`** (`TournamentScreen`)
    * **INALCANÇÁVEL** (nenhuma rota, botão, `Navigator.push` ou importador no aplicativo)

---

## 3. Origem dos Dados nas Telas Alcançáveis de Ranking ou Estatística

* **`lib/screens/ranking_screen.dart` (`RankingScreen`)**: Ambos (tenta carregar jogadores via `PlayersRepository.getPlayersByGroup` [L87] com fallback para `SharedPreferences` chave `players_<groupId>` [L107], e partidas via `MatchesRepository.getMatchesBySession` [L134] com fallback para `SharedPreferences` chave `match_history_<tournamentId>` [L177]).
* **`lib/screens/season_stats_screen.dart` (`SeasonStatsScreen`)**: Repositório (`MatchesRepository.getMatchesByGroup` [L199], `PlayersRepository.getPlayersByGroup` [L200] e `SeasonsRepository.getSeasons` [L201], sem leitura de `SharedPreferences`).
* **`lib/screens/player_comparison_screen.dart` (`PlayerComparisonScreen`)**: Ambos (lê jogadores da chave `players_<groupId>` em `SharedPreferences` [L50, L56], preferência `show_radar_chart` em `SharedPreferences` [L52], e histórico de partidas via `getAllGroupMatches` [L62] que consulta repositórios com fallback para `SharedPreferences`).
* **`lib/screens/player_detail.dart` (`PlayerDetailScreen`)**: Ambos (busca jogadores e temporadas via repositórios [L131, L209], mas lê insígnias de `custom_badges_<groupId>` [L116], elenco de `players_<groupId>` [L150, L174] e histórico de `match_history_*` [L1813] em `SharedPreferences`).
