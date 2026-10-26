# Inventário de Acoplamento com Supabase e Dependências de Plataforma

Este documento mapeia o acoplamento do aplicativo com o Supabase, chamadas de banco de dados, fluxos de autenticação, operações de escrita multi-tabela, dependência de papéis administrativos e restrições de compatibilidade para execução na Web.

---

## 1. Métodos Públicos em `lib/repositories/` e Tabelas Utilizadas

### 1.1 `lib/repositories/action_logs_repository.dart`

| Método Público (Assinatura Completa) | Linhas | Tabelas / Recursos Supabase |
|---|---|---|
| `Future<void> log({required String groupId, required String action, String? targetPlayerId, Map<String, dynamic> details = const {}})` | 24-44 | `group_action_logs` (insert) |
| `Future<List<Map<String, dynamic>>> getRecentLogs(String groupId, {int limit = 100})` | 47-61 | `group_action_logs` (select) |
| `Future<List<Map<String, dynamic>>> exportAndCleanOldLogs(String groupId, {int olderThanDays = 30})` | 65-77 | RPC `export_and_clean_action_logs` (executa na tabela `group_action_logs`) |

---

### 1.2 `lib/repositories/group_members_repository.dart`

| Método Público (Assinatura Completa) | Linhas | Tabelas / Recursos Supabase |
|---|---|---|
| `Future<List<GroupMemberModel>> getMembers(String groupId)` | 14-25 | `group_members`, `players` (join `players(*)`) |
| `Future<GroupMemberModel?> getMyMembership(String groupId)` | 28-41 | `group_members`, `players` (join `players!inner(*)`) |
| `Future<bool> isCurrentUserAdmin(String groupId)` | 47-65 | `groups` (select `creator_id`), `group_members` e `players` (via `getMyMembership`) |
| `Future<void> promoteToAdmin({required String groupId, required String playerId})` | 68-82 | `group_members` (update), `groups` e `players` (via validação em `isCurrentUserAdmin`) |
| `Future<void> demoteToMember({required String groupId, required String playerId})` | 85-99 | `group_members` (update), `groups` e `players` (via validação em `isCurrentUserAdmin`) |
| `Future<GroupMemberModel> addMember({required String groupId, required String playerId, String role = GroupMemberModel.roleMember})` | 102-118 | `group_members` (insert), `players` (join `players(*)`) |
| `Future<void> removeMember({required String groupId, required String playerId})` | 121-130 | `group_members` (delete) |
| `Future<GroupModel?> findGroupByCode(String code)` | 141-148 | RPC `find_group_by_invite_code` (consulta tabela `groups`) |
| `Future<void> requestToJoin({required String inviteCode, required String desiredName})` | 151-170 | `group_join_requests` (insert), `groups` (via `findGroupByCode` / RPC `find_group_by_invite_code`) |
| `Future<List<Map<String, dynamic>>> listPendingRequests(String groupId)` | 173-181 | `group_join_requests` (select) |
| `Future<void> approveRequest(String requestId, {String? existingPlayerId})` | 185-190 | RPC `approve_join_request` |
| `Future<void> rejectRequest(String requestId)` | 192-194 | RPC `reject_join_request` |

---

### 1.3 `lib/repositories/groups_repository.dart`

| Método Público (Assinatura Completa) | Linhas | Tabelas / Recursos Supabase |
|---|---|---|
| `Future<List<GroupModel>> getMyGroups()` | 22-65 | `groups` (select), `group_members` (select), `players` (join `players!inner(creator_id)`) |
| `Future<GroupModel> createGroup({required String name, String? adminPlayerName})` | 75-139 | `groups` (insert), `players` (select e insert condicional), `group_members` (insert), `seasons` (insert) |
| `Future<GroupModel> updateGroup(GroupModel group)` | 142-156 | `groups` (update), `group_members` e `players` (via `_membersRepo.isCurrentUserAdmin`) |
| `Future<void> deleteGroup(String groupId)` | 159-166 | `groups` (delete), `group_members` e `players` (via `_membersRepo.isCurrentUserAdmin`) |

---

### 1.4 `lib/repositories/matches_repository.dart`

| Método Público (Assinatura Completa) | Linhas | Tabelas / Recursos Supabase |
|---|---|---|
| `Future<List<MatchModel>> getMatchesBySession(String sessionId)` | 49-103 | `matches` (select), `match_lineups` (select com join `players(*)`), `players` (join), `match_events` (select) |
| `Future<List<MatchModel>> getMatchesByGroup(String groupId)` | 118-146 | `matches` (select), `match_lineups` (select), `match_events` (select) |
| `Future<void> savePendingMatch({required String matchId, required Map<String, dynamic> match, required List<Map<String, dynamic>> lineups, required List<Map<String, dynamic>> events, bool isRetry = false})` | 164-190 | `matches` (upsert), `match_lineups` (delete se retry, insert), `match_events` (delete se retry, insert) |
| `Future<MatchModel> saveFullMatch({required String sessionId, required String groupId, required int teamAScore, required int teamBScore, DateTime? startTime, DateTime? endTime, int? durationSeconds, String? status, required List<MatchLineupModel> lineups, required List<MatchEventModel> events, String? seasonId, List<RatingHistoryModel> ratingHistory = const []})` | 193-269 | `matches` (insert), `match_lineups` (insert), `match_events` (insert), `rating_history` (insert) |
| `Future<MatchModel> updateFullMatch({required String matchId, required String sessionId, required int teamAScore, required int teamBScore, DateTime? startTime, DateTime? endTime, int? durationSeconds, String? status, required List<MatchLineupModel> lineups, required List<MatchEventModel> events, String? seasonId, List<RatingHistoryModel> ratingHistory = const []})` | 271-350 | `matches` (update), `match_events` (delete, insert), `match_lineups` (delete, insert), `rating_history` (delete, insert) |
| `Future<MatchModel> updatePartialMatch({required String matchId, required int teamAScore, required int teamBScore, required List<MatchEventModel> events})` | 352-381 | `matches` (update, select com join), `match_events` (delete, insert), `match_lineups` (join select), `players` (join select) |
| `Future<void> deleteMatch(String matchId)` | 383-388 | `match_events` (delete), `match_lineups` (delete), `rating_history` (delete), `matches` (delete) |

