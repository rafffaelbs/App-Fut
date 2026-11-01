# DUVIDAS.md — Registro de Dúvidas e Achados

Este documento registra comportamentos inesperados, inconsistências nas fórmulas ou funções não testáveis em testes unitários puros encontradas durante o desenvolvimento e criação dos testes de caracterização. Nenhuma decisão ou alteração de fórmula foi tomada por conta própria, seguindo as regras do projeto.

---

### 1. `lib/utils/rating_calculator.dart` (linhas 385–395)
- **O que viu:** Na função `findSpecialGoals`, a condição para detectar o gol da virada (`comebackIndex`) é:
  ```dart
  if (redScored && beforeRed < beforeWhite && scoreRed > scoreWhite && !redEverLed) {
    comebackIndex = i;
  }
  ```
  (e idêntica para o time Branco).
- **Impacto:** Como cada evento de gol adiciona exatamente 1 ponto ao placar (`scoreRed = beforeRed + 1`), se o time estava perdendo antes do gol (`beforeRed < beforeWhite`), o valor máximo possível após o gol é o empate (`scoreRed == beforeWhite`). É matematicamente impossível que um gol unitário faça `scoreRed > beforeWhite`. Consequentemente, `comebackIndex` nunca é atribuído e sempre retorna `-1`.
- **Ação no teste:** O teste de caracterização preservou e congelou o valor atual (`-1`).

---

### 2. `lib/utils/rating_calculator.dart` (linha 177)
- **O que viu:**
  ```dart
  final double teamGoalBonus = teamGoals > 0 ? kBonusTeamGoal : 0.0; // desativado (0.0)
  ```
  O comentário indica `// desativado (0.0)`, porém na linha 52 a constante está definida como `const double kBonusTeamGoal = 0.1;` (com o comentário: `Ativado para ajudar aqueles que ajudaram mas nao puderam nem fazer gol ou assist`).
- **Impacto:** O código está ativo e somando `0.1` ponderado pelo multiplicador de pressão a cada partida com `teamGoals > 0`.
- **Ação no teste:** O teste de caracterização registrou a soma de `0.1` ativa.

---

### 3. `lib/utils/stats_calculator.dart` (linhas 13–93)
- **O que viu:** A função pública `getAllGroupMatches(String groupId)` instancia diretamente repositórios Supabase (`MatchesRepository()` e `PlayersRepository()`) e usa `SharedPreferences.getInstance()` como fallback em caso de exceção.
- **Impacto:** Não é testável em teste de unidade puro sem Flutter binding e sem mock/serviço Supabase.
- **Ação no teste:** Registrada aqui conforme regra: *"Se alguma função não for testável sem Flutter binding ou Supabase, anote no DUVIDAS.md"*.

---

### 4. `lib/utils/stats_calculator.dart` (linhas 306–310 e 321–322)
- **O que viu:** Em `calculateGlobalStats`, o processamento de goleiros (`gk_red` e `gk_white`) chama a closure interna `processPlayer`:
  ```dart
  if (match['players']['gk_red'] != null) processPlayer(match['players']['gk_red'], redStatus, scoreRed, scoreWhite, redAvg, whiteAvg);
  if (match['players']['gk_white'] != null) processPlayer(match['players']['gk_white'], whiteStatus, scoreWhite, scoreRed, whiteAvg, redAvg);
  ```
  E dentro de `processPlayer` (linha 306), o rating da partida é calculado chamando `calculateMatchRating(...)` em vez de `calculateGkMatchRating(...)`.
- **Impacto:** A fórmula específica de goleiro (`calculateGkMatchRating`, que ignora resultado da partida e dá peso menor a gols sofridos) não é utilizada no cálculo das notas globais em `calculateGlobalStats`.
- **Ação no teste:** O teste de caracterização congelou o comportamento atual.

---

### 5. `lib/utils/stats_calculator.dart` (linha 309)
- **O que viu:** Em `calculateGlobalStats`, a chamada para `calculateMatchRating` passa `teamWinStreak: 0` fixo:
  ```dart
  teamWinStreak: 0, teamAvgRating: teamAvg, opponentAvgRating: oppAvg
  ```
- **Impacto:** O bônus de sequência de vitórias (2 vitórias ou 3+ vitórias) nunca é aplicado no cômputo global das notas ao longo das partidas.
- **Ação no teste:** Congelado no teste de caracterização.

---

