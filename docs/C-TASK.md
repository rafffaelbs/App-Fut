# C-TASK.md: Correções pós-Fase 2 (C1 a C4)

Criado em 15/11/2026. Reúne as correções que saíram da revisão das sugestões do AG e da validação feita pelo Claude Code. Este arquivo é a fonte da verdade dos prompts da fase C, como o `F2-TASK.md` é para a Fase 2.

**Regra de ouro:** quando o código discorda do doc, o código vale e o doc é corrigido.
**Fluxo:** uma tarefa = uma branch, sempre a partir da `main` limpa. Só passa para a próxima depois do merge da anterior.

## Papéis
- **Claude (conversa do projeto):** arquiteto. Planeja, escreve prompts e docs, valida o que os agentes entregam.
- **Antigravity (AG):** executa as tarefas de volume, com o cabeçalho abaixo colado antes do prompt.
- **Claude Code:** revisa em sessão nova, **somente leitura**. Quem escreveu o código não revisa. Todo prompt de revisão inclui: "não rode git checkout, switch nem stash; para ver a versão antiga use `git show pre-refactor:<arquivo>`".
- **Enzo:** testa, faz merge e push.

## Cabeçalho da fase C (colar antes de qualquer prompt do AG)

```
Projeto: App-Fut (Flutter, futsal; backend Supabase; repo público). Fase C: correções pós-Fase 2.

REGRAS
- Altere o CÓDIGO (não só o documento). No fim, rode `git diff main --stat` e mostre; se só docs mudaram, a tarefa NÃO está feita.
- Uma tarefa = uma branch, criada da main com `git status` limpo. Se não estiver limpo, PARE e avise.
- Commite somente os arquivos da tarefa (git add por arquivo; `git add -p` se o arquivo for compartilhado). Sem merge e sem push.
- Só lib/data/supabase/ e lib/bootstrap_personal.dart importam supabase_flutter. Não quebre isso.
- A proteção offline do app (fila pending_matches_v1, CacheStore, estado local da partida, snapshot do elenco) NÃO pode ser alterada sem tarefa própria.
- Antes de qualquer mudança no banco: backup (supabase db dump --remote="hcjiqushursknfsdvavy" --data-only --use-copy -f ~/backups/backup_dados_AAAA-MM-DD.sql). Nenhuma tarefa da fase C mexe no banco sem eu pedir.
- Rode `flutter analyze` e `flutter test` e informe os números. Baseline: 322 testes passando (conferido em 15/11/2026, já com a C2); o analyze tem avisos antigos (DUVIDAS #39), só erros novos contam.
- Quando o código discorda do doc, o código vale.
- Responda em português, simples.
```

## Status

| ID | Tarefa | Quem | Branch | Estado |
|---|---|---|---|---|
| C2 | Nota do jogador pela história inteira | Claude Code | `fix/rating-all-history` | ✅ feita e mesclada na `main` (merge `027fb03`, 15/11/2026) |
| C4 | Atualizar os docs (22 correções + registros) | Claude Code ou AG | `docs/atualizacao-2026-11-15` | ✅ feita em 15/11/2026 (commit único na branch; falta o merge do Enzo) |
| C3 (invest.) | Investigar senha e RLS do histórico | Claude Code (leitura) | sem branch | prompt pronto |
| C3a | Esconder ações de edição de quem não é admin | AG | `fix/admin-only-actions` | prompt pronto; depende do relatório da investigação |
| C3b | Conferir RLS real de matches/sessions | Enzo roda o SQL | sem branch | SQL sai da investigação |
| C3c | Redesenhar a senha do histórico | a decidir | a decidir | depende da investigação |
| C1 | Preview "Entra:" no fim de partida | AG | `fix/entering-preview` | prompt pronto; exige teste de modo avião |
| C5 | Mover `F2_T6_share_link.sql` para `docs/sql/` (sem token) | Enzo fornece o arquivo | `docs/share-link-sql` | pendente |

Ordem: C2 ✅, C4 ✅, C3 (invest.), C3a, C1, C5 (C3b e C3c quando o relatório voltar). Estado de todas as tarefas: `docs/TASKS.md`.