---

### 1.5 `lib/repositories/players_repository.dart`

| Método Público (Assinatura Completa) | Linhas | Tabelas / Recursos Supabase |
|---|---|---|
| `Future<List<PlayerModel>> getPlayersByGroup(String groupId)` | 41-86 | `group_members` (select), `players` (join `players(*)` e fallback select direto) |
| `Future<PlayerModel> createGhostPlayer({required String groupId, required String name, String? avatarUrl, List<PlayerBadgeModel> badges = const []})` | 89-116 | `players` (insert), `group_members` (insert) |
| `Future<PlayerModel> createPlayerWithUser({required String groupId, required String userId, required String name, String? avatarUrl, List<PlayerBadgeModel> badges = const [], String role = 'member'})` | 119-148 | `players` (insert), `group_members` (insert) |
| `Future<PlayerModel> updatePlayer(PlayerModel player)` | 151-166 | `players` (update) |
| `Future<PlayerModel> setPlayerIcon({required String playerId, required String? iconPath})` | 170-182 | `players` (update) |
| `Future<PlayerModel> setGoalSound({required String playerId, required String? audioFileName, String? groupId})` | 186-216 | `players` (update), `group_action_logs` (insert via `_logs.log`) |
| `Future<void> removePlayerFromGroup({required String groupId, required String playerId})` | 220-229 | `group_members` (delete) |
| `Future<PlayerModel> linkEmailToPlayer({required String playerId, required String email})` | 234-245 | `players` (update) |
| `Future<List<PlayerModel>> claimGhostProfiles()` | 249-255 | RPC `claim_ghost_profile` |
| `Future<List<PlayerModel>> getMyPlayers()` | 258-266 | `players` (select por `creator_id` via `_client.auth.currentUser?.id`) |
| `Future<PlayerModel> uploadGoalSound({required String groupId, required String playerId, required Uint8List fileBytes, required String fileExtension})` | 290-330 | Storage bucket `goal-sounds` (uploadBinary, getPublicUrl), `players` (update), `group_action_logs` (insert via `_logs.log`), `groups`/`group_members` (via `_membersRepo.isCurrentUserAdmin`) |
| `Future<PlayerModel> clearGoalSound({required String groupId, required String playerId})` | 333-356 | `players` (update), `group_action_logs` (insert via `_logs.log`), `groups`/`group_members` (via `_membersRepo.isCurrentUserAdmin`) |
| `Future<PlayerModel> setNameEffect({required String groupId, required String playerId, required String? effect})` | 365-393 | `players` (update), `group_action_logs` (insert via `_logs.log`), `groups`/`group_members` (via `_membersRepo.isCurrentUserAdmin`) |
| `Future<PlayerModel> setMonthlyHighlight({required String groupId, required String playerId, required bool value})` | 397-422 | `players` (update), `group_action_logs` (insert via `_logs.log`), `groups`/`group_members` (via `_membersRepo.isCurrentUserAdmin`) |
| `Future<PlayerModel> setCosmetics({required String groupId, required String playerId, required bool goldenBall, required CosmeticEffect nameEffect, required int monthlyStarCount})` | 427-462 | `players` (update), `group_action_logs` (insert via `_logs.log`), `groups`/`group_members` (via `_membersRepo.isCurrentUserAdmin`) |
| `Future<PlayerModel> setCommunityAttributes({required String groupId, required String playerId, required CommunityAttributes attributes})` | 470-516 | `players` (update), `group_action_logs` (insert via `_logs.log`), `groups`/`group_members` (via `_membersRepo.isCurrentUserAdmin`) |
| `Future<PlayerModel?> getPlayerById(String playerId)` | 519-528 | `players` (select) |
| `Future<PlayerModel> setAdvancedStat({required String groupId, required String playerId, required Map<String, dynamic> patch})` | 536-570 | `players` (select via `getPlayerById`, update), `group_action_logs` (insert via `_logs.log`), `groups`/`group_members` (via `_membersRepo.isCurrentUserAdmin`) |

---

### 1.6 `lib/repositories/ratings_repository.dart`

| Método Público (Assinatura Completa) | Linhas | Tabelas / Recursos Supabase |
|---|---|---|
| `Future<List<RatingHistoryModel>> getPlayerHistoryBySeason({required String playerId, required String seasonId})` | 11-27 | `rating_history` (select), `matches` (join inner), `sessions` (join inner) |
| `Future<List<RatingHistoryModel>> getFullPlayerHistory(String playerId)` | 29-42 | `rating_history` (select) |
| `Future<Map<String, double>> getLatestRatingsBySeason(String seasonId)` | 44-63 | `rating_history` (select), `matches` (join inner), `sessions` (join inner) |
| `Future<void> recordRatingsBatch(List<RatingHistoryModel> records)` | 65-71 | `rating_history` (insert) |

---

### 1.7 `lib/repositories/seasons_repository.dart`