### 6. `lib/utils/stats_calculator.dart` (linhas 293–311)
- **O que viu:** Em `calculateGlobalStats`, quando `match['isExactCurrentSeason'] == false`, os contadores de jogos, vitórias, derrotas, gols e assistências não são incrementados (linhas 293–304). Porém, a linha 311 adiciona a nota da partida a `playerStats['ratings']` incondicionalmente:
  ```dart
  final double matchRating = calculateMatchRating(...);
  (playerStats['ratings'] as List<double>).add(matchRating);
  ```
- **Impacto:** Partidas que não pertencem à temporada exata atual não contam como jogos jogados (`games == 0`), mas impactam a `nota` final do jogador.
- **Ação no teste:** Congelado no teste de caracterização.

---

### 7. `lib/main.dart` (linhas 191–260 e 497–502) — Tarefa T0b
- **O que viu:** O drawer do `main.dart` continha o botão "Corrigir Tempos", que executava `FixEventTimesService().run(...)` com um caminho absoluto local hardcoded (`/home/marinho/Documents/github/App-Fut/pelada_backup_1789226662128.json`).
- **Impacto:** Era o único ponto do app em `lib/` com dependência direta de `FixEventTimesService`.
- **Ação:** Com a confirmação de que os scripts de migração/correção não são mais usados, o método e o item do drawer foram removidos de `lib/main.dart`, e os arquivos foram movidos para `tool/legacy/`. Caso essa rotina ainda seja necessária como script manual, ela deve ser executada a partir de `tool/legacy/fix_event_times_service.dart`.

---

### 8. `lib/screens/group_ranking_screen.dart` (linhas 106–128 e 173–176) — Tarefa T0d
- **O que viu:** A tela `GroupRankingScreen` é alimentada exclusivamente por `SharedPreferences` (`players_$groupId`, `seasons_$groupId`, `sessions_$groupId` e `match_history_$tournamentId`) e não consulta nenhum repositório (`SessionsRepository`, `SeasonsRepository`, `MatchesRepository` ou `PlayersRepository`). Além disso, as chaves `seasons_$groupId` e `sessions_$groupId` não são mais gravadas em nenhuma tela ou repositório ativo (sessões e temporadas são salvas direto no Supabase).
- **Impacto:** Temporadas e peladas recém-criadas ou editadas no app não aparecem no `GroupRankingScreen`.
- **Ação:** Registrado no inventário `docs/INVENTARIO_SHAREDPREFS.md` e aguardando migração nas tarefas de repositórios/telas.

---

### 9. `lib/repositories/ratings_repository.dart` (linha 65) e `lib/repositories/matches_repository.dart` (linhas 193, 271) — Tarefa T0d
- **O que viu:** A tabela `rating_history` não é gravada no fluxo de encerramento de partidas (`_finishMatch` chama `PendingMatchQueue.enqueue`, que executa `savePendingMatch`, o qual grava apenas em `matches`, `match_lineups` e `match_events`). Os únicos métodos que gravam em `rating_history` no app (`recordRatingsBatch`, `saveFullMatch`, `updateFullMatch`) não são chamados em nenhum ponto do código (0 chamadores / código morto).
- **Impacto:** `rating_history` só continha dados da migração inicial legada (`tool/legacy/data_migration_service.dart:540`). Em tempo de execução real, as notas exibidas nas telas são calculadas puramente em memória pelos calculators a partir do histórico de partidas.
- **Ação:** Registrado no inventário `docs/INVENTARIO_SHAREDPREFS.md`.

---

### 10. `lib/screens/tournament_screen.dart` (linhas 1–134) e `lib/screens/blank_screen.dart` (linha 5) — Tarefa T0e
- **O que viu:** O arquivo `lib/screens/tournament_screen.dart` não possui nenhum chamador no aplicativo (0 chamadores, não é importado em nenhum outro arquivo). A tela `BlankScreen` (`lib/screens/blank_screen.dart`) só é aberta dentro de `tournament_screen.dart:122` via `MaterialPageRoute(builder: (c) => const BlankScreen())`. Além disso, em `lib/main.dart:5` existe um `import 'package:app_do_fut/screens/blank_screen.dart';` não utilizado.
- **Impacto:** Tanto `TournamentScreen` quanto `BlankScreen` são telas inalcançáveis no aplicativo.
- **Ação:** Registrado em `docs/CODIGO_MORTO.md`.

---

