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

## 2b. Fila de envio: reenviar ao abrir o app e ao voltar do background (achado da T3d)

Hoje uma partida pendente só é enviada quando a `MatchScreen` é aberta (`initState`), quando uma partida é iniciada, pelo botão manual ou pelo timer enquanto o app está aberto. Não há reenvio ao iniciar o app nem ao voltar do background, e o selo de pendentes só aparece depois de abrir a tela de partida. Melhoria: chamar `outbox.flush()` no bootstrap e ao retomar o app (`WidgetsBindingObserver`), e carregar a contagem de pendentes na inicialização. Muda comportamento (é uma melhoria), então fica para depois da Fase 1, com teste do modo avião.

## 2c. Tela "Como podemos te chamar?" aparece sem rede (achado do teste da T3e, item 16)

Comportamento **já existente** (confirmado contra a tag `pre-refactor`; não é regressão da T2/T3).

- Em `lib/main_personal.dart` (`_ProfileCheckState._check`, ~linhas 89-101), `claimGhostProfiles()` + `getMyPlayers()` são chamados no Supabase. Se a chamada falha (sem rede, rede lenta, RPC com erro), o `catch` só imprime no log e `_hasProfile` continua `false`, então `CompleteProfileScreen` aparece.
- O nome digitado ali só fica em memória (`_pendingName`), usado como sugestão na tela de entrar em grupo. Nada é gravado.
- O botão "Sair" da tela faz `auth.signOut()`.
- **Correção sugerida (pequena):** separar "a consulta deu erro" de "a consulta voltou vazia". Se deu erro, não mostrar a tela de nome: mostrar o `HomePage` (que já usa cache) ou um aviso "sem conexão, tentar de novo". Só mostrar a tela de nome quando a consulta der certo e vier vazia. Uma variável `_failed` e um `if` no build; não mexe em tabela, RPC nem SharedPreferences.
- **Fazer junto com o item 2b** (reenviar fila ao abrir o app): os dois tratam de abrir o app sem rede. Muda comportamento, então só depois da Fase 1, com teste em modo avião.
- A sessão salva já é reconhecida offline; o que falta é não confundir "erro de rede" com "sem perfil".

## 2d. Catálogo de insígnias personalizadas: apagar não remove dos jogadores (item 9 do teste da T3e)

O catálogo fica no celular (`custom_badges_<groupId>`) e a insígnia atribuída fica no jogador (`players.manual_badges`, Supabase). Apagar do catálogo não tira do jogador; remover pelo perfil do jogador tira. Provável desenho original (a T3e só mudou onde o catálogo é lido/gravado). **A confirmar** comparando com `pre-refactor`. Se confirmado, é melhoria de uso: ao apagar do catálogo, perguntar se também remove dos jogadores.

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