| Método Público (Assinatura Completa) | Linhas | Tabelas / Recursos Supabase |
|---|---|---|
| `Future<List<SeasonModel>> getSeasons(String groupId)` | 18-30 | `seasons` (select) |
| `Future<SeasonModel?> getCurrentSeason(String groupId)` | 33-43 | `seasons` (select) |
| `Future<SeasonModel> createSeason({required String groupId, required String name, DateTime? startDate, DateTime? endDate, bool isActive = true})` | 46-84 | `seasons` (update condicional de ativação, insert), `groups` e `group_members` (via `_membersRepo.isCurrentUserAdmin`) |
| `Future<SeasonModel> updateSeason(SeasonModel season)` | 87-108 | `seasons` (update condicional de ativação, update), `groups` e `group_members` (via `_membersRepo.isCurrentUserAdmin`) |
| `Future<void> deleteSeason({required String groupId, required String seasonId})` | 111-121 | `seasons` (delete), `groups` e `group_members` (via `_membersRepo.isCurrentUserAdmin`) |

---

### 1.8 `lib/repositories/session_arrivals_repository.dart`

| Método Público (Assinatura Completa) | Linhas | Tabelas / Recursos Supabase |
|---|---|---|
| `Future<List<Map<String, dynamic>>> getArrivals(String sessionId)` | 21-32 | `session_arrivals` (select) |
| `Future<Map<String, List<String>>> getPlayerIdsBySessions(List<String> sessionIds)` | 36-55 | `session_arrivals` (select) |
| `Future<void> replaceArrivals(String sessionId, List<Map<String, dynamic>> players)` | 68-94 | `session_arrivals` (delete, insert) |
| `Future<void> clearArrivals(String sessionId)` | 99-101 | `session_arrivals` (delete) |

---

### 1.9 `lib/repositories/sessions_repository.dart`

| Método Público (Assinatura Completa) | Linhas | Tabelas / Recursos Supabase |
|---|---|---|
| `Future<SessionModel?> getCachedSession(String sessionId)` | 19-24 | Nenhuma tabela Supabase (lê exclusivamente do `CacheStore` local) |
| `Future<SessionModel?> getSessionById(String sessionId)` | 33-50 | `sessions` (select) |
| `Future<List<SessionModel>> getSessionsBySeason(String seasonId)` | 53-64 | `sessions` (select) |
| `Future<List<SessionModel>> getSessionsByGroup(String groupId)` | 70-96 | `sessions` (select) |
| `Future<SessionModel> createSession(SessionModel session)` | 99-109 | `sessions` (insert) |
| `Future<SessionModel> updateSession(SessionModel session)` | 112-125 | `sessions` (update) |
| `Future<void> updateRuntimeState(String sessionId, {bool? isRunning, int? secondsPlayed, int? scoreRed, int? scoreWhite, int? redStreak, int? whiteStreak, bool? isOvertime, DateTime? startedAt, String? status})` | 136-161 | `sessions` (update) |
| `Future<void> finalizeSession(String sessionId)` | 164-169 | `sessions` (update) |
| `Future<void> deleteSession(String sessionId)` | 172-174 | `sessions` (delete) |

---

### 1.10 `lib/repositories/supabase_service.dart`

| Membro / Instância | Linhas | Tabelas / Recursos Supabase |
|---|---|---|
| `static final SupabaseService instance` / `factory SupabaseService()` | 15-17 | Service locator / Singleton que centraliza e instancia todos os repositórios e a conexão `SupabaseConfig.client` |
| `late final SupabaseClient client;` | 34 | Expõe a instância ativa do cliente Supabase |
| Repositórios instanciados (`groupMembers`, `groups`, `seasons`, `players`, `sessions`, `matches`, `ratings`, `sessionArrivals`, `actionLogs`) | 36-44 | Não consulta tabelas diretamente na classe, apenas instancia os 9 repositórios com o cliente configurado |

---

## 2. Uso de `Supabase.instance`, `supabase_flutter`, `.from(`, `.rpc(`, `.channel(` e `.auth` FORA de `lib/repositories/`