### 11. `lib/repositories/ratings_repository.dart` (linhas 11–72) — Tarefa T0e
- **O que viu:** Todos os 4 métodos públicos de `RatingsRepository` (`getPlayerHistoryBySeason`, `getFullPlayerHistory`, `getLatestRatingsBySeason`, `recordRatingsBatch`) possuem 0 chamadores externos à própria classe no aplicativo. A propriedade `SupabaseService.instance.ratings` nunca é consumida.
- **Impacto:** Toda a classe `RatingsRepository` não possui chamadores ativos na aplicação atual.
- **Ação:** Registrado em `docs/CODIGO_MORTO.md`.

---

### 12. `lib/domain/services/permission_service.dart` e mensagens de erro de `requireAdmin` — Tarefa T2
- **O que viu:** O `ARCHITECTURE.md` (linha 99) e o enunciado da tarefa T2 afirmam que `requireAdmin` deve lançar "a MESMA exceção e mensagem que os repositórios lançam hoje". No entanto, inspecionando os repositórios (`groups`, `seasons`, `players`, `group_members`), verificou-se que cada método lança uma mensagem de erro distinta e específica (ex.: `'Access denied: Only administrators can create seasons.'`, `'Access denied: Only administrators can edit the group.'`, `'Acesso negado: somente administradores podem definir áudios de gol.'`, etc.).
- **Impacto:** Uma assinatura rígida `requireAdmin(String groupId)` sem mensagem forçaria a unificação sob uma mensagem genérica arbitrária, violando a Regra de Ouro nº 8 ("Exceções e mensagens de erro existentes devem ser preservadas com o mesmo texto").
- **Ação:** A interface `PermissionService` foi ajustada para aceitar um parâmetro opcional `Future<void> requireAdmin(String groupId, [String? message])`. Quando chamada sem mensagem, utiliza o padrão `'Access denied: Only administrators can perform this action.'`. Nos repositórios, cada método repassa o seu texto original de erro, preservando 100% da compatibilidade e das mensagens existentes.

---

### 13. Remoção de telas inalcançáveis e artefatos órfãos — Tarefa T0g
- **O que viu:**
  1. As 4 telas inalcançáveis mapeadas no `docs/CODIGO_MORTO.md` (`lib/screens/expanded_ranking_screen.dart`, `lib/screens/group_ranking_screen.dart`, `lib/screens/tournament_screen.dart`, `lib/screens/blank_screen.dart`) foram verificadas via grep em `lib/` e `test/` e confirmou-se que não possuíam chamadores externos. Foram removidas com sucesso.
  2. O `import 'package:app_do_fut/screens/blank_screen.dart';` em `lib/main.dart:5` já havia sido removido em commit prévio; todos os imports atuais de `lib/main.dart` estão em uso.
  3. O widget `PlayerCard` em `lib/widgets/player/player_card.dart` não possui nenhum importador ou chamador no projeto (apenas `FifaCard` e `WaitingPlayerCard` são utilizados). Conforme a regra de ouro do projeto, não foi apagado e fica registrado aqui.
  4. A tela `BlankScreen` referenciava dois assets inexistentes no disco (`assets/images/imagem_teste.jpeg` e `assets/audio/whatsapp.mp3`). Não há referências a eles no restante do código.
- **Impacto:** Nenhum impacto no comportamento visível do app. Redução de 34 avisos/lints legados no `flutter analyze`.
- **Ação:** Arquivos de tela removidos e apontamentos registrados aqui.

---

### 14. Pontos de enfileiramento e reenvio de partidas / `_onAppResumed` — Tarefa T3d
- **O que viu:**
  1. O documento `docs/INVENTARIO_OFFLINE.md` (linha 235) afirma: *"Ao Voltar do Background: O método _onAppResumed() em match_screen.dart aciona o reenvio quando o app volta a ter foco no sistema operacional."* Contudo, na inspeção minuciosa do código de `match_screen.dart` e de todo o `lib/`, verificou-se que não existe nenhum método `_onAppResumed()`, nem implementação de `WidgetsBindingObserver` ou escuta de ciclo de vida (`AppLifecycleState`) no `match_screen.dart`.
  2. Foi realizado um levantamento completo de todos os pontos que enfileiram ou disparam reenvio de partidas no aplicativo:
     - **Enfileiramento (`enqueue`)**: chamado exclusivamente em `lib/screens/match_screen.dart:3434` (`_finishMatch`), ao encerrar uma partida.
     - **Reenvio / Flush (`flush`)**:
       - `lib/screens/match_screen.dart:129` no `initState()` ao abrir a tela da partida;
       - `lib/screens/match_screen.dart:602` em `_startMatch()` quando a partida é iniciada;
       - `lib/screens/match_screen.dart:3706` no botão "Tentar agora" do diálogo `_showPendingSyncDialog`;
       - Timer interno em `SupabaseMatchOutbox.enqueue` (disparo automático 2 segundos após enfileirar);
       - Timer interno de backoff em `SupabaseMatchOutbox._scheduleRetry` (5s, 10s, 20s, 40s, 60s) em caso de erro.
     - **Mesclagem em memória sem rede (`readAll`)**: chamado em `lib/data/supabase/matches_repository.dart:27` em `_pendingMatches()` para exibir partidas ainda não sincronizadas no Histórico, Ranking e Estatísticas.