## Decisões que valem para a fase C
- **C2:** nota e overall pela história inteira em todas as telas; gols, jogos e posição continuam respeitando o filtro de período.
- **C3:** todos veem a lista de partidas do histórico; só o admin altera (lixeira "Limpar tudo", lápis, toque longo de debug); mesmo o admin precisa de senha para alterar o histórico. Menu ⋮ do grupo (Editar/Excluir) só para admin. A senha dentro do app é atrito contra clique acidental, não segurança: a proteção real é o RLS exigir admin.
- **A3 (T7b):** continua por último. O envio ao site antigo é um Timer de uso único de 90 s, rearmado após cada partida finalizada (`match_screen.dart:3713-3725`), não um ciclo.

---

## C2: nota pela história inteira

**Problema:** Elenco, comparação e snapshot (`players_screen.dart:108-132`, `player_comparison_screen.dart:94-95`, `group_bootstrap.dart:193`) usam todas as partidas; a carta (`player_detail.dart:340, 3871`) usa o período escolhido na tela (padrão: temporada ativa).

**Aceite:** a nota e o overall são iguais no Elenco e na carta, mesmo com o filtro da carta em outro período. Gols, jogos e posição no ranking continuam respeitando o filtro. Teste novo cobrindo isso.

**Prompt (Claude Code):**

```
Você é o EXECUTOR desta tarefa (C2) no repositório App-Fut. Não rode git stash. Branch única: fix/rating-all-history.

Decisão do Enzo: a nota e o overall do jogador valem pela HISTÓRIA INTEIRA (todas as partidas), em todas as telas.

1. Confirme que está na main e que git status só mostra arquivos untracked de docs (não os inclua no commit). Se houver alteração em código, PARE e avise. Crie a branch fix/rating-all-history.
2. Em player_detail.dart (~320-370 e onde 3871 usa o período), faça nota e overall usarem _rawHistory (história inteira). Gols, jogos, posição no ranking e demais estatísticas continuam usando o filtro de período.
3. Reconfira players_screen.dart:108-132, player_comparison_screen.dart:94-95 e group_bootstrap.dart:193; mude só o que divergir. ranking_screen.dart:301 (ranking da pelada) e season_stats_screen.dart:113-121 (média do período) são legítimos e NÃO mudam.
4. Teste novo: o mesmo jogador, com partidas em temporadas diferentes, tem a mesma nota no Elenco e na carta, mesmo com filtro de período diferente de "história inteira".
5. Rode flutter analyze e flutter test. Informe os números (esperado: 320 + os novos).
6. Commit só dos arquivos da tarefa. Sem merge e sem push. Mostre git diff main --stat.
7. NÃO mexa no match_screen nem na proteção offline. Se a UI da carta puder indicar "nota do histórico" sem mexer em layout, faça; senão, não faça e me avise.
```

---

## C4: atualizar os docs

**Objetivo:** corrigir a documentação conforme a validação das 14 contradições, as contradições novas e os registros no backlog. Só `docs/`, nenhum arquivo de código.

**Executada em 15/11/2026 no commit único da branch `docs/atualizacao-2026-11-15` (hash: `git log -1 docs/atualizacao-2026-11-15`); ver `docs/DIAGNOSTICO_AG_2026-11-15.md` e `TASKS.md`.**

---

## C3 (investigação): senha e RLS do histórico

**Objetivo:** descobrir quais ações alteram o histórico, como a senha "0101" (`history_screen.dart:212`) funciona, e escrever o SQL de leitura para o Enzo conferir o RLS real. Somente leitura.

**Prompt (Claude Code, sessão de revisão):**

