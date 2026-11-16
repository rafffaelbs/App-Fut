# Resumo das docs (leitura de 15/11/2026)

Gerado em modo somente leitura. `git diff --stat` vazio e árvore limpa na hora da leitura.

**O que li:** ARCHITECTURE, TASKS, F3-TASK, S1-TASK, BACKLOG e F2-TASK por completo. No DUVIDAS.md li só do item 25 em diante, e só consultei os itens 25, 28 e 31 a 46. Os itens 1 a 24, 26, 27 e 29 a 30 ficaram sem ler (do 1 ao 30 só vi os títulos).

**O que não li:** ESTADO_ATUAL, INVENTARIO_*, CODIGO_MORTO, VISAO_GERAL, F0-TASK e F1-TASK (só vi no F1 as linhas de status das tarefas T-B).

## 1. Estado atual por fase

| Fase | Estado | Observação |
|---|---|---|
| 0 | ✅ Concluída | Na `main`, é só histórico. |
| 1 | ✅ Concluída | Na `main`. |
| 1b | ✅ Concluída | T-B1 a T-B6c estão na `main`. |
| 2 | ✅ Encerrada em 15/11/2026 | O site está no ar em `app-fut-site.pages.dev/fut`. Ficaram pendências que não bloqueiam (seção 6). |
| 3 | ⏳ Pendente | Só existe a tabela T8 a T15. Os prompts não foram escritos. |
| E1 | ✅ Concluída | E1a, E1b, E1c e E1d. Está na `main` (o último commit é a E1d). |
| S1 | ⏳ Desenho pronto, nada aplicado | A ordem é S1b (app) → instalar nos admins → S1a (SQL). Prioridade alta, mas não urgente. |

## 2. O que mudou nas docs desde a Fase 2 encerrada (15/11)

Os docs ARCHITECTURE, DUVIDAS, F2-TASK, TASKS e INVENTARIO_SHAREDPREFS foram editados no fim do dia 15/11. Os commits `b2ea3fa` e `9432713` (E1a a E1d) vieram depois do encerramento.

- **Fases novas:** nenhuma. A estética do site virou **E1**, para não colidir com T8 a T15.
- **Decisões novas (E1):**
  - "Craque do mês" é o selo manual. "Destaque do mês" é o líder calculado.
  - O mês vale pela data da pelada, e o mínimo é de 5 partidas no mês.
  - Goleiros ficam fora do destaque por enquanto.
  - O desempate é G+A, gols, vitórias e nome.
- **Tarefas criadas:** E1.0, E1a, E1b, E1c e E1d.
- **Tarefas adiadas ou reordenadas:**
  - A T6c (tela do link no app) foi para o backlog em 14/11.
  - A T7b ficou por último, depois da E1.
- **Tarefas removidas:** não consta nenhuma.
- **Tarefas renomeadas:** não consta nenhuma.
- **Mudanças no app que as docs registram:**
  - Estilos de avatar (fundo ou auréola) por tela.
  - Seção "Atualizações" no dashboard.
  - Sino de notificações pessoais, só no app.
  - Nova tela de estatísticas da temporada.
- **Contagem de testes:** 320 (antes 308 e 222).

## 3. Lista de tarefas

