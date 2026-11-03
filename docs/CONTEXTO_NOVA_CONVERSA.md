# Contexto para a nova conversa (App do Fut)

Cole este texto na primeira mensagem e anexe: `ARCHITECTURE.md`, `TASKS.md`, `BACKLOG.md`, `ESTADO_ATUAL.md` (todos de `docs/`). O `DUVIDAS.md` só se eu pedir.

## Quem sou eu e como quero trabalhar

Sou o Enzo, analista de implantação (formação em Ciência da Computação, mas **não sou muito técnico em Flutter**) e quero **aprender o processo**, então explique de forma simples e diga o porquê. Português. Prefiro passos curtos e claros, sem me deixar perdido entre branches.

Fluxo de trabalho:
- **Você (Claude, nesta conversa)** é o arquiteto: planeja, escreve prompts, atualiza os docs, decide o que revisar.
- **Antigravity (AG)** executa as tarefas de volume. Eu colo o prompt que você escrever (sempre com o cabeçalho do `TASKS.md`).
- **Claude Code** só **revisa, somente leitura**, com prompts que você escreve. Todo prompt de revisão inclui: "não rode git checkout, switch nem stash; para ver a versão antiga use `git show pre-refactor:<arquivo>`".
- **Eu** testo no celular (ou `flutter run -d linux`), faço merge e push.
- Cada tarefa = uma branch. Prefira me dizer o comando exato do git.

## O projeto

App Flutter de gestão de pelada de futsal (repo `~/Documents/github/App-Fut`, backend Supabase). Objetivo: um código, vários apps:
1. **personal** (meu app, Supabase, admin, tema Blue Lock): fica como está.
2. **site somente leitura (Flutter Web)** para quem usa iPhone ver rankings e estatísticas por **link secreto, sem login** (substitui o site React antigo que lê `sync_data`).
3. **app público offline** (SQLite/drift, sem login, dono = admin, tema neutro, 1 grupo, botões exportar/importar `.db`).

## Onde estamos (03/11/2026)

- **Fase 0, Fase 1 e Fase 1b concluídas e na `main`** (T0 a T4 e T-B1 a T-B6c): interfaces em `lib/domain/`, `AppServices`, `AppFeatures`, camada `lib/data/` (Supabase e SharedPreferences), fila outbox com isolamento de erros permanentes e cache offline de grupos. 217 testes passando, 0 erros no analyze. A tag `pre-refactor` marca o app antes da refatoração.
- A **proteção contra queda de internet** (estado local da partida, fila `pending_matches_v1` com isolamento de falhas, `CacheStore` com `groups:my:<userId>`, snapshot do elenco) foi fortalecida e comprovada.
- Os **bugs da Fase 1b** foram todos corrigidos e integrados:
  - **B1 / B1b** criar grupo e temporada (UUID v4 gerado no cliente, rollback reverso em caso de falha).
  - **B2/B3** cache do elenco e nome do jogador (invalidação de cache, refresh do snapshot e persistência de nome no Supabase via `updatePlayer` com permissão de admin ou dono).
  - **B4** estatísticas avançadas com percentuais corrigidos.
  - **B5** isolamento de partidas com erro permanente na fila outbox sem bloquear envios e fora das estatísticas.
  - **Abrir o app sem rede (T-B6/B6b/B6c):** tela de perfil não bloqueia offline (`ProfileCheckResult.failed`), `HomePage` carrega grupos salvos em cache local com aviso, e ícone de pendências na AppBar.
  - **B6** (não é bug de código): decisão de desenho; grupos legados foram apagados em 02/11 pelo Enzo; discussão volta após o app offline.

## Próximos passos (ordem)

1. **Fase 2 (site somente leitura)**: T5 a T7b do `TASKS.md`. Cuidado: `PlayerComparisonScreen` e o modal de adicionar jogadores agora contam com fallback no repositório, facilitando a adaptação para a web.
2. **Fase 3 (app público)**: T8 a T15.

## Lições do processo (para evitar repetir)

- O AG às vezes altera só o documento e não o código: sempre pedir "altere o CÓDIGO, não só a documentação" e conferir com `grep`/`git diff`.
- Os inventários continham erros (método `_onAppResumed`, botão "TESTAR CONEXÃO"): quando o código discorda do doc, o código vale e o doc é corrigido.
- O Claude Code já rodou `git checkout main` por engano: manter a linha de proibição nos prompts de revisão.
- Prefiro `git diff -M` nas revisões de arquivos movidos.