```
Tarefa SOMENTE LEITURA. Não altere arquivos, não rode git checkout, switch nem stash. Não rode nada contra o banco de produção (nem supabase db, nem SQL remoto): você só escreve SQL para o Enzo rodar.

CONTEXTO (decisões do Enzo)
- Histórico de partidas: TODOS veem a lista; só o admin pode alterar. Mesmo o admin precisa digitar uma senha para alterar o histórico.
- Menu ⋮ do grupo (Editar/Excluir): só admin.
- Hoje há uma senha fixa "0101" em history_screen.dart:212, num repositório PÚBLICO.

ENTREGUE:
1. SENHA: liste TODAS as ações que alteram o histórico (lixeira "Limpar tudo", lápis de edição, toque longo de debug, exclusão de partida, updateFullMatch, qualquer outra) com arquivo:linha, e diga para cada uma se hoje exige a senha, exige admin, os dois ou nenhum. Diga onde a senha é verificada e se existe outro lugar com senha hardcoded (grep por números de 4 dígitos usados como PIN, "senha", "password", "pin").
2. PROPOSTA DE SENHA: apresente 2 ou 3 opções para guardar e conferir a senha sem deixá-la literal no código público (ex.: dart-define no build, definida pelo admin no aparelho e guardada com hash em SharedPreferences, ou outra que você ache melhor). Para cada uma: esforço, o que protege e o que NÃO protege. Deixe claro que é atrito contra clique acidental, não segurança; a proteção real é o RLS.
3. RLS: escreva o SQL (somente SELECT) para o Enzo rodar no SQL Editor do Supabase e responder: (a) as policies reais de UPDATE e DELETE de matches, sessions e das tabelas de eventos/partidas que o histórico altera (consulte pg_policies e use os nomes das tabelas que o código realmente usa, com arquivo:linha); (b) se um membro comum (não admin) consegue UPDATE/DELETE nelas; (c) como ler o resultado (o que significaria "ok" e o que significaria "exposto"). Se existirem arquivos .sql em docs/ que já descrevam essas policies, cite-os.
4. LISTA EXATA DE UI para esconder de quem não é admin: menu ⋮ da lista de grupos (main_personal.dart:834-860) e as ações do histórico (history_screen.dart:260-262, 14-331), usando permissions.isAdmin(groupId) + features.canAdminister. Diga como o histórico deve ficar para membro comum (só a lista) e para admin (ações + senha), em termos do código atual, e quais testes existentes cobrem essas telas.
5. Riscos: o que pode quebrar ao esconder essas ações (cache offline, isReadOnly do site, testes).

Responda em português, simples, com arquivo:linha.
```

---

## C3a: esconder ações de edição de quem não é admin

**Aceite:** membro comum vê a lista de partidas do histórico sem nenhuma ação de alteração e não vê o menu ⋮ do grupo; admin continua como hoje (inclusive a senha "0101", que NÃO muda nesta tarefa). Testes de widget para membro comum e admin em cada tela.

**Prompt (AG):** cole o cabeçalho da fase C e depois:

```
Tarefa C3a: esconder ações de edição de quem não é admin. Branch: fix/admin-only-actions.

O que fazer:
1. Menu ⋮ "Editar / Excluir" da lista de grupos (main_personal.dart:834-860): só aparece se o usuário for admin DAQUELE grupo, usando AppServices.instance.permissions.isAdmin(groupId) junto com features.canAdminister(isAdmin). Para quem não é admin, o menu não existe.
2. Histórico (history_screen.dart:260-262 e 14-331): TODOS continuam vendo a lista de partidas. Para quem não é admin, somem a lixeira "Limpar tudo", o lápis de edição e o toque longo de debug (nenhum menu ⋮ para membro comum). Para admin, tudo continua como está hoje, inclusive a senha "0101" (NÃO altere nem mova a senha nesta tarefa).
3. Não altere repositórios, RLS, match_screen nem a proteção offline. Não mude o comportamento do site somente leitura (isReadOnly continua escondendo tudo).
4. Testes: para cada tela, um teste de widget com membro comum (não aparece) e com admin (aparece), seguindo o padrão de testes existente.
5. Rode flutter analyze e flutter test e informe os números (esperado: 322 + os novos).
```

**Depois:** revisão em sessão nova do Claude Code e teste manual do Enzo com uma conta de membro comum.

---

## C1: preview "Entra:" no fim de partida

