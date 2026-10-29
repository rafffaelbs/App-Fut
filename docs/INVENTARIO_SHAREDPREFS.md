# INVENTARIO_SHAREDPREFS.md — Inventário Completo de SharedPreferences

> Documento gerado na tarefa **T0d** (somente leitura, sem alterações em `lib/`).
> Mapeamento de 100% das chaves, métodos (`getString`, `setString`, `getInt`, `setInt`, `getBool`, `setBool`, `remove`, `containsKey`, `getStringList`, `setStringList`, `getKeys`), arquivos e linhas de leitura/escrita, conteúdos e categorias no aplicativo.

---

## 1. Categorias de Armazenamento

Conforme especificação da tarefa, cada chave ou prefixo está categorizado em:
* **(a)** Cache de algo que também existe no Supabase
* **(b)** Estado temporário de partida em andamento
* **(c)** Fila de envio ("outbox")
* **(d)** Preferência de configuração
* **(e)** Dado que SÓ existe localmente (não está no Supabase)

---

## 2. Tabela Geral de Chaves e Prefixos

| Chave / Prefixo | Categoria | Quem Escreve (Arquivo:Linha) | Quem Lê (Arquivo:Linha) | Quem Remove (Arquivo:Linha) | O que contém |
|---|---|---|---|---|---|
| `cache:*`<br>*(prefixo via `CacheStore`)* | **(a)** | `lib/services/cache_store.dart:28`<br>*(chamadores:<br>`matches_repo:64, 131`<br>`sessions_repo:29, 84`<br>`players_repo:59, 77`)* | `lib/services/cache_store.dart:35`<br>*(chamadores:<br>`matches_repo:68, 139`<br>`sessions_repo:20, 90`<br>`players_repo:64, 80`)* | `lib/services/cache_store.dart:52` (`invalidate`),<br>`61` (`clearAll`) | Envelope JSON `{'value': ..., 'cachedAt': ISO-8601}` com partidas, sessões ou jogadores vindos do Supabase. |
| `pending_matches_v1` | **(c)** | `lib/services/pending_match_queue.dart:45`<br>*(chamadores: L63 em `enqueue`, L102 e L113 em `flush`)* | `lib/services/pending_match_queue.dart:32`<br>*(chamadores: L54 em `readAll`, L62 em `enqueue`, L76, 79, 100, 107 em `flush`)* | — | Lista JSON de jobs de partidas finalizadas aguardando envio (`match_id`, `match`, `lineups`, `events`, `attempts`). |
| `players_$groupId`<br>*(prefixo `players_`)* | **(a)** | `lib/services/group_bootstrap.dart:110`<br>`lib/screens/match_screen.dart:2806`<br>`lib/screens/player_detail.dart:995, 1023, 1076, 1392, 2061`<br>`lib/screens/manage_badges_screen.dart:150`<br>`lib/services/sync_service.dart:105` | `lib/services/group_bootstrap.dart:58`<br>`lib/screens/match_screen.dart:343, 361`<br>`lib/screens/ranking_screen.dart:107`<br>`lib/screens/group_ranking_screen.dart:107`<br>`lib/screens/player_comparison_screen.dart:56`<br>`lib/screens/edit_match_screen.dart:54`<br>`lib/screens/player_detail.dart:155, 975, 988, 1016, 1070, 1379, 2047`<br>`lib/screens/manage_badges_screen.dart:108, 144`<br>`lib/utils/site_data_generator.dart:75`<br>`lib/services/sync_service.dart:88`<br>`tool/legacy/data_migration_service.dart:158` | — | Lista JSON do elenco do grupo com dados do jogador e campos calculados (`id`, `name`, `icon`, `rating`, `overall`, `goal_sound_url`, `name_effect`, `monthly_highlight`, `manual_badges`, `advanced_stats`, `craque_mes_count`, `community_*`). |
| `ratings_snapshot_at_$groupId`<br>*(prefixo `ratings_snapshot_at_`)* | **(e)** | `lib/services/group_bootstrap.dart:112` | *Nenhum leitor direto em tempo de execução* (apenas inspeção genérica de storage em `admin_debug_screen.dart:105` e export em `sync_service.dart:24`) | — | String ISO 8601 com o timestamp do cálculo das notas e overall do elenco pelo `GroupBootstrap`. |
| `match_history_$id`<br>*(prefixo `match_history_`, onde `$id` é o `session_id`)* | **(e)** | `lib/screens/match_screen.dart:3647`<br>`lib/services/sync_service.dart:174, 210` | `lib/screens/group_ranking_screen.dart:176`<br>`lib/screens/ranking_screen.dart:179`<br>`lib/screens/match_screen.dart:573, 3641`<br>`lib/utils/stats_calculator.dart:109`<br>`lib/utils/site_data_generator.dart:60`<br>`lib/services/sync_service.dart:139, 208`<br>`tool/legacy/data_migration_service.dart:196, 418`<br>`tool/legacy/fix_event_times_service.dart:42` | `lib/services/sync_service.dart:211` *(ao migrar ID antigo de sessão)* | Lista JSON de partidas jogadas na sessão/pelada (súmula local completa com times `red`/`white`, placar, duração, horário e eventos com minuto/autor/assistência). |
| `present_players_$id` | **(b)** | `lib/screens/match_screen.dart:228, 402`<br>`lib/services/sync_service.dart:125` | `lib/screens/match_screen.dart:376, 453`<br>`lib/screens/edit_match_screen.dart:77`<br>`lib/utils/site_data_generator.dart:217`<br>`lib/services/sync_service.dart:109, 128` | — | Lista JSON de jogadores confirmados na pelada (inclui flag `desistiu: true/false`). |
| `team_red_$id` | **(b)** | `lib/screens/match_screen.dart:229, 404`<br>`lib/services/sync_service.dart:125` | `lib/screens/match_screen.dart:459`<br>`lib/utils/site_data_generator.dart:211`<br>`lib/services/sync_service.dart:109, 131` | — | Lista JSON com jogadores escalados no time vermelho. |
| `team_white_$id` | **(b)** | `lib/screens/match_screen.dart:230, 405`<br>`lib/services/sync_service.dart:125` | `lib/screens/match_screen.dart:465`<br>`lib/utils/site_data_generator.dart:214`<br>`lib/services/sync_service.dart:109, 134` | — | Lista JSON com jogadores escalados no time branco. |
| `score_red_$id` | **(b)** | `lib/screens/match_screen.dart:231, 421` | `lib/screens/match_screen.dart:507` | — | `int`: Placar atual do time vermelho. |
| `score_white_$id` | **(b)** | `lib/screens/match_screen.dart:232, 423` | `lib/screens/match_screen.dart:508` | — | `int`: Placar atual do time branco. |
| `match_events_$id` | **(b)** | `lib/screens/match_screen.dart:233` | `lib/screens/match_screen.dart:468, 470` | — | Lista JSON dos eventos da partida em andamento (gols, assistências, cartões, etc.). |
| `is_overtime_$id` | **(b)** | `lib/screens/match_screen.dart:234, 429` | `lib/screens/match_screen.dart:511` | — | `bool`: Indica se a partida em andamento está em prorrogação. |
| `seconds_played_$id` | **(b)** | `lib/screens/match_screen.dart:235, 418` | `lib/screens/match_screen.dart:512` | — | `int`: Total de segundos jogados antes da última pausa ou encerramento. |
| `is_running_$id` | **(b)** | `lib/screens/match_screen.dart:236, 419` | `lib/screens/match_screen.dart:513` | — | `bool`: Indica se o cronômetro da partida está correndo. |
| `start_timestamp_$id` | **(b)** | `lib/screens/match_screen.dart:240` | `lib/screens/match_screen.dart:515` | `lib/screens/match_screen.dart:244, 433` *(remove ao pausar ou ao restaurar da nuvem)* | String ISO 8601 com horário de início da contagem atual do cronômetro. |
| `red_streak_$id` | **(b)** | `lib/screens/match_screen.dart:247, 425` | `lib/screens/match_screen.dart:509` | — | `int`: Vitórias consecutivas do time vermelho na pelada. |
| `white_streak_$id` | **(b)** | `lib/screens/match_screen.dart:248, 427` | `lib/screens/match_screen.dart:510` | — | `int`: Vitórias consecutivas do time branco na pelada. |
| `active_gk_red_$id` | **(b)** | `lib/screens/match_screen.dart:250` | `lib/screens/match_screen.dart:518` | `lib/screens/match_screen.dart:251` *(remove quando null)* | JSON Map do goleiro ativo no time vermelho. |
| `active_gk_white_$id` | **(b)** | `lib/screens/match_screen.dart:252` | `lib/screens/match_screen.dart:519` | `lib/screens/match_screen.dart:253` *(remove quando null)* | JSON Map do goleiro ativo no time branco. |
| `first_gk_red_$id` | **(b)** | `lib/screens/match_screen.dart:254` | `lib/screens/match_screen.dart:520` | `lib/screens/match_screen.dart:255` *(remove quando null)* | JSON Map do primeiro goleiro do time vermelho no jogo (rodízio). |
| `first_gk_white_$id` | **(b)** | `lib/screens/match_screen.dart:256` | `lib/screens/match_screen.dart:521` | `lib/screens/match_screen.dart:257` *(remove quando null)* | JSON Map do primeiro goleiro do time branco no jogo (rodízio). |
| `show_radar_chart` | **(d)** | `lib/screens/group_dashboard_screen.dart:187` | `lib/screens/group_dashboard_screen.dart:168`<br>`lib/screens/player_comparison_screen.dart:52`<br>`lib/screens/player_detail.dart:119` | — | `bool` (default true): Exibir gráfico radar no perfil do jogador e na comparação X1. |
| `confirm_timer_enabled`<br>*(const `kPrefConfirmTimerEnabled`)* | **(d)** | `lib/screens/group_dashboard_screen.dart:197`<br>`lib/screens/match_screen.dart:1676` | `lib/screens/group_dashboard_screen.dart:171`<br>`lib/screens/match_screen.dart:340` | — | `bool` (default true): Bloqueia o botão de confirmar encerramento de partida por 3 segundos. |
| `pitch_use_cards` | **(d)** | `lib/screens/group_dashboard_screen.dart:207`<br>`lib/screens/match_screen.dart:1639` | `lib/screens/group_dashboard_screen.dart:169`<br>`lib/screens/match_screen.dart:336` | — | `bool`: Exibir cards estilo FIFA no campinho tático em vez de chips. |
| `pitch_use_chips` | **(d)** | `lib/screens/group_dashboard_screen.dart:208`<br>`lib/screens/match_screen.dart:1640` | `lib/screens/group_dashboard_screen.dart:170`<br>`lib/screens/match_screen.dart:337` | — | `bool`: Inverso de `pitch_use_cards` (fallback legado de UI). |
| `require_gk` | **(d)** | `lib/screens/match_screen.dart:1658` | `lib/screens/match_screen.dart:339` | — | `bool` (default true): Exige goleiros definidos para iniciar a partida. |
| `show_tactical_pitch` | **(d)** | `lib/screens/match_screen.dart:2399` | `lib/screens/match_screen.dart:335` | — | `bool` (default true): Visibilidade do campinho tático na tela de partida. |
| `my_sync_code` | **(d)** | `lib/services/sync_service.dart:74` | `lib/services/sync_service.dart:48`<br>`lib/screens/admin_debug_screen.dart:39` | — | `String`: Código alfanumérico (ex.: `SNC1234`) para o pacote de sync no Supabase. |
| `cache_has_pending_cloud_sync`<br>*(const `keyHasPendingChanges`)* | **(e)** | `lib/services/cache_sync_manager.dart:39, 45, 52` | `lib/services/cache_sync_manager.dart:83` | — | `bool`: Indicador de pendências de upload do sync legado. |
| `cache_last_cloud_sync_at`<br>*(const `keyLastCloudSyncAt`)* | **(e)** | `lib/services/cache_sync_manager.dart:46` | `lib/services/cache_sync_manager.dart:84` | — | String ISO 8601 do último upload realizado pelo sync legado. |
| `cache_last_cloud_fetch_at`<br>*(const `keyLastCloudFetchAt`)* | **(e)** | `lib/services/cache_sync_manager.dart:53` | `lib/services/cache_sync_manager.dart:85` | — | String ISO 8601 do último download realizado pelo sync legado. |
| `sync_history` | **(e)** | `lib/screens/match_screen.dart:4021` | `lib/screens/match_screen.dart:4013` | — | `List<String>`: Histórico de execuções do sync em background (`timestamp\|success[\|error]`). |
| `custom_badges_$groupId`<br>*(prefixo `custom_badges_`)* | **(e)** | `lib/screens/manage_badges_screen.dart:1150` | `lib/screens/manage_badges_screen.dart:79, 82`<br>`lib/screens/player_detail.dart:176, 179, 1817, 1819` | — | Lista JSON de insígnias customizadas criadas no grupo (`id`, `title`, `desc`, `icon`, `created_at`). |
| `sessions_$groupId`<br>*(prefixo `sessions_`)* | **(e)** / legada | `lib/services/sync_service.dart:221`<br>*(nenhuma tela escreve)* | `lib/screens/group_ranking_screen.dart:126`<br>`lib/screens/match_screen.dart:474`<br>`lib/utils/stats_calculator.dart:100`<br>`lib/utils/site_data_generator.dart:40`<br>`lib/services/sync_service.dart:183`<br>`tool/legacy/data_migration_service.dart:354` | — | Lista JSON de peladas/sessões legadas do grupo (`id`, `title`, `timestamp`, `status`, `win_limit`, etc.). |
| `seasons_$groupId`<br>*(prefixo `seasons_`)* | **(e)** / legada | *Nenhum escritor no código* | `lib/screens/group_ranking_screen.dart:116`<br>`lib/utils/stats_calculator.dart:124`<br>`lib/utils/site_data_generator.dart:46`<br>`tool/legacy/data_migration_service.dart:290` | — | Lista JSON de temporadas legadas do grupo (`id`, `name`, `startDate`, `endDate`). |
| `app_groups` | **(e)** / legada | *Nenhum escritor no código* | `lib/utils/site_data_generator.dart:16`<br>`tool/legacy/data_migration_service.dart:112` | — | Lista JSON de grupos locais legados pré-Supabase. |
| `players_grupo_` | **(e)** / legada | *Nenhum escritor no código* | `lib/utils/site_data_generator.dart:27` | — | Variação legada de chave de grupo pré-Supabase. |