| Arquivo | Linha | Expressão no Código | O que a chamada faz |
|---|---|---|---|
| `lib/config/supabase_config.dart` | 1 | `import 'package:supabase_flutter/supabase_flutter.dart';` | Importa a biblioteca do Supabase para Flutter. |
| `lib/config/supabase_config.dart` | 11 | `await Supabase.initialize(...)` | Inicializa a conexão com a URL do projeto e a chave anon/publishable. |
| `lib/config/supabase_config.dart` | 18 | `static SupabaseClient get client => Supabase.instance.client;` | Getter estático que expõe o cliente a partir de `Supabase.instance`. |
| `lib/config/supabase_config.dart` | 21 | `static User? get currentUser => client.auth.currentUser;` | Retorna o usuário logado via `.auth.currentUser`. |
| `lib/config/supabase_config.dart` | 24 | `static String? get currentUserId => client.auth.currentUser?.id;` | Retorna o ID (UUID) do usuário logado via `.auth.currentUser?.id`. |
| `lib/main.dart` | 16 | `import 'package:supabase_flutter/supabase_flutter.dart';` | Importa os tipos da biblioteca, incluindo `AuthState`. |
| `lib/main.dart` | 68 | `stream: SupabaseConfig.client.auth.onAuthStateChange,` | StreamBuilder que escuta eventos de transição de sessão de autenticação. |
| `lib/main.dart` | 70 | `final session = SupabaseConfig.client.auth.currentSession;` | Verifica existência de sessão ativa para decisão de roteamento no `AuthGate`. |
| `lib/main.dart` | 589 | `await SupabaseConfig.client.auth.signOut();` | Executa logout do usuário autenticado no menu Drawer. |
| `lib/screens/login_screen.dart` | 2 | `import 'package:supabase_flutter/supabase_flutter.dart';` | Importa biblioteca para autenticação e tratamento de `AuthException`. |
| `lib/screens/login_screen.dart` | 30 | `await Supabase.instance.client.auth.signUp(...)` | Cria nova conta de usuário com e-mail e senha no Supabase Auth. |
| `lib/screens/login_screen.dart` | 35 | `await Supabase.instance.client.auth.signInWithPassword(...)` | Realiza autenticação com e-mail e senha no Supabase Auth. |
| `lib/screens/complete_profile_screen.dart` | 94 | `onPressed: () => SupabaseService.instance.client.auth.signOut(),` | Executa logout via cliente do Supabase no botão "Sair". |
| `lib/screens/match_screen.dart` | 410-415 | `final raw = await SupabaseService.instance.client.from('sessions').select('seconds_played,is_running,score_red,score_white,red_streak,white_streak,is_overtime,started_at').eq('id', id).maybeSingle();` | Consulta direta fora de repositório à tabela `sessions` via `.from('sessions')` para restaurar cronômetro, placares e streaks. |
| `lib/services/cache_sync_manager.dart` | 2 | `import 'package:supabase_flutter/supabase_flutter.dart';` | Importa tipagem de `SupabaseClient`. |
| `lib/services/cache_sync_manager.dart` | 61 | `await _supabase.from('sync_data').select('sync_code').limit(1);` | Consulta de 1 linha na tabela `sync_data` via `.from('sync_data')` para medir ping e testar conectividade. |
| `lib/services/data_migration_service.dart` | 5 | `import 'package:supabase_flutter/supabase_flutter.dart';` | Importa cliente e tipos para migração de dados. |
| `lib/services/data_migration_service.dart` | 140-145 | `await _client.from('groups').insert({...});` | Insere grupo na tabela `groups` via `.from('groups')`. |
| `lib/services/data_migration_service.dart` | 275 | `await _insertInBatches('players', playersToInsert);` | Insere jogadores na tabela `players` via `_client.from(table).insert` (linha 589). |
| `lib/services/data_migration_service.dart` | 282 | `await _insertInBatches('group_members', membersToInsert);` | Insere membros na tabela `group_members` via `_client.from(table).insert` (linha 589). |
| `lib/services/data_migration_service.dart` | 345 | `await _insertInBatches('seasons', seasonsToInsert);` | Insere temporadas na tabela `seasons` via `_client.from(table).insert` (linha 589). |
| `lib/services/data_migration_service.dart` | 408 | `await _insertInBatches('sessions', sessionsToInsert);` | Insere sessões na tabela `sessions` via `_client.from(table).insert` (linha 589). |
| `lib/services/data_migration_service.dart` | 525 | `await _insertInBatches('matches', matchesToInsert);` | Insere partidas na tabela `matches` via `_client.from(table).insert` (linha 589). |
| `lib/services/data_migration_service.dart` | 530 | `await _insertInBatches('match_lineups', lineupsToInsert);` | Insere escalações na tabela `match_lineups` via `_client.from(table).insert` (linha 589). |
| `lib/services/data_migration_service.dart` | 535 | `await _insertInBatches('match_events', eventsToInsert);` | Insere eventos na tabela `match_events` via `_client.from(table).insert` (linha 589). |
| `lib/services/data_migration_service.dart` | 540 | `await _insertInBatches('rating_history', ratingsToInsert);` | Insere notas na tabela `rating_history` via `_client.from(table).insert` (linha 589). |
| `lib/services/data_migration_service.dart` | 589 | `await _client.from(table).insert(batch);` | Executa inserção em lote na tabela passada como parâmetro via `.from(table)`. |
| `lib/services/fix_event_times_service.dart` | 4 | `import 'package:supabase_flutter/supabase_flutter.dart';` | Importa cliente para script de correção de dados. |
| `lib/services/fix_event_times_service.dart` | 68-69 | `final response = await _client.from('partidas').select('id, timestamp, eventos_partida(id, tipo, time, jogador_id, tempo)');` | Consulta dados da tabela legada `partidas` com join em `eventos_partida` via `.from('partidas')`. |
| `lib/services/fix_event_times_service.dart` | 136-138 | `await _client.from('eventos_partida').update({'tempo': matchedTime}).eq('id', int.parse(evId));` | Atualiza o campo `tempo` na tabela legada `eventos_partida` via `.from('eventos_partida')`. |
| `lib/services/sync_service.dart` | 3 | `import 'package:supabase_flutter/supabase_flutter.dart';` | Importa tipagem de cliente para serviço de backup/sincronização. |
| `lib/services/sync_service.dart` | 34-39 | `await _supabase.from('sync_data').upsert({...});` | Grava dados locais completos e JSON do site na tabela `sync_data` via `.from('sync_data')`. |
| `lib/services/sync_service.dart` | 47-50 | `final response = await _supabase.from('sync_data').select().eq('sync_code', syncCode).maybeSingle();` | Busca payload de restauração por código na tabela `sync_data` via `.from('sync_data')`. |
| `lib/services/sync_service.dart` | 221-226 | `await _supabase.from('sync_data').upsert({...});` | Grava versão normalizada de UUIDs na tabela `sync_data` via `.from('sync_data')`. |

*Nota sobre `.channel()` e `.rpc()` fora de `lib/repositories/`: Não existe nenhuma chamada para `.channel(` ou `.rpc(` fora de `lib/repositories/`.*

---

## 3. Chamadas `rpc()` e Realtime / Subscriptions

### 3.1 Chamadas RPC (`.rpc(...)`)