**Problema:** `_calculateEnteringPlayers` (`match_screen.dart:3682-3702`) só pula quem fica em campo e quem desistiu; não exclui quem está saindo. O diálogo de fim de partida (`match_finish_confirmation_dialog.dart:306`, dados de `match_screen.dart:3579, 3592, 3607`) mostra em "Entra:" os próprios jogadores que saem. O fluxo real (`_processMatchExit`, 4119-4180) está certo e NÃO muda. Possível mesmo defeito em `enteringForSplit` (3611-3614), que filtra só os vencedores: verificar.

**Cenário que reproduz:** presença A, B, C, D (vermelho), E, F, G, H (branco); ao terminar, o diálogo sugere "Tirar o Time Branco" e em "Entra:" aparece E, F, G, H. Com fila vazia e "Sair os 2 times", "Entra:" lista os jogadores que saem em vez de "Nenhum jogador na fila".

**Aceite:** a pré-visualização mostra exatamente quem o fluxo real vai colocar em campo. Teste de modo avião no aparelho depois do merge.

**Prompt (AG):** cole o cabeçalho da fase C e depois:

```
Tarefa C1: corrigir a pré-visualização "Entra:" do diálogo de fim de partida. Branch: fix/entering-preview.

1. Em _calculateEnteringPlayers (match_screen.dart:3682-3702), exclua da sugestão TODOS os jogadores que estão em teamRed e teamWhite, igual ao fluxo real em _processMatchExit (4146-4148). O fluxo real NÃO muda.
2. Confira enteringForSplit (3611-3614): se também puder incluir perdedores antes da fila, corrija pelo mesmo critério e explique o que fez.
3. Quando a fila estiver vazia, o diálogo deve mostrar "Nenhum jogador na fila" em vez de listar quem sai.
4. Teste: se _calculateEnteringPlayers for privado e não testável, extraia SÓ o cálculo para uma função pura (em utils/), sem mudar o comportamento, e teste-a: (a) primeira troca com 8 jogadores, "Tirar o Time Branco" → Entra vazio ou só quem está de fato fora dos times; (b) fila menor que quem sai; (c) fila vazia com "Sair os 2 times".
5. NÃO altere _processMatchExit, a fila offline nem o estado local da partida. Mostre o git diff do match_screen inteiro no relatório.
6. Rode flutter analyze e flutter test e informe os números. Lembre o Enzo de testar em modo avião antes do merge (esta tarefa mexe no match_screen).
```

---

## C5: `F2_T6_share_link.sql` no repositório

O arquivo existe só na máquina do Enzo e os docs o citam como `docs/sql/F2_T6_share_link.sql`. Mover para `docs/sql/` **sem nenhum token dentro** (as funções e a tabela podem ficar; o valor do token não). Branch `docs/share-link-sql`. Depois ajustar as citações nos docs, que na C4 apontam para `docs/F2_T6_testes.md` e `docs/S1_players_select_rls.sql`.

---

## Trechos para colar nos outros docs

**TASKS.md, tabela de fases e tarefas:**

```
| C1 | Preview "Entra:" no fim de partida (match_screen.dart:3682-3702) | C | AG | fix/entering-preview | ⏳ prompt pronto (docs/C-TASK.md), exige teste de modo avião |
| C2 | Nota do jogador pela história inteira | C | Claude Code | fix/rating-all-history | ⏳ prompt pronto |
| C3 | Ações de edição só para admin (menu ⋮ do grupo e histórico) + senha + RLS | C | investigação, AG | fix/admin-only-actions | ⏳ investigar, depois C3a, C3b, C3c |
| C4 | Atualizar os docs conforme a validação de 15/11 | C | Claude Code ou AG | docs/atualizacao-2026-11-15 | ⏳ prompt pronto |
| C5 | Mover F2_T6_share_link.sql para docs/sql/ (sem token) | C | Enzo | docs/share-link-sql | ⏳ |
```

**F2-TASK.md, no encerramento (acrescentar):**

```
10. Correções pós-Fase 2 (C1 a C5), com prompts em docs/C-TASK.md. O item F2 do BACKLOG §0b ("botões que dão erro") NÃO estava resolvido: é a C3.
```

**F3-TASK.md:19:** trocar "depois do gate" por "depois da Fase 2 (encerrada em 15/11)". A Fase 3 continua sem prompts: a ordem é C-fase primeiro, T8 em seguida, e a T7b por último.