---

## 3. Respostas às Perguntas Obrigatórias

### Pergunta 1: Quais telas leem `match_history_*` (histórico local) em vez de repositórios?

1. **`lib/screens/group_ranking_screen.dart` (linhas 173–176)**:
   * No método `_calculateGlobalRankings()`, lê diretamente `match_history_$tournamentId` de `SharedPreferences` para cada sessão listada em `_allSessions`.
   * **Não consulta nenhum repositório.** O histórico local é a **única** fonte de dados de partidas para calcular todo o ranking geral do grupo, gols, assistências, vitórias e notas.
2. **`lib/screens/ranking_screen.dart` (linhas 177–180)**:
   * No método `_loadData()`, tenta primeiro carregar via `MatchesRepository.getMatchesBySession(widget.tournamentId)` (linhas 132–174).
   * Se a lista retornada for vazia (`history.isEmpty`), executa fallback lendo `match_history_${widget.tournamentId}` de `SharedPreferences`.
3. **`lib/screens/match_screen.dart` (linhas 571–573)**:
   * No método `_loadSessionMatches()`, tenta primeiro carregar via `MatchesRepository.getMatchesBySession(widget.tournamentId)` (linha 554).
   * Se a chamada falhar ou a lista for vazia, executa fallback lendo `match_history_${widget.tournamentId}` de `SharedPreferences` para preencher `_finishedMatches` (utilizado no cálculo de rotação da fila de espera e tempo de banco dos jogadores).

