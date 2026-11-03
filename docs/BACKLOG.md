# BACKLOG.md — Decisões e ideias para depois da Fase 1

> Nada daqui deve ser mexido durante a refatoração (Fase 1): o app personal precisa continuar idêntico. Estes itens mudam números ou funcionalidades e entram em tarefas próprias depois.

## 0. Bugs conhecidos (a investigar e corrigir, um por tarefa)

Ponto de partida: a `main` atual (Fase 1 integrada, incluindo T4). Para cada bug: reproduzir, achar a causa no código, comparar com `git show pre-refactor:<arquivo>` para saber se é regressão, corrigir com teste.

| # | Bug | Como aparece | Suspeita / observação |
|---|---|---|---|
| B1 | ✅ **Corrigido na branch `fix/create-group-season-id` (e `fix/create-season-id`).** Criar grupo falha | `PostgrestException: null value in column "id" of relation "seasons" violates not-null constraint (23502)`. Aparece "Error saving group". | Resolvido: id da temporada gerado via `const Uuid().v4()` em `createGroup` e `createSeason`, com rollback atômico na ordem inversa. |
| B2 | ✅ **Corrigido na branch `fix/players-cache`.** Jogador novo não aparece em "adicionar jogadores" numa pelada já existente | Aparece no elenco, na promoção a admin e na comparação; só aparecia na pelada criada depois. | Resolvido: `_addNewPlayer` e remoção chamam `GroupBootstrap.refreshLocalSnapshot` e `SupabasePlayersRepository` invalida `players:group:<groupId>` no `CacheStore`. |
| B3 | ✅ **Corrigido na branch `fix/players-cache`.** Nome editado não aparece em carta, título nem comparação (chegou a mostrar "Desconhecido") | Persistia só em algumas telas. | Resolvido: `_savePlayerName` chama `updatePlayer` no Supabase validando permissões (admin ou próprio dono); comparação e `match_screen` consultam repositório com fallback no snapshot. |
| B4 | ✅ **Corrigido pelo Enzo em 02/11 (branch `feature/player-advanced-stats`).** Estatísticas avançadas do jogador com números errados | Ex.: 10 derrotas; o jogador com quem mais perdeu esteve em 3 delas, mas dizia "cerca de 70%" (deveria ser 30%). | Corrigido pelo Enzo antes da Fase 1b. |
| B5 | ✅ **Corrigido na branch `fix/outbox-permanent-errors`.** Partida presa na fila de envio sem aviso | Gol de um jogador apagado continuava nas estatísticas mesmo com histórico e `match_events` vazios; voltava a cada reinício. | Resolvido: `isPermanentOutboxError` classifica erros permanentes (`23503`, `23502`, `23514`, `22P02`); após 2 falhas a partida ganha `status: 'failed'`, sai do topo da fila e das estatísticas; diálogo com Copiar, Tentar de novo e Descartar. |
| B6 | **Qualquer pessoa com o app cria grupos** | Outras pessoas já criaram grupos ("du", "du fut", "Baba do Carlos"). A restrição de admin só existe dentro do grupo. | Não é bug de código, é decisão de desenho. Todos os grupos antigos foram apagados do Supabase em 02/11; a discussão volta depois do app offline. |

Relacionados já registrados abaixo: 2c (tela do nome offline), 2d (catálogo de insígnias), 2b (fila ao abrir o app).

### Resultado da investigação (docs/ESTADO_ATUAL.md seção 7, 02/11/2026)

**Nenhum dos bugs é regressão da Fase 1:** todos existiam na tag `pre-refactor`. Tarefas de correção: Fase 1b em `TASKS.md`.

- **B1:** `createGroup` insere em `groups`, `players`, `group_members` e por último em `seasons` sem `id` (`groups_repository.dart:134-138`). Sem transação, falhar na temporada deixa o grupo órfão. Correção: gerar o id com uuid + desfazer o que foi criado se algo falhar. Conferir se os grupos de outras pessoas têm temporada.
- **B2:** o modal "adicionar jogadores" (`match_screen.dart:2806-2827`) lê `players_<groupId>` do `SharedPreferences` e **só consulta o Supabase se a chave estiver vazia**. `_addNewPlayer` (`players_screen.dart:140-159`) grava no Supabase mas não atualiza esse snapshot nem o `CacheStore`.
- **B3:** `_savePlayerName` (`player_detail.dart:1207-1225`) só altera o snapshot local e nunca chama `updatePlayer`; o nome volta ao do banco na próxima recarga. `PlayerComparisonScreen` lê só o snapshot e mostra "Desconhecido" quando o jogador não está nele. Decisão pendente: quem pode renomear (TASKS, pergunta 4).
- **B4:** card "Mais Perdeu Junto" usa `totalReference: myTotalLosses` (`player_detail.dart:1024-1038`), enquanto o Top 1 (`findMax`, ~1161-1165) usa `lossesWith/gamesWith`. **Atenção:** isso não reproduz o exemplo do Enzo (3 de 10 daria 30%, e a tela mostrava ~70%); a correção deve começar reproduzindo com os números reais. Decisão pendente: regra do percentual (TASKS, pergunta 5). O código novo veio do commit `ea08813` ("novas estatísticas", branch `feature/player-advanced-stats`).
- **B5:** `SupabaseMatchOutbox.flush` (`supabase_match_outbox.dart:81-132`) trata todo erro como transitório. Um erro permanente (ex.: `23503`, jogador apagado) fica no topo da fila (`jobs.first`) tentando a cada 60 s para sempre, **bloqueia as partidas seguintes** e continua somado às estatísticas via `readAll()`.

