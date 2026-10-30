# BACKLOG.md — Decisões e ideias para depois da Fase 1

> Nada daqui deve ser mexido durante a refatoração (Fase 1): o app personal precisa continuar idêntico. Estes itens mudam números ou funcionalidades e entram em tarefas próprias depois.

## 1. Cálculos: possíveis bugs (decidir um a um: bug ou intencional?)

Origem: `docs/DUVIDAS.md` (T0). Os testes de caracterização **travam o comportamento atual**; corrigir qualquer item muda as notas que todos veem, então é uma decisão consciente (e os testes correspondentes precisam ser atualizados junto).

| # | Onde | O que acontece hoje | Pergunta |
|---|---|---|---|
| 1 | `findSpecialGoals` | `comebackIndex` é sempre -1: um gol de +1 nunca passa o rival, então a "virada" nunca é detectada | Empatar conta como virada? Qual é a regra? |
| 2 | `kBonusTeamGoal = 0.1` | O comentário diz "desativado", mas o bônus está ativo | Só corrigir o comentário? |
| 3 | `calculateGlobalStats` | Usa `calculateMatchRating` também para goleiros (e não `calculateGkMatchRating`) | Goleiro deveria usar a fórmula de goleiro? |
| 4 | `calculateGlobalStats` | Passa `teamWinStreak: 0` fixo: o bônus de sequência de vitórias nunca é aplicado na nota global | Era para aplicar? |
| 5 | `calculateGlobalStats` | Com `isExactCurrentSeason == false`, não conta os jogos, mas conta a nota | Os dois deveriam andar juntos? |

## 2. Funcionalidade nova: evolução do rating (decidido pelo Enzo)

- **Nota do app:** gráfico de evolução, como é hoje. Ela é **calculada em memória** a partir das partidas e eventos; não precisa de tabela. Reaproveitar o cálculo atual para gerar a série.
- **Nota da comunidade:** não é gráfico. É uma **comparação com a nota anterior** (ex.: "+3 em relação à última votação"). Hoje **não existe nenhuma nota anterior**: ao atualizar os atributos, o valor antigo é sobrescrito.
- **Consequência:** para a comparação existir um dia, é preciso **guardar a nota anterior**. Opções (decidir quando a feature for desenhada): tabela de histórico das notas da comunidade (por jogador e data/votação), ou colunas "anterior" na própria linha do jogador.
- **Antes da próxima atualização das notas da comunidade:** tirar um backup (SELECT das colunas `community_*` da tabela `players`, exportado em CSV). Assim a nota atual vira a "anterior" quando a feature chegar.
- **A conferir:** o log de auditoria (`group_action_logs`, gravado por `setCommunityAttributes`) pode já registrar valores antigos e novos em `details`. Se registra, dá para reconstruir um histórico a partir dele.
- `RatingsRepository` e a tabela `rating_history` (hoje sem uso) **ficam como estão**; não serão apagados nem levados ao SQLite v1. O desenho novo provavelmente será diferente (histórico da comunidade, e não de notas por partida). O drift tem migrações, então a tabela nova entra depois sem problema.

## 3. Código sem uso mantido de propósito (decidir depois da Fase 1)

Métodos com 0 chamadores que ficaram nas classes Supabase (ver `docs/ARCHITECTURE.md`, seção 4.5). Alguns podem fazer parte de funcionalidades futuras:

- `getRecentLogs`, `exportAndCleanOldLogs` → possível tela de logs do admin.
- `createPlayerWithUser`, `linkEmailToPlayer` → possível login por e-mail/SSO.
- `uploadGoalSound`, `clearGoalSound` → upload de som de gol pelo app (hoje não usado).
- `setCosmetics` → atribuição de cosméticos em lote.
- `addMember`, `removeMember`, `saveFullMatch`, `updateFullMatch`, `getSessionsBySeason`, `finalizeSession`, `clearArrivals`.

## 4. Limpezas pequenas (sem pressa)

- 24 avisos do `flutter analyze` (268 itens no total).
- Mover `CommunityAttributes` de `overall_calculator.dart` para `lib/models/`, para `lib/domain` não depender de `lib/utils`.
- Comentário errado em `kBonusTeamGoal` (item 2 da seção 1).