*(Nota: Fora da pasta `lib/screens/`, a função utilitária `getAllGroupMatches` em `lib/utils/stats_calculator.dart:106–109` e o gerador de dados do site em `lib/utils/site_data_generator.dart:57–60` também leem `match_history_*` diretamente do `SharedPreferences`).*

---

### Pergunta 2: Onde `rating_history` é gravado no fluxo de finalizar partida (`savePendingMatch` não grava `rating_history`)? Quem chama `recordRatingsBatch`, `saveFullMatch` e `updateFullMatch`, e quando?

#### Onde `rating_history` é gravado no fluxo de finalizar partida:
* **EM LUGAR NENHUM.**
* Quando o usuário finaliza uma partida (`lib/screens/match_screen.dart:3345–3490`, método `_finishMatch()`), o app executa:
  1. `_writeMatchState()` (linha 3362)
  2. `PendingMatchQueue.instance.enqueue(...)` (linha 3418)
  3. `unawaited(_appendLocalHistory(matchRecord))` (linha 3434)
* O job enfileirado no `PendingMatchQueue` é processado em `flush()` (`lib/services/pending_match_queue.dart:86`), que invoca exclusivamente `MatchesRepository.savePendingMatch(...)`.
* Por sua vez, `MatchesRepository.savePendingMatch(...)` (`lib/repositories/matches_repository.dart:164–190`) grava **apenas** nas tabelas `matches`, `match_lineups` e `match_events`.
* Portanto, no fluxo atual de finalização de partida em produção, **nenhum registro é inserido na tabela `rating_history`**. As notas são calculadas dinamicamente em memória pelos calculators (`rating_calculator.dart` e `stats_calculator.dart`) a partir dos eventos e súmulas das partidas.