- **Impacto:** Não houve alteração de comportamento. A documentação `INVENTARIO_OFFLINE.md` continha menção a um método inexistente (`_onAppResumed`). Todos os gatilhos reais existentes no código foram 100% preservados na abstração `SupabaseMatchOutbox`.
- **Ação:** Registrado aqui conforme instrução 5 da tarefa T3d.

---

### 15. Referência a "TESTAR CONEXÃO AGORA" em `admin_debug_screen.dart` — Tarefa T3c
- **O que viu:** O documento `docs/INVENTARIO_OFFLINE.md` (linhas 101 e 317) e o enunciado da tarefa T3c citam: *"abrir o painel de debug do admin e tocar 'TESTAR CONEXÃO AGORA'"*. Contudo, na inspeção minuciosa de `lib/screens/admin_debug_screen.dart` e em todo o histórico do git (`git log -S "TESTAR CONEXÃO"`), verificou-se que nunca existiu um botão físico com o texto "TESTAR CONEXÃO AGORA". O teste de latência e conectividade com o Supabase (`testSupabaseConnection()`) é disparado automaticamente durante o carregamento inicial da tela e pelo botão de recarregar da AppBar (`IconButton` com `Icons.refresh` e tooltip "Atualizar Status"), bem como pelo gesto de pull-to-refresh (`RefreshIndicator`), ambos chamando `_loadData()` que executa `getStatus()`.
- **Impacto:** Nenhum impacto no comportamento visível do app. Conforme a regra de ouro de não alterar o comportamento visível da UI, a interface existente com `RefreshIndicator` e botão de refresh na AppBar foi preservada, agora consumindo `AppServices.instance.diagnostics` e `AppServices.instance.siteSync`.
- **Ação:** Registrado aqui conforme a regra geral do projeto.

---

### 16. `lib/utils/stats_calculator.dart` (`getAllGroupMatches`, linhas 13–130) — Tarefa T3e (Etapa 1)
- **O que viu:** A função `getAllGroupMatches(String groupId)` busca inicialmente todas as partidas e o elenco do grupo via repositórios (`MatchesRepository.getMatchesByGroup` e `PlayersRepository.getPlayersByGroup`), mapeando escalações, eventos e goleiros em memória. Caso ocorra qualquer exceção (ex.: falha de rede/offline), cai no fallback para `SharedPreferences`, onde lê `sessions_$groupId` (lista de sessões do grupo) e, para cada sessão encontrada, busca seu histórico local na chave `match_history_$tId`. Em seguida, se existir a chave de configuração `seasons_$groupId`, filtra as partidas pela temporada ativa baseando-se nas datas `startDate` e `endDate`.
- **Impacto:** O fluxo combinava instanciação direta de repositórios Supabase com leitura direta de chaves locais/legadas em `SharedPreferences`.
- **Ação:** Parâmetros opcionais nomeados `matchesRepository` e `playersRepository` foram adicionados à assinatura para possibilitar testes de unidade e injeção de dependências, mantendo as implementações originais como padrão.

---

### 17. Tratamento de erro de JSON e ausência de chaves em `match_history_` e `custom_badges_` — Tarefa T3e (Etapa 3)
- **O que viu:**
  - `match_history_<sessionId>`:
    - Em `match_screen.dart` (linha 565 em `_loadSessionMatches` e linha 3654 em `_appendLocalHistory`), as leituras usam `try/catch` tratando exceções (incluindo JSON corrompido) e revertem para lista vazia `[]`.
    - Em `ranking_screen.dart` (linha 178) e `stats_calculator.dart` (linha 109), `jsonDecode` era executado diretamente sem `try/catch`, arriscando `FormatException` caso a string em disco estivesse corrompida.
  - `custom_badges_<groupId>`:
    - Em `manage_badges_screen.dart` (linha 82) e `player_detail.dart` (linhas 179 e 1818), `jsonDecode` era executado sem `try/catch`, assumindo JSON válido.
