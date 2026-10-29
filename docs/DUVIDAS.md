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