#### Quem chama `recordRatingsBatch`, `saveFullMatch` e `updateFullMatch`, e quando:
1. **`recordRatingsBatch`** (`lib/repositories/ratings_repository.dart:65–71`):
   * **Chamado por NINGUÉM.** Não existe nenhuma chamada a este método em todo o repositório (`0` referências). É código morto (*dead code*).
2. **`saveFullMatch`** (`lib/repositories/matches_repository.dart:193–269`):
   * **Chamado por NINGUÉM.** Não existe nenhuma chamada a este método em todo o repositório (`0` referências). É código morto (*dead code*).
3. **`updateFullMatch`** (`lib/repositories/matches_repository.dart:271–350`):
   * **Chamado por NINGUÉM.** Não existe nenhuma chamada a este método em todo o repositório (`0` referências). É código morto (*dead code*).
   * A tela de edição de partida (`lib/screens/edit_match_screen.dart:450`) chama `updatePartialMatch(...)`, que atualiza `matches` e `match_events`, mas **não** toca em `rating_history`.

*(Nota: O único local do projeto onde `rating_history` foi alimentado foi durante a migração inicial de dados legados em `tool/legacy/data_migration_service.dart:540`. A única operação ativa que toca na tabela `rating_history` é a exclusão via `MatchesRepository.deleteMatch` na linha 386, disparada ao excluir partida em `lib/screens/history_screen.dart:181`).*

