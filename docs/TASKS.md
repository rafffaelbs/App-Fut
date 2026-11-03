# TASKS.md — Índice das tarefas (v5, atualizado em 03/11/2026)

> Este arquivo é só o **índice**. As tarefas, prompts, branches e prompts de revisão ficam em um arquivo por fase. O agente (AG ou Claude Code) lê `docs/ARCHITECTURE.md` e **apenas o arquivo da fase atual**.

## Arquivos

| Fase | Arquivo | Situação |
|---|---|---|
| Fase 0 (T0, T0b, T0c, T0d, T0e, T0g) | `docs/F0-TASK.md` | ✅ concluída e integrada na `main` (histórico) |
| Fase 1 (T1, T2, T3a a T3e, T4) e Fase 1b (T-B1 a T-B6c) | `docs/F1-TASK.md` | ✅ concluídas e integradas na `main`. 222 testes passando (histórico) |
| **Fase 2 (site somente leitura, T5 a T7b)** | **`docs/F2-TASK.md`** | **⏳ fase atual** |
| Fase 3 (app público offline, T8 a T15) | `docs/F3-TASK.md` | ⏳ depois da Fase 2 (prompts ainda não escritos) |

Ponto de partida oficial: a `main` atual. A tag `pre-refactor` fica só como referência de comparação.

## Como usar

- **Prompt para o AG:** abra o arquivo da fase, cole o *Cabeçalho* e depois o prompt da tarefa (a tarefa já tem a branch indicada).
- **Prompt de revisão para o Claude Code:** vem junto da tarefa, sempre somente leitura e com a proibição de `git checkout`, `switch` e `stash`.
- **Mudou um prompt durante o trabalho?** O Claude atualiza o arquivo da fase. O arquivo da fase é a fonte de verdade; não dependa do histórico do chat.
- **Fase concluída:** marcar como ✅ no índice, manter o arquivo como histórico e criar o da próxima fase no mesmo padrão.
- **Quem faz:** AG = Antigravity (executa) · CLAUDE = Claude (desenha ou revisa) · Enzo = testa, executa SQL e faz merge e push.

## Decisões já tomadas (resumo; o detalhe de cada fase está no arquivo dela)

- **Site antigo (React/Vercel)** não é mais usado e será removido no **fim da Fase 2** (T7b), junto do envio do pacote do site, `my_sync_code` e a tabela `sync_data` (que fica por último).
- **Web somente leitura:** link secreto sem login (token por grupo + funções `SECURITY DEFINER`). Login pode ser acrescentado depois sem refazer a arquitetura. Hospedagem: Cloudflare Pages com build no GitHub Actions.
- **Web sem `match_screen`.** Partida ao vivo e notificações de eventos ficam exclusivas do app.
- `data_migration_service` e `fix_event_times_service`: movidos para `tool/legacy/` (T0b).
- **App público:** um grupo só por enquanto; migrar para vários depois.
- `sync_service`/`cache_sync_manager` não são a proteção offline; viraram `SiteSyncService` e `DiagnosticsService` (T3c). A proteção offline é a fila, o cache, o estado local da partida e o snapshot do elenco (seção 9 do `ARCHITECTURE.md`).
- **Grupos:** o Enzo apagou do Supabase os grupos de teste e de outras pessoas em 02/11. **Resta o "Fut do INF" (dados reais de produção)** — qualquer mudança de banco exige backup antes. A discussão de arquitetura de grupos (quem cria, órfãos) volta depois do app offline.
- **Repositório:** hoje público. O Enzo pretende fechar a parte pessoal (app e site) e deixar aberto o app offline; a forma de separar fica para depois do app offline. A segurança não pode depender do código ser secreto.

## Perguntas em aberto

1. **Insígnias personalizadas** (`custom_badges_*`, só no aparelho): só o Enzo cria ou outros admins também? E o comportamento "apagar do catálogo não remove do jogador" (BACKLOG 2d) é desejado?
2. Perguntas específicas da Fase 2 (token no navegador, domínio, `session_arrivals`): ver `docs/F2-TASK.md`.

~~Resolvidas~~ (histórico): site antigo em React; resultado do inventário (T0d); apagar telas inalcançáveis (T0g); quem renomeia jogador; regra do percentual de "Mais perdeu junto"; grupos de outras pessoas; `match_screen` na web (**não existe na web**).

## Ajustes pendentes nos outros docs (ainda não feitos)

Quando o Enzo puder mexer no git, aplicar:

- `ARCHITECTURE.md` regra 5: acrescentar a exceção aditiva da Fase 2 (tabela `group_share_tokens` e funções novas); seção 7: link `#/g/<token>`, hospedagem Cloudflare Pages, web sem `match_screen`; seção 11 e `BACKLOG.md` B6: trocar "todos os grupos apagados" por "todos apagados, **exceto o Fut do INF**"; status do topo: 222 testes (hoje diz 217).
- `DUVIDAS.md` #19 (itens 7, 8 e 18): marcar "match_screen não existe na web" como decidido.
- Trocar as referências a `docs/TASKS.md` nos documentos de contexto pelos arquivos por fase.