| Função RPC | Arquivo | Linhas | Parâmetros Enviados | O que a chamada faz |
|---|---|---|---|---|
| `export_and_clean_action_logs` | `lib/repositories/action_logs_repository.dart` | 69-72 | `{'p_group_id': groupId, 'p_older_than_days': olderThanDays}` | Exporta e deleta registros de auditoria da tabela `group_action_logs` mais antigos que a quantidade de dias informada. |
| `find_group_by_invite_code` | `lib/repositories/group_members_repository.dart` | 143 | `{'code': code.trim().toUpperCase()}` | Função com SECURITY DEFINER no banco que permite a um usuário ainda não-membro localizar um grupo por código de convite sem violar a política de RLS da tabela `groups`. |
| `approve_join_request` | `lib/repositories/group_members_repository.dart` | 186-189 | `{'request_id': requestId, 'existing_player_id': existingPlayerId}` | Aprova a solicitação de entrada na tabela `group_join_requests` e vincula o usuário solicitante ao jogador especificado ou cria um novo membro. |
| `reject_join_request` | `lib/repositories/group_members_repository.dart` | 193 | `{'request_id': requestId}` | Rejeita e atualiza o status da solicitação na tabela `group_join_requests`. |
| `claim_ghost_profile` | `lib/repositories/players_repository.dart` | 250 | *(Sem parâmetros)* | Vincula automaticamente o ID autenticado (`auth.uid()`) a qualquer jogador existente na tabela `players` cujo campo `email` coincida com o e-mail do usuário autenticado. |

### 3.2 Realtime e Subscriptions

| Tipo de Stream / Subscription | Arquivo | Linhas | Chamada no Código | O que a chamada faz |
|---|---|---|---|---|
| Auth State Change | `lib/main.dart` | 68 | `SupabaseConfig.client.auth.onAuthStateChange` | Escuta o stream de mudanças de sessão do Supabase Auth para alternar entre as telas `LoginScreen`, `CompleteProfileScreen` e `HomePage`. |
| Realtime Database (`.channel(`, `.stream(`, Postgres Changes) | — | — | *Nenhuma* | O aplicativo **não** possui nenhuma assinatura de banco de dados em tempo real (nenhum uso de `.channel()`, `.stream()` ou listen de Postgres Changes). |

---

## 4. Escrita em Múltiplas Tabelas na Mesma Operação

| Operação / Fluxo | Arquivo e Linhas | Tabelas Envolvidas | Como é feita hoje no código |
|---|---|---|---|
| Criação de Grupo (`createGroup`) | `lib/repositories/groups_repository.dart:75-138` | `groups`<br>`players`<br>`group_members`<br>`seasons` | Chamadas REST sequenciais sem transação: 1) `insert` em `groups`; 2) `select` em `players` e `insert` caso não exista jogador do criador; 3) `insert` em `group_members`; 4) `insert` em `seasons`. Falha intermediária deixa registros órfãos. |
| Salvar Partida Completa (`saveFullMatch`) | `lib/repositories/matches_repository.dart:193-269` | `matches`<br>`match_lineups`<br>`match_events`<br>`rating_history` | Chamadas REST sequenciais sem transação: 1) `insert` em `matches`; 2) `insert` em lote em `match_lineups`; 3) `insert` em lote em `match_events`; 4) `insert` em lote em `rating_history`. |
| Salvar Partida Pendente / Fila Outbox (`savePendingMatch`) | `lib/repositories/matches_repository.dart:164-190` | `matches`<br>`match_lineups`<br>`match_events` | 1) `upsert` na tabela `matches`; 2) Se for retry, executa `delete` em paralelo (`Future.wait`) em `match_lineups` e `match_events`; 3) Executa `insert` em paralelo (`Future.wait`) em `match_lineups` e `match_events`. Não utiliza transação SQL. |
| Atualizar Partida Completa (`updateFullMatch`) | `lib/repositories/matches_repository.dart:271-350` | `matches`<br>`match_events`<br>`match_lineups`<br>`rating_history` | Chamadas REST sequenciais: 1) `update` em `matches`; 2) `delete` em `match_events`, `match_lineups` e `rating_history`; 3) `insert` em `match_lineups`, `match_events` e `rating_history`. Não há atomicidade no banco. |
| Atualizar Partida Parcial (`updatePartialMatch`) | `lib/repositories/matches_repository.dart:352-381` | `matches`<br>`match_events` | Chamadas REST sequenciais: 1) `update` em `matches`; 2) `delete` em `match_events`; 3) `insert` em `match_events`; 4) `select` com joins para recarregar o modelo. |
| Exclusão de Partida (`deleteMatch`) | `lib/repositories/matches_repository.dart:383-388` | `match_events`<br>`match_lineups`<br>`rating_history`<br>`matches` | Executa 4 chamadas `delete` sequenciais via REST nas tabelas `match_events`, `match_lineups`, `rating_history` e `matches`. |
| Criação de Jogador Fantasma (`createGhostPlayer`) | `lib/repositories/players_repository.dart:89-116` | `players`<br>`group_members` | Chamadas REST sequenciais: 1) `insert` em `players`; 2) `insert` em `group_members` associando o ID retornado. |
| Criação de Jogador com Usuário (`createPlayerWithUser`) | `lib/repositories/players_repository.dart:119-148` | `players`<br>`group_members` | Chamadas REST sequenciais: 1) `insert` em `players` com `creator_id`; 2) `insert` em `group_members` com a role informada. |
| Definição de Som de Gol (`setGoalSound` e `clearGoalSound`) | `lib/repositories/players_repository.dart:186-216, 333-356` | `players`<br>`group_action_logs` | Chamadas REST sequenciais: 1) `update` na tabela `players`; 2) `insert` na tabela `group_action_logs` via `_logs.log` (envolvido em `try/catch` para não propagar erro caso a auditoria falhe). |
| Upload de Áudio de Gol (`uploadGoalSound`) | `lib/repositories/players_repository.dart:290-330` | Supabase Storage (`goal-sounds`)<br>`players`<br>`group_action_logs` | Sequencial: 1) `uploadBinary` no bucket de Storage; 2) `update` com a URL pública na tabela `players`; 3) `insert` na tabela `group_action_logs` via `_logs.log`. |
| Configuração de Cosméticos e Efeitos (`setNameEffect`, `setMonthlyHighlight`, `setCosmetics`, `setCommunityAttributes`, `setAdvancedStat`) | `lib/repositories/players_repository.dart:365-393, 397-422, 427-462, 470-516, 536-570` | `players`<br>`group_action_logs` | Sequencial: 1) `update` na tabela `players`; 2) `insert` na tabela `group_action_logs` via `_logs.log`. |
| Sincronização de Rascunho / Desistência / Placar (`_syncToCloud`) | `lib/screens/match_screen.dart:281-329` | `session_arrivals`<br>`sessions` | Disparado ao alterar placar, cronômetro, escalação ou registrar desistência de jogador: 1) `replaceArrivals` executa `delete` seguido de `insert` na tabela `session_arrivals`; 2) `updateRuntimeState` executa `update` na tabela `sessions`. |
| Migração de Dados do Backup JSON (`migrateJsonToSupabase`) | `lib/services/data_migration_service.dart:133-545` | `groups`<br>`players`<br>`group_members`<br>`seasons`<br>`sessions`<br>`matches`<br>`match_lineups`<br>`match_events`<br>`rating_history` | Inserções sequenciais em lote (`_insertInBatches`) executadas tabela por tabela via HTTP. Não há bloco transacional global. |