## 0b. Achados do teste das flags da T4 (02/11/2026, `flutter run -d linux`)

Com todas as flags em `true` (app personal) nada mudou. As lacunas abaixo só aparecem com flags desligadas, ou seja, para o site e o app público. Resolver na Fase 2 (T5) ou na T13, não antes.

| # | Achado | Detalhe |
|---|---|---|
| F1 | `hasCosmetics = false` **não esconde a tela "gerenciar cosméticos"** | A flag hoje só é consultada em `manage_badges_screen.dart:34` (`_canManageCosmetics`). A tela ou aba continua aparecendo. Decidir: a flag controla só a **gestão** ou também a **exibição** (molduras, efeitos de nome) nas cartas e rankings? Para o public (flag `false`) provavelmente os dois. |
| F2 | Com `isReadOnly = true` ainda aparecem botões de gravar que dão erro | Ex.: editar/apagar pelada mostra "apenas admins podem", mesmo logado como admin (a mensagem engana: o app está em modo somente leitura). É o mesmo padrão que já existia para quem **não é admin**: a opção aparece e o banco/o app recusa. Está no `Plano_de_Acao.md` (item 2.4: tirar acesso às opções de escrita de quem não é admin). Correção: esconder o botão em vez de mostrar e recusar. Pré-requisito do site (T5). |
| F3 | `match_screen` em somente leitura: dá para adicionar jogador à pelada e **iniciar** a partida, mas não encerrar | A T4 só bloqueou o encerramento (`DUVIDAS.md` #19, itens 7, 8 e 18). Decisão da Fase 2: `match_screen` existe na web? Se não existir, o problema some. |
| F4 | `hasCloudDraftSync = false`: **teste inconclusivo** | Durante o teste houve `SocketException: Failed host lookup ... supabase.co` (falha de DNS da máquina) na fila de envio e o ícone de nuvem (selo de partida pendente) apareceu. Isso não depende da flag: a fila de envio não é controlada por ela. Repetir com a rede estável e conferir se `sessions` e `session_arrivals` deixam de ser atualizados durante a partida. |

## Pendências deixadas pela Fase 1b

- linha parcial em matches/lineups/events que pode ficar no Supabase quando uma partida isolada falha, e "Descartar" só remove a cópia local (DUVIDAS 30); candidata: T-B5b, que tentaria apagar a partida parcial no servidor ao descartar;
- createSeason sem transação (DUVIDAS 26);
- o RLS de players deixa o dono alterar qualquer coluna da própria linha, não só o nome (DUVIDAS 28);
- se _readFromPrefs da fila (supabase_match_outbox.dart) encontra JSON corrompido, devolve lista vazia e o próximo enqueue sobrescreve a fila: risco de perder partidas pendentes (revisão da T-B5);
- o diálogo "adicionar jogadores" pode demorar offline até a requisição falhar (match_screen ~2806-2860);
- setPlayerIcon e os outros métodos que alteram jogador podem não invalidar o cache players:group:<id> (conferir);
- refreshLocalSnapshot ignora lista vazia, então remover o último jogador mantém o snapshot;
- testes que faltam: fallback offline do match_screen, falha de rede ao renomear, teste de widget do gatilho de abertura da fila, HomePage offline;
- mensagem de permissão nova em updatePlayer (DUVIDAS 27).

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

## 2b. Fila de envio: reenviar ao abrir o app e ao voltar do background (resolvido pela T-B6)

Resolvido na Tarefa T-B6 (`fix/offline-startup`): chamadas a `outbox.refreshCounts()` e `outbox.flush()` integradas na inicialização (após login reconhecido em `_ProfileCheckState.initState`) e ao retornar do background via `WidgetsBindingObserver` (`_AuthGateState.didChangeAppLifecycleState` com `AppLifecycleState.resumed`).

## 2c. Tela "Como podemos te chamar?" aparece sem rede (resolvido pela T-B6)

Resolvido na Tarefa T-B6 (`fix/offline-startup`): `ProfileCheckResult` separa explicitamente erro de rede (`failed`) de lista vazia (`noProfile`). Em caso de falha de conexão, o app não exibe `CompleteProfileScreen`, navegando para a `HomePage` que exibe os grupos do cache local (`groups:my:<userId>`, adicionado na T-B6b) com aviso de dados salvos.

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