- **Impacto:** Diferentes telas lidavam de formas distintas com a robustez na deserialização dos dados locais persistidos no `SharedPreferences`.
- **Ação / Decisão do Dono do Projeto:**
  - Foi aceito que JSON corrompido em `match_history_*` e `custom_badges_*` retorne lista vazia `[]` e que itens que não sejam `Map` sejam descartados em todas as telas (evitando que dados corrompidos quebrem a UI).
  - Foi rejeitado alterar a semântica de decisão nas telas para `isNotEmpty`. Na `main`, a decisão dependia de a chave existir (`containsKey`), inclusive quando o valor salvo fosse uma lista vazia `[]` (ex.: `match_screen.dart` atualiza `_finishedMatches`, `manage_badges_screen.dart` atualiza `_customBadges`, `player_detail.dart` atualiza templates).
  - Para preservar estritamente esse comportamento, foram adicionados os métodos `Future<bool> hasCustomBadges(String groupId)` na interface `CustomBadgesRepository` e `Future<bool> hasSession(String sessionId)` na interface `MatchHistoryStore`, implementados em `PrefsCustomBadgesRepository` e `PrefsMatchHistoryStore` via `containsKey`. No futuro app público (SQLite), o significado corresponderá a "já foi salvo alguma vez".
  - Em `stats_calculator.dart`, o fallback foi simplificado para `matchHistoryStore ?? AppServices.instance.matchHistory`, com injeção explícita do store nos testes de unidade correspondentes.

---

### 18. Chave `match_history_` em `lib/data/supabase/supabase_site_sync_service.dart` (linhas 132, 198, 199) — Tarefa T3e (Etapa 4)
- **O que viu:** No serviço `SupabaseSiteSyncService` (movido de `lib/services/sync_service.dart` para `lib/data/supabase/` na Tarefa T3c), há rotinas de normalização de IDs de jogadores em lote e renomeação de IDs de sessão que varrem todas as chaves do `SharedPreferences` que começam com `match_history_` e reescrevem o JSON normalizado ou movem de `match_history_$oldId` para `match_history_$newId`.
- **Impacto:** O arquivo `supabase_site_sync_service.dart` manipula chaves `match_history_` em nível de migração/backup de dados, de forma similar ao `lib/data/supabase/site_data_generator.dart`.
- **Ação:** Seguindo a instrução da Tarefa T3e de não alterar comportamentos de sync de dados ou serviços legados além do escopo das telas/calculators, o código em `supabase_site_sync_service.dart` foi preservado sem alterações e registrado aqui.

---

