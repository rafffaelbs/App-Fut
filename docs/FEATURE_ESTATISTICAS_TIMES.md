# Estatísticas de Times, Validador Tático e Correção de Gols da Virada

**Data de Implementação:** 20/11/2026  
**Documento de Referência:** `docs/FEATURE_ESTATISTICAS_TIMES.md`

---

## 1. Visão Geral

Este documento detalha o conjunto de novas funcionalidades e correções de cálculos desenvolvidas no App-Fut:
1. **Correção do Cálculo de Gols da Virada** (`findSpecialGoals` e `PlayerDetailScreen`).
2. **Sistema de Formações Táticas Padrão** (`TacticalFormation`, `FormationManager` e `ManageFormationsScreen`).
3. **Módulo de Estatísticas de Times** (`TeamStatsCalculator`, `TeamStatsView` e `TeamPitchValidator`).
4. **Melhor Time da Pelada** no ranking por sessão (`RankingScreen`).
5. **Top Rivalidades e Troféus da Resenha / Cômicos** na tela da temporada (`SeasonStatsScreen`).
6. **Conquista e Badge "Rei da Virada"** no perfil do jogador (`PlayerDetailScreen`).

---

## 2. Correção: Gols da Virada (Comeback Goals)

### 2.1 Problema Identificado
No arquivo `lib/utils/rating_calculator.dart`, a função `findSpecialGoals` verificava se um gol era de virada utilizando a seguinte condição matemática:
```dart
// Código antigo
if (isRedGoal) {
  if (beforeRed < beforeWhite && scoreRed > scoreWhite) {
    comebackIndex = i;
  }
}
```
Como no futebol e futsal cada gol soma exatamente 1 ponto (`+1`):
- Se `beforeRed < beforeWhite`, no melhor cenário o time estava perdendo por 1 gol (`beforeWhite - beforeRed == 1`).
- Ao marcar um gol, o novo placar ficava `scoreRed == scoreWhite` (empate).
- O gol que coloca o time à frente (`scoreRed > scoreWhite`) partia obrigatoriamente de uma situação de empate (`beforeRed == beforeWhite`).
- Portanto, a condição `beforeRed < beforeWhite && scoreRed > scoreWhite` exigia uma diferença fracionária impossível ($0 < beforeWhite - beforeRed < 1$), fazendo com que `comebackIndex` fosse permanentemente `-1`.

### 2.2 Solução Implementada
A lógica foi aprimorada para registrar se a equipe adversária esteve em vantagem no placar em algum momento prévio da partida:
```dart
bool whiteEverLed = false;
bool redEverLed = false;

// Durante a iteração de eventos:
if (beforeWhite > beforeRed) whiteEverLed = true;
if (beforeRed > beforeWhite) redEverLed = true;

// Ao computar o gol:
if (isRedGoal) {
  if (whiteEverLed && scoreRed > scoreWhite && comebackIndex == -1) {
    comebackIndex = i;
  }
} else {
  if (redEverLed && scoreWhite > scoreRed && comebackIndex == -1) {
    comebackIndex = i;
  }
}
```
Com isso:
- O gol que empata o jogo não é considerado virada (apenas reação).
- O gol subsequente que coloca a equipe em vantagem pela primeira vez após ter estado atrás é pontuado como **Gol da Virada** com bônus de nota e contabilização nas estatísticas avançadas.

### 2.3 Testes Automatizados
O arquivo `test/utils/rating_calculator_test.dart` foi atualizado com testes cobrindo:
- Partida iniciada em 0-0 sem viradas.
- Time A sai na frente (1-0, `whiteEverLed = true`).
- Time B empata (1-1, ainda sem virada).
- Time B marca o 2-1 (virada confirmada no índice do evento).

---

## 3. Formações Táticas Padrão & Gerenciador