| ID | Nome | Fase | Status | Dependências | Branch |
|---|---|---|---|---|---|
| T0, T0b, T0c, T0d, T0e, T0g | Fase 0 | 0 | ✅ | não consta | não consta |
| T1, T2, T3a a T3e, T4 | Fase 1 | 1 | ✅ | não consta | não consta nos docs que li |
| T-B1 | Criar grupo sem erro de temporada | 1b | ✅ | não consta | `fix/create-group-season-id` |
| T-B1b | Criar temporada sem erro de id | 1b | ✅ | não consta | `fix/create-season-id` |
| T-B2/B3 | Cache do elenco e nome do jogador | 1b | ✅ | não consta | `fix/players-cache` |
| T-B4 | Estatísticas avançadas | 1b | ✅ (feito pelo Enzo) | não consta | `feature/player-advanced-stats` |
| T-B5 | Fila de envio com erro permanente | 1b | ✅ | não consta | `fix/outbox-permanent-errors` |
| T-B6 | Abrir o app sem rede | 1b | ✅ | não consta | `fix/offline-startup` |
| T-B6b | Cache da lista de grupos offline | 1b | ✅ | não consta | `fix/groups-offline-cache` |
| T-B6c | Indicador de pendências na HomePage | 1b | ✅ | não consta | `fix/home-pending-indicator` |
| T5 | Telas seguras para web e modo somente leitura | 2 | ✅ | não consta | `feat/web-readonly-screens` |
| T6 | Token e funções SQL | 2 | ✅ (04/11) | não consta | sem branch |
| T6b | Repositórios via token e `bootstrap_web` | 2 | ✅ | T5 e T6 | `feat/web-token-repos` |
| T7 | Deploy no Cloudflare Pages | 2 | ✅ no ar (falta o teste no iPhone) | T6b | `feat/web-deploy` |
| T6c | Tela do link no app | 2 | ⏸️ adiada | passo 5 de `F2_T6_testes.md` | `feat/share-link-admin` |
| E1.0 | Levantamento | 2 | ✅ | não consta | não consta |
| E1a | Aba "Peladas" na carta | 2 | ✅ | não consta | `feat/player-recent-sessions` |
| E1b | Dashboard "Início" | 2 | ✅ | não consta | `feat/web-dashboard` |
| E1c | Melhorias no dashboard e nas estatísticas | 2 | ✅ | não consta | não consta |
| E1d | Estilos de avatar, atualizações e notificações | 2 | ✅ | não consta | não consta |
| T7b | Aposentar o site antigo | 2 | ⏳ por último (rascunho) | E1 e site em uso pelos amigos | `chore/remove-old-site` |
| T8 | Schema drift e migrações | 3 | ⏳ (Claude) | não consta | não consta |
| T9 | Repositórios locais simples | 3 | ⏳ (AG) | não consta | não consta |
| T10 | Repositórios locais com transação e `LocalMatchOutbox` | 3 | ⏳ (Claude) | não consta | não consta |
| T11 | Exportar e importar `.db` | 3 | ⏳ (Claude) | não consta | não consta |
| T12 | `bootstrap_public` e `main_public` | 3 | ⏳ (AG) | não consta | não consta |
| T13 | Tema neutro e flags do app público | 3 | ⏳ (AG) | não consta | não consta |
| T14 | `custom_badges`, `MatchHistoryStore` e limpeza ao importar | 3 | ⏳ (Claude) | não consta | não consta |
| T15 | Build Android do app público | 3 | ⏳ (AG) | não consta | não consta |
| S1b | `createGhostPlayer` sem RETURNING e fim do plano B sem filtro | S1 | ⏳ | nenhuma | `fix/ghost-player-insert` |
| S1a | SQL da policy `players_select` | S1 | ⏳ | S1b, instalar nos admins e backup | sem branch |
| T-B5b | Apagar partida parcial no servidor ao descartar | 1b (candidata) | não criada | não consta | não consta |

As dependências da Fase 3 entre T8 e T15 não estão escritas no F3-TASK.md. A tabela só traz tarefa e responsável.

As branches `feat/player-recent-sessions` e `feat/web-deploy` já estão mescladas na `main`. A `feat/web-dashboard` não aparece nas branches locais nem nas remotas. O código dela está na `main`.

## 4. Contradições (o código vale; o que cada doc precisa corrigir)

1. **Aba "Início" (E1b em `F2-TASK.md`).**
   - O doc diz que a aba aparece só com `isReadOnly` e que há teste de que ela não existe com `isReadOnly=false`.
   - O código (`group_dashboard_screen.dart:161-170,267`) mostra a aba sempre, no app e no site. O DUVIDAS #44 confirma que foi pedido do Enzo.
   - Corrigir o prompt e o aceite da E1b. O "personal idêntico" de ARCHITECTURE e F2 também não vale mais.