---

## 5. Telas e Serviços que Dependem de Role / Admin

### 5.1 Serviços e Métodos de Repositório

| Repositório / Serviço | Método | Arquivo e Linhas | Regra de Verificação | Operação Protegida |
|---|---|---|---|---|
| `GroupMembersRepository` | `isCurrentUserAdmin(String groupId)` | `lib/repositories/group_members_repository.dart:47-65` | Consulta `groups.creator_id == currentUserId` e `getMyMembership(groupId)?.isAdmin` (`role == 'admin'`). | Base de consulta de permissão para UI e métodos de escrita. |
| `GroupMembersRepository` | `promoteToAdmin(...)` | `lib/repositories/group_members_repository.dart:68-82` | Valida `await isCurrentUserAdmin(groupId)`. Lança exceção se `false`. | Atualiza `role` para `'admin'` em `group_members`. |
| `GroupMembersRepository` | `demoteToMember(...)` | `lib/repositories/group_members_repository.dart:85-99` | Valida `await isCurrentUserAdmin(groupId)`. Lança exceção se `false`. | Atualiza `role` para `'member'` em `group_members`. |
| `GroupMembersRepository` | `listPendingRequests(...)` | `lib/repositories/group_members_repository.dart:173-181` | Restrição aplicada no banco por política RLS em `group_join_requests`. | Consulta pedidos de entrada pendentes. |
| `GroupMembersRepository` | `approveRequest(...)` | `lib/repositories/group_members_repository.dart:185-190` | Restrição executada pela RPC `approve_join_request` no PostgreSQL. | Aprovação de solicitação de entrada. |
| `GroupMembersRepository` | `rejectRequest(...)` | `lib/repositories/group_members_repository.dart:192-194` | Restrição executada pela RPC `reject_join_request` no PostgreSQL. | Rejeição de solicitação de entrada. |
| `GroupsRepository` | `updateGroup(...)` | `lib/repositories/groups_repository.dart:142-156` | Valida `await _membersRepo.isCurrentUserAdmin(group.id)`. Lança exceção se `false`. | Atualiza dados do grupo na tabela `groups`. |
| `GroupsRepository` | `deleteGroup(...)` | `lib/repositories/groups_repository.dart:159-166` | Valida `await _membersRepo.isCurrentUserAdmin(groupId)`. Lança exceção se `false`. | Deleta o grupo na tabela `groups`. |
| `SeasonsRepository` | `createSeason(...)` | `lib/repositories/seasons_repository.dart:46-84` | Valida `await _membersRepo.isCurrentUserAdmin(groupId)`. Lança exceção se `false`. | Cria nova temporada na tabela `seasons`. |
| `SeasonsRepository` | `updateSeason(...)` | `lib/repositories/seasons_repository.dart:87-108` | Valida `await _membersRepo.isCurrentUserAdmin(season.groupId)`. Lança exceção se `false`. | Altera parâmetros de temporada na tabela `seasons`. |
| `SeasonsRepository` | `deleteSeason(...)` | `lib/repositories/seasons_repository.dart:111-121` | Valida `await _membersRepo.isCurrentUserAdmin(groupId)`. Lança exceção se `false`. | Deleta temporada na tabela `seasons`. |
| `PlayersRepository` | `uploadGoalSound(...)` | `lib/repositories/players_repository.dart:290-330` | Valida `await _membersRepo.isCurrentUserAdmin(groupId)`. Lança exceção se `false`. RLS no Storage. | Upload de áudio para bucket `goal-sounds` e vínculo a jogador. |
| `PlayersRepository` | `clearGoalSound(...)` | `lib/repositories/players_repository.dart:333-356` | Valida `await _membersRepo.isCurrentUserAdmin(groupId)`. Lança exceção se `false`. | Remove campo `goal_sound_url` na tabela `players`. |
| `PlayersRepository` | `setNameEffect(...)` | `lib/repositories/players_repository.dart:365-393` | Valida `await _membersRepo.isCurrentUserAdmin(groupId)`. Lança exceção se `false`. RLS no banco. | Atualiza `name_effect` na tabela `players`. |
| `PlayersRepository` | `setMonthlyHighlight(...)` | `lib/repositories/players_repository.dart:397-422` | Valida `await _membersRepo.isCurrentUserAdmin(groupId)`. Lança exceção se `false`. | Atualiza `monthly_highlight` na tabela `players`. |
| `PlayersRepository` | `setCosmetics(...)` | `lib/repositories/players_repository.dart:427-462` | Valida `await _membersRepo.isCurrentUserAdmin(groupId)`. Lança exceção se `false`. | Atualiza colunas cosméticas em `players`. |
| `PlayersRepository` | `setCommunityAttributes(...)` | `lib/repositories/players_repository.dart:470-516` | Valida `await _membersRepo.isCurrentUserAdmin(groupId)`. Lança exceção se `false`. RLS no banco. | Atualiza atributos da comunidade em `players`. |
| `PlayersRepository` | `setAdvancedStat(...)` | `lib/repositories/players_repository.dart:536-570` | Valida `await _membersRepo.isCurrentUserAdmin(groupId)`. Lança exceção se `false`. | Atualiza JSONB `advanced_stats` na tabela `players`. |
| `ActionLogsRepository` | `getRecentLogs(...)` | `lib/repositories/action_logs_repository.dart:47-61` | Restrito via RLS na tabela `group_action_logs` (somente admin lê). | Leitura de logs de auditoria administrativa. |
| `ActionLogsRepository` | `exportAndCleanOldLogs(...)` | `lib/repositories/action_logs_repository.dart:65-77` | Restrito pela definição da RPC `export_and_clean_action_logs`. | Exportação e limpeza de logs de auditoria. |

