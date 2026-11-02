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

## Onde estamos (02/11/2026)

- **Fase 0 e Fase 1 concluídas e na `main`** (T0 a T4): interfaces em `lib/domain/`, `AppServices`, `AppFeatures`, camada `lib/data/supabase/` e `lib/data/prefs/`. 162 testes passando, 0 erros no analyze, isolamento do Supabase verificado. A tag `pre-refactor` marca o app antes da refatoração.
- A **proteção contra queda de internet** (estado local da partida, fila `pending_matches_v1`, `CacheStore`, snapshot do elenco) **não pode ser alterada** sem tarefa própria (seção 9 do ARCHITECTURE).
- Nos testes apareceram **bugs que já existiam na versão original** (nenhum é regressão). Decidi tratá-los como bugs a corrigir com calma, partindo da `main` atual. Estão no `BACKLOG.md` seção 0 e viraram a **Fase 1b** do `TASKS.md`:
  - **B1** criar grupo falha (insert em `seasons` sem `id`) e deixa grupo órfão. **Prioridade alta.**
  - **B2/B3** jogador novo não aparece na pelada já aberta; renomear jogador só grava no celular (nunca no Supabase) e a comparação mostra "Desconhecido".
  - **B4** estatísticas avançadas com percentual errado: **já corrigi e validei (02/11)**; não precisa de tarefa. Ideia futura: oferecer as duas visões de percentual, com mínimo de jogos para não dar 100% eterno.
  - **B5** partida presa na fila de envio quando o banco recusa (ex.: jogador apagado), bloqueando as seguintes e inflando as estatísticas.
  - **Abrir o app sem rede:** tela "Como podemos te chamar?" aparece quando falta rede; fila só reenvia ao abrir a tela de partida.
  - **B6** (não é bug de código): qualquer pessoa com o app cria grupos (outras pessoas já criaram "du", "du fut", "Baba do Carlos"). Isso reforça o site e o app offline.
- Pendências minhas: rodar no Supabase a consulta de temporadas por grupo e apagar os grupos "Teste" órfãos (TASKS, pergunta 6); testar o que faltou do roteiro da T4 (criar/apagar grupo, partes 11 e 12 do teste de não admin, virar cada flag); commitar os docs atualizados e o `Plano_de_Acao.md`.

## Próximos passos (ordem)

1. **Fase 1b**: B1 → B2/B3 → B5 → B6 (abrir sem rede). Decidido: só admin renomeia qualquer jogador e o dono do perfil renomeia o próprio. A arquitetura de grupos (quem pode criar grupo etc.) **ainda não é meu foco**; priorize só se achar necessário.
2. **Fase 2 (site)**: T5 a T7b do `TASKS.md`. Detalhar os prompts quando a 1b terminar. Cuidado: `PlayerComparisonScreen` e o modal de adicionar jogadores dependem do snapshot `players_<groupId>`, que na web não existe.
3. **Fase 3 (app público)**: T8 a T15.

Peça para eu começar pela T-B1: escreva o prompt do AG e o de revisão do Claude Code.

## Lições do processo (para evitar repetir)

- O AG às vezes altera só o documento e não o código: sempre pedir "altere o CÓDIGO, não só a documentação" e conferir com `grep`/`git diff`.
- Os inventários continham erros (método `_onAppResumed`, botão "TESTAR CONEXÃO"): quando o código discorda do doc, o código vale e o doc é corrigido.
- O Claude Code já rodou `git checkout main` por engano: manter a linha de proibição nos prompts de revisão.
- Prefiro `git diff -M` nas revisões de arquivos movidos.
