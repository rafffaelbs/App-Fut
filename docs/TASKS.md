# TASKS.md — Índice e fonte única do estado das tarefas (v7, atualizado em 15/11/2026)

> Este arquivo é o **índice** e a **única tabela de estado** de todas as tarefas (para importar no Obsidian). Os prompts, branches e prompts de revisão ficam em um arquivo por fase. O agente (AG ou Claude Code) lê `docs/ARCHITECTURE.md` e **apenas o arquivo da fase atual**.
> **Suíte de testes: 322 passando** (rodada em 15/11/2026; 0 erros no analyze, 14 warnings). Números antigos (217, 222, 308, 320) nos arquivos de fase são históricos.

## Arquivos

| Fase | Arquivo | Situação |
|---|---|---|
| Fase 0 (T0, T0b, T0c, T0d, T0e, T0g) | `docs/F0-TASK.md` | ✅ concluída e integrada na `main` (histórico) |
| Fase 1 (T1, T2, T3a a T3e, T4) e Fase 1b (T-B1 a T-B6c) | `docs/F1-TASK.md` | ✅ concluídas e integradas na `main` (histórico) |
| Fase 2 (site somente leitura, T5 a T7b, E1) | `docs/F2-TASK.md` | ✅ **encerrada em 15/11/2026**: site no ar em `app-fut-site.pages.dev/fut`. E1 (E1a a E1d) concluída. Pendências de teste: F2-t1 a F2-t5 abaixo; T7b e T6c abaixo |
| **Fase C: correções pós-Fase 2 (C1 a C5)** | `docs/C-TASK.md` | 🔄 **arquivo dos prompts da fase C** (cabeçalho, prompts de C1, C2, C3 e C5; a C4 foi executada, ver `docs/DIAGNOSTICO_AG_2026-11-15.md`) |
| Fase 3 (app público offline, T8 a T15) | `docs/F3-TASK.md` | ⏳ depois da Fase 2 (encerrada em 15/11) e da fase C; prompts ainda não escritos. A estética do site chama-se **E1**, para não colidir com T8 a T15 |
| **S1 — Segurança do RLS de `players`** (fora das fases) | `docs/S1-TASK.md` | ⏳ desenho concluído; S1b (app, AG) → instalar nos admins → S1a (SQL). Prioridade alta, não urgente. Trata da **leitura** de `players` (policy `players_select`, que expõe e-mail); a edição de colunas da própria linha é a DUVIDAS #28 |
| Diagnóstico do AG de 15/11 | `docs/DIAGNOSTICO_AG_2026-11-15.md` | registro (A1 a A9) |

Ponto de partida oficial: a `main` atual. A tag `pre-refactor` fica só como referência de comparação.

## Tabela única de tarefas

Status: ✅ feito · 🔄 em andamento · ⏳ pendente · ⏸️ adiada · ❌ cancelada. Datas = data do commit ou do merge no `git log` (AAAA-MM-DD); "não consta" quando não deu para determinar. Responsável das T-B: padrão do F1-TASK (revisão Claude, executor AG); T-B1b, T-B6b e T-B6c sem indicação no F1-TASK (a verificar).