### 5.2 Telas da Aplicação

| Tela | Arquivo e Linhas | Verificação de Role / Admin | Elementos Condicionados |
|---|---|---|---|
| `GroupDashboardScreen` | `lib/screens/group_dashboard_screen.dart:49, 129-160` | Executa `isCurrentUserAdmin(widget.groupId)` e salva em `_isAdmin`. | Exibição do botão de configurações (engrenagem) na AppBar com acesso a: `ManageJoinRequestsScreen`, `ManageMembersScreen`, `ManageBadgesScreen`, `ManageSeasonsScreen`, `AdminDebugScreen` e diálogo de configurações locais. |
| `SessionsScreen` | `lib/screens/sessions_screen.dart:35-36, 163-164, 211-224` | Executa `isCurrentUserAdmin(widget.groupId)` e salva em `_isAdmin`. | 1) `FloatingActionButton` de criar nova pelada/sessão é exibido somente se `_isAdmin == true`; 2) Ações de editar (`onEdit`) e deletar (`onDelete`) peladas executam `_denyPermission` caso o usuário não seja admin. |
| `PlayersScreen` | `lib/screens/players_screen.dart:61-62, 436, 460, 495, 796-805` | Executa `isCurrentUserAdmin(widget.groupId)` e salva em `_isAdmin`. | 1) `FloatingActionButton` de adicionar jogador (fantasma) é exibido somente se `_isAdmin == true`; 2) Ação de toque longo e menu de exclusão de jogador (`removePlayerFromGroup`) só aparecem para admin. |
| `PlayerDetail` | `lib/screens/player_detail.dart:56, 110-112, 2625, 2762, 3350, 3740` | Executa `isCurrentUserAdmin(widget.groupId)` e salva em `_isAdmin`. | 1) Libera edição dos atributos da comunidade (PAC, SHO, PAS, DRI, DEF, PHY e Nota da Comunidade); 2) Exibe opções de atribuir badges manuais, efeitos visuais de nome, bola de ouro e craque do mês. |
| `ManageMembersScreen` | `lib/screens/manage_members_screen.dart:35, 57, 113-153` | Consulta `getMyMembership(widget.groupId)` e avalia `member.isAdmin` para cada membro da lista. | Exibe badges de Admin/Membro; exibe e opera o `Switch` de promoção (`promoteToAdmin`) e despromoção (`demoteToMember`). Bloqueia auto-alteração de role do usuário logado. |
| `ManageBadgesScreen` | `lib/screens/manage_badges_screen.dart:114, 126, 178, 451, 550, 555, 579, 615, 1009, 1103, 1112, 1370, 1448` | Executa `isCurrentUserAdmin(widget.groupId)` e salva em `_isAdmin`. | Protege todas as ações de concessão/revogação de badges manuais, aplicação de efeitos visuais de nome, definição de craque do mês e upload de áudios de gol. |
| `ManageJoinRequestsScreen` | `lib/screens/manage_join_requests_screen.dart:29, 47, 80` | Acessível apenas a partir do menu restrito a admin de `GroupDashboardScreen`. | Operações de listagem, aprovação e rejeição de solicitações de entrada no grupo. |
| `ManageSeasonsScreen` | `lib/screens/manage_seasons_screen.dart:1-200` | Acessível apenas a partir do menu restrito a admin de `GroupDashboardScreen`. | Criação, ativação, edição e exclusão de temporadas no grupo. |
| `AdminDebugScreen` | `lib/screens/admin_debug_screen.dart:84-180` | Acessível apenas a partir do menu restrito a admin de `GroupDashboardScreen`. | Diagnóstico de conexão Supabase, inspeção do storage local e disparo de limpeza de logs (`exportAndCleanOldLogs`). |

---

## 6. Dependências do `pubspec.yaml` e Restrições de Plataforma (Web)

### 6.1 Tabela de Dependências do `pubspec.yaml`