### 19. Levantamento de ações de escrita nas telas e condicionamento a `!isReadOnly` — Tarefa T4 (Etapa 3)
- **O que viu:** Foi realizado o levantamento de todas as ações de escrita (salvar, editar, apagar, reordenar, promover etc.) existentes nas telas do app, classificando quais atualmente exigem privilégio de admin e quais são abertas a qualquer membro ou usuário.
- **Ações de escrita que NÃO exigem admin (condicionadas a `!isReadOnly` sem impor admin):**
  1. `lib/screens/history_screen.dart:168` (`_clearHistory`): Limpar todas as partidas do histórico da sessão. Não exige admin (comportamento legado com confirmação em diálogo). No app web/read-only não deve existir. Condicionado a `!isReadOnly`.
  2. `lib/screens/history_screen.dart:188` (`_promptPasswordForEdit`): Solicitar senha local ("0101") para editar partida do histórico. Não exige admin Supabase. No app web/read-only não deve existir. Condicionado a `!isReadOnly`.
  3. `lib/screens/history_screen.dart:261` (Botão de lixeira no `AppBar`): Condicionado a `!isReadOnly`.
  4. `lib/screens/history_screen.dart:327` (Botão de edição no card de partida): Condicionado a `!isReadOnly`.
  5. `lib/screens/edit_match_screen.dart:405` (`_saveChanges`): Salva alterações de placar e eventos de uma partida já jogada no Supabase via `MatchesRepository`. Não exige admin (acessado via senha local). No app web/read-only não deve existir. Condicionado a `!isReadOnly`.
  6. `lib/screens/edit_match_screen.dart:498` (Botão `SALVAR` no `AppBar`): Condicionado a `!isReadOnly`.
  7. `lib/screens/match_screen.dart:1045` (Botão "Encerrar Partida" no diálogo de confirmação): Sem restrição de admin; no web somente leitura não deve existir; condicionado a `!isReadOnly`; **decidir na Fase 2 se `match_screen` existirá no web**.
  8. `lib/screens/match_screen.dart:3361` (`_finishMatch`): Grava o encerramento da partida na fila outbox e no histórico local. Sem restrição de admin; no web somente leitura não deve existir; condicionado a `!isReadOnly`; **decidir na Fase 2 se `match_screen` existirá no web**.
  9. `lib/main_personal.dart:186` (`_showGroupDialog`): Criar novo grupo ou editar nome do grupo. Ação do dono da conta pessoal (sem papel admin por grupo). No app web/read-only não deve existir. Condicionado a `!isReadOnly`.
  10. `lib/main_personal.dart:312` (`_deleteGroup`): Excluir grupo da conta. No app web/read-only não deve existir. Condicionado a `!isReadOnly`.
  11. `lib/main_personal.dart:644` (Menu de contexto do grupo: Editar / Excluir): Condicionado a `!isReadOnly`.
  12. `lib/main_personal.dart:675` (FAB de criar grupo): Condicionado a `!isReadOnly`.
  13. `lib/screens/player_detail.dart:204` (`_pickAndUploadAvatar`): Upload de foto de perfil. Permitido ao dono do perfil (`_isOwner`) ou ao admin. Condicionado a `!isReadOnly`.
  14. `lib/screens/player_detail.dart:3804` (`_showAudioPickerModal`): Escolha de som de gol. Permitido ao dono do perfil (`_isOwner`) ou ao admin. Condicionado a `!isReadOnly` e `hasGoalSounds`.
  15. `lib/screens/manage_badges_screen.dart:1153, 1558, 1667, 1737` (`_saveBadges`, botões e FAB de troféus): Salvar e excluir insígnias e troféus personalizados. Não exigia admin na main. No modo read-only não deve existir. Condicionado a `!isReadOnly`.

- **Ações de escrita que EXIGEM admin (condicionadas a `canAdminister` e suas respectivas flags):**
  1. `lib/screens/sessions_screen.dart:163` (`onEdit`): Editar sessão — exige admin (`canAdminister`).
  2. `lib/screens/sessions_screen.dart:164` (`onDelete`): Excluir sessão — exige admin (`canAdminister`).
  3. `lib/screens/sessions_screen.dart:211` (FAB de criar sessão) — exige admin (`canAdminister`).
  4. `lib/screens/players_screen.dart:436, 460, 495` (Menu e exclusão de jogador do elenco) — exige admin (`canAdminister`).
  5. `lib/screens/players_screen.dart:796` (FAB de adicionar jogador ao elenco) — exige admin (`canAdminister`).
  6. `lib/screens/settings_screen.dart:224` (`_showEditGroupDialog`): Editar dados do grupo — exige admin (`canAdminister`).
  7. `lib/screens/manage_members_screen.dart:54, 153` (`_toggleAdmin` / Switch): Promover ou rebaixar membros — exige admin (`canAdminister`).
  8. `lib/screens/manage_seasons_screen.dart:37, 200, 313, 335` (Criar, editar e excluir temporadas) — exige admin (`canAdminister`).
  9. `lib/screens/manage_join_requests_screen.dart:42, 77, 238` (Aprovar e rejeitar solicitações de entrada) — exige admin (`canAdminister`).
  10. `lib/screens/manage_badges_screen.dart:377, 439` (Definir áudio de gol de jogadores) — exige admin (`canAdminister` e `hasGoalSounds`).
  11. `lib/screens/manage_badges_screen.dart:338, 351, 364` (Definir cosméticos de jogadores) — exige admin (`canAdminister` e `hasCosmetics`).
  12. `lib/screens/player_detail.dart:2622, 2762` (Adicionar e remover insígnias manuais) — exige admin (`canAdminister`).
  13. `lib/screens/player_detail.dart:3350, 3740` (Editar atributos comunitários) — exige admin (`canAdminister`).
  14. `lib/screens/admin_debug_screen.dart:46` (Limpar cache, recalcular overall, forçar sync) — tela exclusiva de admin (`canAdminister` e `hasAdminDebug`).