---

### Pergunta 3: Existe algum dado exibido nas telas que NÃO venha de repositório (só de SharedPreferences)?

**SIM.** Existem dados exibidos na interface do usuário que não passam por nenhum repositório e são obtidos exclusivamente de `SharedPreferences`:

1. **`GroupRankingScreen` (`lib/screens/group_ranking_screen.dart`)**:
   * **Histórico completo de partidas e estatísticas**: Toda a tabela de classificação (jogos, vitórias, empates, derrotas, gols, assistências, notas médias e pontuação) e os pontos do gráfico de evolução são calculados a partir de `match_history_$tournamentId` (`SharedPreferences`, linha 176).
   * **Elenco e ícones dos jogadores**: Carregados diretamente de `players_${widget.groupId}` (`SharedPreferences`, linha 107).
   * **Filtro de Temporadas**: As opções de temporadas do seletor vêm de `seasons_${widget.groupId}` (`SharedPreferences`, linha 116).
   * **Lista de Peladas/Sessões**: O agrupamento de sessões vem de `sessions_${widget.groupId}` (`SharedPreferences`, linha 126).
   * *Nenhum dado exibido nesta tela vem de repositório.*

2. **`ManageBadgesScreen` (`lib/screens/manage_badges_screen.dart`)**:
   * **Lista de Insígnias Customizadas do Grupo**: A lista de badges customizados criada pelo admin é lida exclusivamente da chave `custom_badges_${widget.groupId}` (`SharedPreferences`, linhas 78–84) e renderizada na UI. Não existe tabela no Supabase nem repositório para essas insígnias.