### 3.1 Expansão das Formações
No arquivo `lib/utils/tactical_formation.dart`, os presets táticos foram ampliados para suportar equipes de **4 até 11 jogadores de linha** (além de mini-jogos 3x3):
- **4 jogadores:** `1-2-1` (Futsal Clássico), `2-2` (Quadrado Futsal), `1-1-2` (Ofensivo).
- **5 jogadores:** `2-2-1` (Equilibrado Society), `1-3-1` (Meio-campo Society), `2-1-2` (Alas Abertos), `3-1-1` (Três Zagueiros).
- **6 jogadores:** `2-3-1` (Padrão Fut7), `3-2-1` (Solidez Defensiva), `2-2-2` (Duas Linhas).
- **7 jogadores:** `3-3-1` (Equilibrado 8x8), `2-4-1` (Meio Povoado), `3-2-2` (Dupla de Ataque).
- **8 jogadores:** `3-3-2` (Equilibrado 9x9), `3-4-1` (Losango), `4-3-1` (Linha de Quatro).
- **9 jogadores:** `4-3-2` (Compacto 10x10), `3-4-2` (Alas Ofensivos), `4-4-1` (Seguro).
- **10 jogadores (Futebol de Campo 11x11 com goleiro):** `4-3-3` (Clássico), `4-4-2` (Duas Linhas), `4-2-3-1` (Moderno), `3-5-2` (Três Zagueiros), `4-1-4-1` (Primeiro Volante).

### 3.2 Persistência de Formações Padrão (`FormationManager`)
Criada a classe `FormationManager` em `lib/utils/tactical_formation.dart`:
- Salva e carrega formações padrão preferidas por tamanho de time via `SharedPreferences` (`default_formation_$lineCount`).

### 3.3 Tela de Gestão de Formações (`ManageFormationsScreen`)
Localizada em `lib/screens/manage_formations_screen.dart` e acessível através das Configurações do App (`SettingsScreen` -> *Customizações & Gestão* -> *Formações Táticas Padrão*):
- Barra de seleção rápida com chips do formato (`4x4` até `11x11`).
- Cards visuais com mini campo tático mostrando a disposição em campo de cada preset.
- Seleção e salvamento instantâneo da formação preferida.

---

## 4. Estatísticas de Times & Validador Tático

### 4.1 Calculador de Desempenho Coletivo (`TeamStatsCalculator`)
Localizado em `lib/utils/team_stats_calculator.dart`:
- **`computeExactTeams`**: Agrupa partidas por formações exatas de linha (ignorando goleiros) para gerar rankings consolidados da temporada.
- **`evaluateCustomTeam`**: Avalia qualquer seleção de **2 a 11 jogadores** que atuaram juntos na mesma equipe:
  - Total de jogos juntos (`games`).
  - Vitórias (`wins`), empates (`draws`) e derrotas (`losses`).
  - Aproveitamento percentual (`winRate`).
  - Gols pró (`goalsFor`), gols sofridos (`goalsAgainst`) e saldo de gols (`goalDiff`).
  - Lista detalhada de partidas disputadas com placares e datas.
- **`computeBestSessionTeam`**: Identifica a formação de linha campeã daquela pelada específica.
- **`computeTopRivalries`**: Mapeia confrontos diretos e histórico de duelos entre atletas.

### 4.2 Validador Tático de Time (`TeamPitchValidator`)
Localizado em `lib/widgets/stats/team_pitch_validator.dart`:
- **Campo Tático Interativo:** Apresenta o desenho do campo respeitando o número de atletas selecionados (ou a formação padrão configurada).
- **Modo Cards FIFA vs Chips com Foto:**
  - Suporte visual completo com alternância entre cards estilo FIFA (overall, nome, escudo, atributos e foto) e chips circulares com foto do jogador.
  - **Correção de Renderização de Avatares:** Correção no carregamento de fotos para suportar tanto caminhos de assets locais (`assets/icons/...`) quanto URLs remotas (`http/https`), evitando círculos pretos/vazios e utilizando inicial maiúscula estilizada caso a imagem não exista ou falhe.
  - **Configuração no App (`SettingsScreen`):** Seletor via `SegmentedButton` [ Chips | Cards FIFA ] nas configurações do app (similar à configuração de destaque de avatar/fundo), além de botão de troca rápida direto no cabeçalho do campo tático.
  - Preferência gravada de forma persistente no dispositivo (`pitch_use_cards` e `pitch_use_chips`).
- **Seletor de Elenco:**
  - Permite adicionar de 2 a 11 jogadores.
  - Modal com busca instantânea, foto do jogador e overall.
- **Feedback em Tempo Real:**
  - Se os atletas selecionados nunca jogaram juntos: exibe mensagem explicativa *"Esse time nunca jogou junto"*.
  - Se já jogaram: exibe placar de métricas (Aproveitamento, Vitórias, Gols Feitos, Defesa) e histórico expansível de partidas.