| ID | Nome | Fase | Status | Responsável | Dependências | Branch | Conclusão |
|---|---|---|---|---|---|---|---|
| T0 | Testes de caracterização dos cálculos | 0 | ✅ | AG | nenhuma | `test/characterization-calculators` | 2026-10-29 |
| T0b | Mover scripts de migração antigos | 0 | ✅ | AG | nenhuma | `chore/move-legacy-scripts` | 2026-10-29 |
| T0c | Remover código morto do sync | 0 | ✅ | AG | nenhuma | `chore/remove-dead-sync-code` | 2026-10-29 |
| T0d | Inventário de SharedPreferences | 0 | ✅ | AG (revisão Claude) | nenhuma | `docs/inventario-sharedprefs` | 2026-10-29 |
| T0e | Código morto e telas inalcançáveis | 0 | ✅ | AG | nenhuma | `docs/codigo-morto` | 2026-10-29 |
| T0g | Remover telas inalcançáveis | 0 | ✅ | AG | T0e; antes da T3e | `chore/remove-unreachable-screens` | 2026-10-30 |
| T1 | Interfaces de repositório | 1 | ✅ | AG (revisão Claude) | T0e | `refactor/domain-interfaces` | 2026-10-29 |
| T2 | AuthService e PermissionService | 1 | ✅ | AG (revisão Claude) | T1 | `refactor/auth-permission` | 2026-10-29 |
| T3a | Mover e renomear repositórios Supabase | 1 | ✅ | AG | T1, T2 | `refactor/supabase-data-layer` | 2026-10-30 |
| T3b | AppServices no lugar de SupabaseService.instance | 1 | ✅ | AG | T3a | `refactor/app-services` | 2026-10-30 |
| T3c | SiteSyncService e DiagnosticsService | 1 | ✅ | AG | T3b | `refactor/site-sync-diagnostics` | 2026-11-01 |
| T3d | MatchOutbox (fila de envio) | 1 | ✅ | AG (revisão Claude) | T3b | `refactor/match-outbox` | 2026-10-31 |
| T3e | Histórico de partidas e insígnias via interfaces | 1 | ✅ | AG (revisão Claude) | T3b, T0g | `refactor/local-only-data` | 2026-11-01 |
| T4 | AppFeatures e flavor personal | 1 | ✅ | AG | T3c, T3d, T3e | `feat/app-features` | 2026-11-01 |
| T-B1 | Criar grupo sem erro de temporada | 1b | ✅ | AG | não consta | `fix/create-group-season-id` | 2026-11-02 |
| T-B1b | Criar temporada sem erro de id | 1b | ✅ | AG (a verificar) | não consta | `fix/create-season-id` | 2026-11-02 |
| T-B2/B3 | Cache do elenco e nome do jogador | 1b | ✅ | AG | não consta | `fix/players-cache` | 2026-11-02 |
| T-B4 | Estatísticas avançadas com percentuais errados | 1b | ✅ | Enzo | não consta | `feature/player-advanced-stats` | 2026-11-02 |
| T-B5 | Fila de envio: erro permanente | 1b | ✅ | AG | não consta | `fix/outbox-permanent-errors` | 2026-11-02 |
| T-B6 | Abrir o app sem rede | 1b | ✅ | AG | não consta | `fix/offline-startup` | 2026-11-02 |
| T-B6b | Cache da lista de grupos offline | 1b | ✅ | AG (a verificar) | não consta | `fix/groups-offline-cache` | 2026-11-03 |
| T-B6c | Indicador de pendências na HomePage | 1b | ✅ | AG (a verificar) | não consta | `fix/home-pending-indicator` | 2026-11-03 |
| T-B5b | Apagar partida parcial no servidor ao descartar (DUVIDAS #30) | 1b (candidata) | ⏳ candidata, não criada | a definir | T-B5 | não criada | — |
| T5 | Telas seguras para web e modo somente leitura | 2 | ✅ | AG (revisão Claude) | Fases 1 e 1b | `feat/web-readonly-screens` | 2026-11-08 |
| T6 | Tabela de token + funções SQL (`group_share_tokens`) | 2 | ✅ | Claude (SQL) + Enzo | nenhuma | sem branch | 2026-11-04 |
| T6b | Repositórios via token e `bootstrap_web` | 2 | ✅ | AG (revisão Claude) | T5, T6 | `feat/web-token-repos` | 2026-11-14 |
| T7 | Build e deploy no Cloudflare Pages | 2 | ✅ (falta o teste no iPhone: F2-t1) | AG + Enzo | T6b | `feat/web-deploy` | 2026-11-14 |
| T6c | Tela do admin no app: ver, copiar, girar e desativar o link | 2 | ⏸️ adiada (backlog) | AG (revisão Claude) | F2-t4 (passo 5 de `F2_T6_testes.md`) | `feat/share-link-admin` | — |
| E1.0 | Levantamento e ideias do dashboard | 2 | ✅ | Claude Code | nenhuma | sem branch | 2026-11-15 |
| E1a | Aba "Peladas" na carta do jogador | 2 | ✅ | AG | E1.0 | `feat/player-recent-sessions` | 2026-11-15 (commit `b2ea3fa`) |
| E1b | Dashboard "Início" (site e app, DUVIDAS #44) | 2 | ✅ | AG | E1a | `feat/web-dashboard` | 2026-11-15 (commit `b2ea3fa`) |
| E1c | Melhorias no dashboard e estatísticas da temporada | 2 | ✅ | AG | E1b | não consta | 2026-11-15 (commit `9432713`) |
| E1d | Estilos de avatar, "Atualizações" e sino de notificações | 2 | ✅ | AG | E1c | não consta | 2026-11-15 (commit `9432713`) |
| E1e | Cards de resumo no dashboard (partidas, sessões, jogadores, gols) | 2 | ✅ | AG | E1d | `feat/dashboard-overview-cards` | 2026-11-16 |
| F2-t1 | Teste no iPhone: "Adicionar à Tela de Início" abre o site (não "Link inválido") | 2 | ⏳ | Enzo (com um amigo) | T7 | — | — |
| F2-t2 | Teste do erro de conexão no site publicado (bloquear `*supabase.co*` → "Tentar de novo") | 2 | ⏳ | Enzo | T7 | — | — |
| F2-t3 | Conferir que `_redirects` não expõe o token (`curl .../_redirects`) | 2 | ⏳ | Enzo | T7 | — | — |
| F2-t4 | Passo 5 de `docs/F2_T6_testes.md` (testes do admin das funções de token) | 2 | ⏳ | Enzo | T6 | — | — |
| F2-t5 | Decidir se gira o token antes de divulgar o link (atualizar secret `FUT_TOKEN` e rodar o workflow) | 2 | ⏳ | Enzo | T7 | — | — |
| T7b | Aposentar o site antigo (envio `sync_data`, `my_sync_code`; lista em ARCHITECTURE §14) | 2 | ⏳ **por último** | AG + Enzo | E1 e site novo em uso pelos amigos; revisão e teste de modo avião | `chore/remove-old-site` | — |
| S1b | `createGhostPlayer` sem RETURNING e fim do plano B sem filtro | S1 | ⏳ | AG | nenhuma | `fix/ghost-player-insert` | — |
| S1a | SQL da policy `players_select` (`docs/S1_players_select_rls.sql`) | S1 | ⏳ | Claude (SQL) + Enzo | S1b, instalar nos admins, backup | sem branch | — |
| C1 | Preview "Entra:" no fim de partida (`match_screen.dart:3682-3702`) | C | ⏳ prompt pronto; exige teste de modo avião | AG | nenhuma (ordem: depois da C3a) | `fix/entering-preview` | — |
| C2 | Nota do jogador pela história inteira | C | ✅ | Claude Code | nenhuma | `fix/rating-all-history` (já mesclada; branch removida) | 2026-11-15 (merge `027fb03`) |
| C3 | Investigar senha e RLS do histórico (somente leitura) | C | ✅ | Claude Code | C2, C4 | sem branch | 2026-11-16 |
| C3a | Esconder ações de edição de quem não é admin (menu ⋮ do grupo e histórico) | C | ✅ | AG | C3 ✅, C3b ✅ | `fix/admin-only-actions` | 2026-11-16 |
| C3b | Conferir o RLS real de `matches`/`sessions` (`pg_policies`) | C | ✅ RLS correto: as 5 tabelas exigem `is_group_admin` | Enzo (rodou o SQL) | C3 | sem branch | 2026-11-16 |
| C3c | Confirmação do admin (autenticação do aparelho ou senha do app) nas ações destrutivas; remove o `"0101"` | C | ⏳ prompt pronto; aprovados: pacotes `local_auth` e `crypto` e 3 chaves novas de SharedPreferences | AG | C3a | `feat/admin-action-gate` | — |
| C4 | Atualizar os docs (este conjunto de mudanças) | C | ✅ | Claude Code | C2 | `docs/atualizacao-2026-11-15` | 2026-11-15 (commit na branch; falta o merge do Enzo) |
| C5 | Mover `F2_T6_share_link.sql` para `docs/sql/` (sem token) | C | ⏳ | Enzo fornece o arquivo | nenhuma | `docs/share-link-sql` | — |
| T8 | Schema drift + migrações | 3 | ⏳ | Claude | não consta | não consta | — |
| T9 | Repositórios locais simples | 3 | ⏳ | AG | não consta | não consta | — |
| T10 | Repositórios locais com transação + `LocalMatchOutbox` | 3 | ⏳ | Claude | não consta | não consta | — |
| T11 | Exportar e importar `.db` | 3 | ⏳ | Claude | não consta | não consta | — |
| T12 | `bootstrap_public` e `main_public` | 3 | ⏳ | AG | não consta | não consta | — |
| T13 | Tema neutro e flags do app público | 3 | ⏳ | AG | não consta | não consta | — |
| T14 | `custom_badges`, `MatchHistoryStore` e limpeza ao importar | 3 | ⏳ | Claude | não consta | não consta | — |
| T15 | Build Android do app público | 3 | ⏳ | AG | não consta | não consta | — |

**Ordem das frentes:** C2 ✅, C4 ✅, C3 ✅, C3b ✅, C3a ✅, C3c (depois da C3a), C1, C5; depois as pendências da Fase 2 (F2-t1 a F2-t5) e a S1; depois a Fase 3; **T7b por último**.

## Como usar

- **Prompt para o AG:** abra o arquivo da fase, cole o *Cabeçalho* e depois o prompt da tarefa (a tarefa já tem a branch indicada).
- **Prompt de revisão para o Claude Code:** vem junto da tarefa, sempre somente leitura e com a proibição de `git checkout`, `switch` e `stash`.
- **Mudou um prompt durante o trabalho?** O Claude atualiza o arquivo da fase. O arquivo da fase é a fonte de verdade; não dependa do histórico do chat.
- **Fase concluída:** marcar como ✅ no índice, manter o arquivo como histórico e criar o da próxima fase no mesmo padrão.
- **Quem faz:** AG = Antigravity (executa) · CLAUDE = Claude (desenha ou revisa) · Enzo = testa, executa SQL e faz merge e push.

## Decisões já tomadas (resumo; o detalhe de cada fase está no arquivo dela)

- **Site antigo (React/Vercel)** não é mais usado e será removido na **T7b** (última tarefa da Fase 2, só depois de o site novo estar em uso), junto do envio do pacote do site, `my_sync_code` e a tabela `sync_data` (que fica por último).
- **Web somente leitura:** link secreto sem login (token por grupo + funções `SECURITY DEFINER`). Login pode ser acrescentado depois sem refazer a arquitetura. Hospedagem: Cloudflare Pages com build no GitHub Actions (projeto `app-fut-site`; link curto `/fut` gerado no deploy a partir do secret `FUT_TOKEN`).
- **Web sem `match_screen`.** Partida ao vivo e notificações de eventos ficam exclusivas do app.
- `data_migration_service` e `fix_event_times_service`: movidos para `tool/legacy/` (T0b).
- **App público:** um grupo só por enquanto; migrar para vários depois.
- `sync_service`/`cache_sync_manager` não são a proteção offline; viraram `SiteSyncService` e `DiagnosticsService` (T3c). A proteção offline é a fila, o cache, o estado local da partida e o snapshot do elenco (seção 9 do `ARCHITECTURE.md`).
- **Grupos:** o Enzo apagou do Supabase os grupos de teste e de outras pessoas em 02/11. **Resta o "Fut do INF" (dados reais de produção, 71 jogadores)** — qualquer mudança de banco exige backup antes. A discussão de arquitetura de grupos (quem cria, órfãos) volta depois do app offline.
- **Repositório:** hoje público. O Enzo pretende fechar a parte pessoal (app e site) e deixar aberto o app offline; a forma de separar fica para depois do app offline. A segurança não pode depender do código ser secreto.

- **Fase C (15/11/2026):** C2 nota pela história inteira (feita); C3 só o admin altera o histórico e o menu ⋮ do grupo, mesmo o admin digita senha (atrito, não segurança; a proteção real é o RLS); C1 preview "Entra:"; C5 `F2_T6_share_link.sql` para `docs/sql/` sem token. Detalhe em `ARCHITECTURE.md` §15 e `docs/C-TASK.md`.

## Perguntas em aberto

1. **Insígnias personalizadas** (`custom_badges_*`, só no aparelho): só o Enzo cria ou outros admins também? E o comportamento "apagar do catálogo não remove do jogador" (BACKLOG 2d) é desejado?
2. Perguntas específicas da Fase 2 (token no navegador, domínio, `session_arrivals`): ver `docs/F2-TASK.md`.

~~Resolvidas~~ (histórico): site antigo em React; resultado do inventário (T0d); apagar telas inalcançáveis (T0g); quem renomeia jogador; regra do percentual de "Mais perdeu junto"; grupos de outras pessoas; `match_screen` na web (**não existe na web**).

## Ajustes pendentes nos outros docs (feitos na C4, 15/11/2026)

- [x] `ARCHITECTURE.md` regra 5 com as exceções aditivas (T6 e S1); seção 7 (link `#/g/<token>`, Cloudflare Pages, web sem `match_screen`); B6 e §11 com "exceto o Fut do INF"; status do topo com a contagem real (322, não 217/222/320).
- [x] `DUVIDAS.md` #19 (itens 7, 8 e 18): "`match_screen` não existe na web" marcado como decidido; item 11 corrigido (editar/excluir grupo exige admin).
- [x] Referências a `docs/sql/...` trocadas por `docs/F2_T6_testes.md` e `docs/S1_players_select_rls.sql`; `F2_T6_share_link.sql` registrado como fora do repositório (C5).
- [ ] Trocar as referências a `docs/TASKS.md` nos documentos de contexto pelos arquivos por fase: os documentos de contexto agora são históricos (aviso no topo) e não foram reescritos.