3. **`PlayerDetail` (`lib/screens/player_detail.dart`)**:
   * **Insígnias Customizadas disponíveis para atribuição**: Lidas de `custom_badges_${widget.groupId}` (`SharedPreferences`, linhas 175–179 e 1814–1819) e exibidas no diálogo de badges do jogador.
   * **Exibição do Gráfico Radar de Atributos**: Condicionada ao valor booleano lido de `show_radar_chart` (`SharedPreferences`, linha 119).
   * **Fallback de dados do jogador**: Caso o Supabase falhe, nome, ícone, overall, nota e atributos vêm de `players_${widget.groupId}` (`SharedPreferences`, linhas 152–155 e 973).

4. **`PlayerComparisonScreen` (`lib/screens/player_comparison_screen.dart`)**:
   * **Lista de Jogadores para Comparação X1**: A lista de jogadores nos menus suspensos (dropdowns) é carregada diretamente de `players_${widget.groupId}` (`SharedPreferences`, linhas 50–57).
   * **Exibição do Gráfico Radar**: Condicionada a `show_radar_chart` (`SharedPreferences`, linha 52).

5. **`MatchScreen` (`lib/screens/match_screen.dart`)**:
   * **Estado em Andamento ao Vivo**: Placar atual (`score_red_`, `score_white_`), cronômetro (`seconds_played_`, `is_running_`, `start_timestamp_`), prorrogação (`is_overtime_`), times em campo (`team_red_`, `team_white_`), presentes (`present_players_`), súmula de eventos em tempo real (`match_events_`), goleiros ativos (`active_gk_*`, `first_gk_*`) e sequências (`red_streak_`, `white_streak_`) são todos lidos de `SharedPreferences` (linhas 450–525).
   * **Preferências Visuais e Operacionais**:
     * Visualização do campinho tático: `show_tactical_pitch` (linha 335).
     * Estilo dos jogadores em campo (Cards FIFA vs. Chips): `pitch_use_cards` e `pitch_use_chips` (linhas 336–337).
     * Obrigatoriedade de goleiro para início: `require_gk` (linha 339).
     * Delay de 3s no botão confirmar: `confirm_timer_enabled` (linha 340).
   * **Histórico de Logs de Sincronização**: Exibido no modal/banner via `sync_history` (linha 4013).
   * **Fila de Espera / Banco de Reservas**: Quando a busca remota de partidas da sessão não retorna nada, lê `match_history_${widget.tournamentId}` (`SharedPreferences`, linha 573) para calcular o descanso dos jogadores.

6. **`RankingScreen` (`lib/screens/ranking_screen.dart`)**:
   * **Fallback de Partidas e Ranking da Sessão**: Se o Supabase não retornar partidas, toda a tabela da sessão é renderizada a partir de `match_history_${widget.tournamentId}` (`SharedPreferences`, linhas 177–180).
   * **Fallback de Metadados**: Se os metadados dos jogadores não vierem da sessão, ícones e efeitos visuais são lidos de `players_${widget.groupId}` (`SharedPreferences`, linhas 107–128).

7. **`EditMatchScreen` (`lib/screens/edit_match_screen.dart`)**:
   * **Lista de Jogadores para Autocomplete/Seleção**: Lida prioritariamente de `players_${widget.groupId}` (linha 54) e `present_players_${widget.tournamentId}` (linha 77) de `SharedPreferences`.

8. **`AdminDebugScreen` (`lib/screens/admin_debug_screen.dart`)**:
   * **Painel de Inspeção do Storage**: Exibe a contagem total de chaves e os valores brutos salvos no `SharedPreferences` (linhas 36–38, 226, 255) e `my_sync_code` (linha 39).