2. **Encerramento da F2, item 1.** Diz que falta o merge de E1a a E1d. A `main` já tem tudo (commits `b2ea3fa` e `9432713`), então esse item está desatualizado.
3. **Contagem de testes.**
   - A linha da E1 em `F2-TASK.md` e no `TASKS.md` diz 308 e cita só E1a a E1c.
   - O `ARCHITECTURE.md` e o encerramento dizem 320.
   - Por contagem de `test(` e `testWidgets(` achei cerca de 320 declarações. Não rodei a suíte.
   - O cabeçalho do `F2-TASK.md` ainda diz 222.
4. **Pasta `docs/sql/` não existe.**
   - `F2-TASK.md` e `S1-TASK.md` citam `docs/sql/F2_T6_share_link.sql`, `docs/sql/F2_T6_testes.md` e `docs/sql/S1a_players_select_rls.sql`.
   - Em `docs/` só existem `F2_T6_testes.md` e `S1_players_select_rls.sql` (o nome do S1 também difere: falta o "a").
   - O arquivo `F2_T6_share_link.sql` não está no repositório. Se ele existe só na máquina do Enzo, o doc deve dizer isso.
5. **ARCHITECTURE: regra 5.** Ainda não tem a exceção aditiva da T6 (tabela `group_share_tokens` e funções novas), nem a exceção da S1. Está na lista "Ajustes pendentes" do `TASKS.md`, e esses ajustes continuam sem ser feitos.
6. **ARCHITECTURE, seção 1.** A web aparece como "(depois)" e o login como "a decidir". Já está decidido: sem login, e o site está no ar.
7. **ARCHITECTURE, seção 5, fim do estado da T4.** Diz "decidir se `match_screen` existe na web". Já foi decidido que não existe. O mesmo vale para o DUVIDAS #19, itens 7, 8 e 18, como o `TASKS.md` já pede.
8. **ARCHITECTURE, seção 7.** Falta o link `#/g/<token>`, a hospedagem Cloudflare Pages e o aviso de que a web não tem `match_screen`.
9. **ARCHITECTURE, seção 3 (árvore de pastas).** Não lista `bootstrap_web.dart`, `main_web.dart`, `lib/screens/web/`, `lib/data/supabase/readonly/` nem os novos serviços (`avatar_style_manager`, `dashboard_store`).
10. **Grupos apagados (ARCHITECTURE seção 11 e BACKLOG B6).** Dizem que todos os grupos foram apagados. O `TASKS.md` diz que sobrou o "Fut do INF", e o S1 confirma 71 jogadores nele.
11. **Chaves de SharedPreferences.**
    - O código grava `avatar_style_ranking`, `avatar_style_dashboard`, `avatar_style_stats`, `avatar_style_match` e `last_seen_notif_<grupo>_<jogador>`.
    - A lista da seção 9 do ARCHITECTURE (regra 10) não tem nenhuma delas. A seção 10 só cita `avatar_style_*` de forma genérica.
    - Não conferi o `INVENTARIO_SHAREDPREFS.md`, que foi editado em 15/11.
12. **BACKLOG.md.**
    - A última edição foi em 03/11. Faltam os itens que o `F2-TASK.md` (encerramento, item 9) manda registrar: T6c, ideias do dashboard, `/fut` resolver o token em tempo de execução e `--no-web-resources-cdn`.
    - O S1 pede o registro dele com prioridade alta.
    - O selo "Craque do mês" não guarda o mês (também item 9 do encerramento).
13. **`F2-TASK.md`, tabela de status.** A T6 diz que falta o teste de admin do passo 5, e a T7 diz que falta o teste no iPhone. As duas pendências são reais, mas a linha da E1 não cita a E1d.
14. **F3-TASK.md.** O texto "detalhar depois do gate" cita um gate que o `TASKS.md` não define.

## 5. Dúvidas em aberto e BACKLOG

