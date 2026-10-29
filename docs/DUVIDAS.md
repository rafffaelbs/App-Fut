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