### 4.3 Visão de Times na Temporada (`TeamStatsView`)
Localizado em `lib/widgets/stats/team_stats_view.dart`:
- Integrado na tela `SeasonStatsScreen` sob a aba `Times & Parcerias`.
- **Filtro de Tamanho:** Permite filtrar rankings por todas as formações, Duplas, Trios, Quartetos ou 5+ jogadores.
- **Rankings Disponíveis:**
  1. *Times Mais Vitoriosos* (maior taxa de vitórias).
  2. *Times Mais Goleadores* (maior média de gols por jogo).
  3. *Times Mais Sólidos Defensivamente* (menor média de gols sofridos).
  4. *Maior Saldo de Gols*.
- **Top Rivalidades:** Seção com os 3 confrontos mais frequentes e botão "Ver Mais" que abre modal com todas as rivalidades computadas.
- **Validador Tático:** Seção integrada no final da tela para validação livre de formações.

---

## 5. Melhor Time da Pelada (`RankingScreen`)

Na tela `RankingScreen` (`lib/screens/ranking_screen.dart`):
- O seletor de topo foi transformado em um controle de 3 abas:
  - `Linha`
  - `Goleiros`
  - `Melhor Time`
- A aba **Melhor Time** exibe:
  - Banner dourado destacando a formação campeã daquela sessão da pelada.
  - Resumo de vitórias, saldo de gols e aproveitamento da formação.
  - Chips com foto e nome de cada jogador de linha da equipe vencedora.
  - Mini campo tático exibindo o posicionamento da equipe.

---

## 6. Troféus da Resenha / Cômicos (`SeasonStatsScreen`)

Localizados na aba individual de `SeasonStatsScreen`:
- **Inimigo do Gol:** Jogador de linha com a maior sequência de jogos sem balançar as redes.
- **Pé Torto / Traidor:** Jogador com o maior número de gols contra marcados na temporada.
- **Açougueiro / Xerife:** Jogador com a maior quantidade acumulada de cartões amarelos e vermelhos.

---

## 7. Conquista & Badge "Rei da Virada" (`PlayerDetailScreen`)

No perfil do jogador (`lib/screens/player_detail.dart`):
- A contagem de `comebackGoals` é exibida no bloco de estatísticas e no resumo avançado.
- Adicionados badges automáticos na Sala de Troféus:
  - **Poder de Reação:** 1 ou mais gols de virada marcados.
  - **Rei da Virada:** 3 ou mais gols de virada marcados na trajetória.

---

## 8. Arquivos Criados e Modificados

| Arquivo | Status | Descrição |
|---|---|---|
| `lib/utils/rating_calculator.dart` | Modificado | Correção matemática da detecção de virada em `findSpecialGoals`. |
| `lib/utils/tactical_formation.dart` | Modificado | Presets táticos de 3 a 11 jogadores e `FormationManager` via `SharedPreferences`. |
| `lib/utils/team_stats_calculator.dart` | **Novo** | Lógica de cálculo de times, histórico conjunto, melhor time da sessão e rivalidades. |
| `lib/screens/settings_screen.dart` | Modificado | Tile de atalho para configuração de formações táticas padrão. |
| `lib/screens/manage_formations_screen.dart` | **Novo** | Tela administrativa para escolha de formações padrão de 4x4 a 11x11. |
| `lib/widgets/stats/team_pitch_validator.dart` | **Novo** | Widget interativo de campo tático com seletor de 2 a 11 atletas e histórico de partidas. |
| `lib/widgets/stats/team_stats_view.dart` | **Novo** | Painel de rankings de times, filtros de tamanho, rivalidades e validador. |
| `lib/screens/season_stats_screen.dart` | Modificado | Abas `Individual` / `Times & Parcerias`, pódio "Reis da Virada" e Troféus da Resenha. |
| `lib/screens/ranking_screen.dart` | Modificado | Aba "Melhor Time" com mini campo e estatísticas da formação campeã da pelada. |
| `lib/screens/player_detail.dart` | Modificado | Badges automáticos "Poder de Reação" e "Rei da Virada". |
| `test/utils/rating_calculator_test.dart` | Modificado | Testes de caracterização e caso específico para gol de virada. |
| `test/utils/team_stats_calculator_test.dart` | **Novo** | Testes unitários para `evaluateCustomTeam`, `computeBestSessionTeam` e `computeTopRivalries`. |
| `docs/BACKLOG.md` | Modificado | Registro da resolução do bug de viradas e adição das novas ideias no backlog. |
| `docs/FEATURE_ESTATISTICAS_TIMES.md` | **Novo** | Documentação técnica e funcional completa das novidades. |