**DUVIDAS.md** (só o que vi nos itens lidos):
- **#30:** o descarte local deixa linhas parciais no Supabase (candidata T-B5b).
- **#26:** `createSeason` sem transação.
- **#28:** o RLS deixa o dono alterar qualquer coluna da própria linha em `players`.
- **#43:** `_calculateChartData` mantém o gráfico antigo quando o período filtrado não tem partidas. Fica fora do escopo e não foi alterado.
- **#44:** `monthly_highlight` é só um booleano, sem mês.
- **#19, itens 7, 8 e 18:** marcar "`match_screen` não existe na web" como decidido.
- Os itens 1 a 30 não foram lidos por completo. Outras dúvidas podem estar em aberto lá.

**TASKS.md, perguntas em aberto:**
1. Insígnias personalizadas: só o Enzo cria ou outros admins também? E "apagar do catálogo não remove do jogador" é desejado?
2. Perguntas específicas da Fase 2 (veja abaixo).

**F2-TASK.md, perguntas em aberto:** guardar o token no navegador, domínio próprio, e se a tabela `custom_badges` tem dados.

**BACKLOG.md:**
- **B6:** qualquer pessoa cria grupos (decisão de desenho, volta depois do app offline).
- **Cálculos 1 a 5:** `comebackIndex` sempre -1, comentário de `kBonusTeamGoal`, goleiro com fórmula de jogador, `teamWinStreak: 0` fixo e nota sem jogos.
- **Rating:** gráfico do app e nota da comunidade com histórico, mais o backup das colunas `community_*` antes da próxima atualização.
- **2d:** apagar do catálogo de insígnias não remove do jogador.
- **Código sem uso** e **limpezas pequenas:** 24 avisos de analyze e mover `CommunityAttributes`.
- **Pendências da Fase 1b:** 9 itens, entre eles JSON corrompido na fila, cache de `setPlayerIcon` e `refreshLocalSnapshot` com lista vazia.
- **F1 a F4 (seção 0b):** F1 (`hasCosmetics`), F2 (botões que dão erro) e F3 (`match_screen` somente leitura) parecem resolvidos pela Fase 2. Isso é inferência minha, porque o doc não os marca. F4 (teste do `hasCloudDraftSync`) continua inconclusivo.

## 6. Riscos e bloqueios

1. **S1 (segurança):** hoje qualquer usuário logado lê todos os `players`, incluindo `email`. Na prática são 2 e-mails, e há 17 usuários em `auth.users`.
   - A S1b precisa ir para os admins **antes** da S1a, senão "adicionar jogador" quebra.
   - A S1b mexe perto do cache offline e exige o item 9 do checklist (modo avião).
2. **Token do site:** o `F2-TASK.md` diz que ele passou por prints e chat. Girar antes de divulgar exige atualizar o secret `FUT_TOKEN` e rodar o workflow. Senão `/fut` e o atalho do iPhone apontam para o token antigo.
3. **Pendências da Fase 2:**
   - Teste no iPhone: o `start_url: "/fut"` pode não valer no iOS.
   - Teste do erro de conexão no site publicado.
   - Conferir que `_redirects` não expõe o token.
   - Teste de admin do passo 5, que bloqueia a T6c.
4. **T7b mexe no `match_screen`**, onde fica a proteção offline. Precisa de revisão e do teste de modo avião, e de `main` limpa.
5. **Banco de produção:** qualquer mudança exige backup antes. O "Fut do INF" tem os dados reais.
6. **Repositório público:** o Enzo quer fechar a parte pessoal depois do app offline. A segurança não pode depender do código ser secreto.
7. **CI:** `flutter analyze` roda com `--no-fatal-infos --no-fatal-warnings`, por causa de 250 infos e 14 warnings antigos (DUVIDAS #39). Só erros reais derrubam o deploy.
8. **Fila de envio:** o risco de JSON corrompido sobrescrever a fila (BACKLOG, Fase 1b) continua aberto.
9. **Contagem de testes:** o número de testes passando depende de rodar a suíte. Não rodei, então os 320 vêm das docs.
10. **Fase 3:** não há prompts nem dependências escritas, e a T14 depende de decisões da seção 10 do ARCHITECTURE.