| Pacote | Versão | Status no Web | Arquivos Onde é Utilizado | Restrição ou Ponto de Quebra no Web |
|---|---|---|---|---|
| `path_provider` | `^2.1.4` | **Incompatível** | `lib/services/sync_service.dart:6, 146`<br>`lib/screens/ranking_screen.dart:10, 637`<br>`lib/screens/history_screen.dart:6, 153`<br>`lib/screens/group_ranking_screen.dart:11, 1765` | Lança exceção (`MissingPluginException` / `UnsupportedError`) no Web em chamadas a `getTemporaryDirectory()` e `getApplicationDocumentsDirectory()`, pois o navegador não expõe diretórios de sistema de arquivos local. |
| `file_picker` | `^11.0.2` | **Incompatível no fluxo atual** | `lib/services/sync_service.dart:8, 160-165` | Na Web, `FilePicker.pickFiles` não preenche o campo `path` (`result.files.single.path` é sempre `null`), fornecendo apenas `bytes`. A linha 165 executa `File(result.files.single.path!)`, gerando erro de Null Check Operator (`!`) e quebra por uso de `dart:io.File`. |
| `screenshot` | `^3.0.0` | **Suporte parcial com quebra no pós-processamento** | `lib/screens/ranking_screen.dart:8, 42, 634`<br>`lib/screens/group_ranking_screen.dart:10, 44, 1761` | A captura por `RenderRepaintBoundary.toImage()` na Web pode ser bloqueada por CORS se houver imagens externas no canvas. Além disso, o fluxo do app após a captura tenta gravar em disco usando `getTemporaryDirectory()` e `dart:io.File` (linhas 637-640 em `ranking_screen.dart` e 1765-1770 em `group_ranking_screen.dart`), quebrando no Web. |
| `share_plus` | `^10.1.0` | **Suporte limitado** | `lib/services/sync_service.dart:7, 150`<br>`lib/screens/ranking_screen.dart:642`<br>`lib/screens/history_screen.dart:158`<br>`lib/screens/group_ranking_screen.dart:1774` | Depende da Web Share API (`navigator.share`). Em navegadores desktop sem suporte à API ou em conexões não-seguras (sem HTTPS), a chamada falha. Além disso, as chamadas no código passam caminhos de `dart:io.File` (`XFile(file.path)`), inexistentes no Web. |
| `audioplayers` | `^6.0.0` | **Suporte limitado por políticas de navegador** | `lib/screens/player_detail.dart:9`<br>`lib/screens/manage_badges_screen.dart:6`<br>`lib/screens/match_screen.dart:5`<br>`lib/screens/blank_screen.dart:2` | No Web, navegadores bloqueiam reprodução automática de áudio (autoplay policy) antes de uma interação física do usuário (clique) no documento. O comportamento com streams e áudios remotos em formatos específicos pode variar entre navegadores. |
| `shared_preferences` | `^2.2.2` | **Compatível com limite de armazenamento** | Usado em múltiplos serviços e telas para persistência local | No Web, utiliza `window.localStorage`, que impõe limite rígido de aproximadamente 5 MB por domínio. Backups completos em JSON ou dumps de histórico correm risco de estourar a quota. |
| `supabase_flutter` | `^2.8.0` | **Compatível** | `lib/config/supabase_config.dart`, repositórios e serviços | Compatível com Web (utiliza clientes HTTP e WebSocket da Web, e gerencia sessão de autenticação via browser storage). |
| `uuid` | `^4.5.1` | **Compatível** | `lib/repositories/`, `lib/services/` | Pacote Dart puro, totalmente funcional em qualquer plataforma. |
| `intl` | `^0.20.2` | **Compatível** | `lib/utils/`, `lib/screens/` | Pacote Dart puro para internacionalização e datas. |
| `collection` | `^1.19.1` | **Compatível** | Múltiplos arquivos | Pacote Dart puro de utilitários de coleções. |
| `cupertino_icons` | `^1.0.8` | **Compatível** | `pubspec.yaml` | Fonte de ícones empacotada como asset. |
| `flutter_rating_bar` | `^4.0.1` | **Compatível** | `lib/screens/` | Widgets Flutter puros baseados em Canvas/RenderBox. |
| `fl_chart` | `^1.2.0` | **Compatível** | `lib/screens/` | Gráficos baseados em `CustomPainter` do Flutter. |

### 6.2 Uso Direto de `dart:io` que Impede a Compilação/Execução na Web

Além dos pacotes, o código-fonte importa e utiliza a biblioteca `dart:io` diretamente nos seguintes arquivos, impedindo a execução no ambiente Web:

| Arquivo | Linha | Uso de `dart:io` | Efeito no Web |
|---|---|---|---|
| `lib/services/data_migration_service.dart` | 2 | `import 'dart:io';`<br>Linha 31: `File(backupJsonPath)` | Falha de compilação ou execução em runtime Web ao instanciar `File`. |
| `lib/services/sync_service.dart` | 2 | `import 'dart:io';`<br>Linhas 147, 165: `File(...)` | Falha de execução na Web ao tentar ler/gravar arquivos com `dart:io.File`. |
| `lib/services/fix_event_times_service.dart` | 2 | `import 'dart:io';`<br>Linha 30: `File(backupJsonPath)` | Falha de compilação ou execução no Web ao instanciar `File`. |
| `lib/screens/ranking_screen.dart` | 9 | `import 'dart:io';`<br>Linha 638: `File('${dir.path}/...').writeAsBytes(...)` | Falha de execução ao gravar imagem de screenshot em disco no Web. |
| `lib/screens/history_screen.dart` | 2 | `import 'dart:io';`<br>Linha 154: `File('${directory.path}/...').writeAsString(...)` | Falha de execução ao exportar backup de histórico para arquivo no Web. |
| `lib/screens/group_ranking_screen.dart` | 3 | `import 'dart:io';`<br>Linha 1766: `File('${directory.path}/...').writeAsBytes(...)` | Falha de execução ao salvar screenshot para compartilhamento no Web. |
