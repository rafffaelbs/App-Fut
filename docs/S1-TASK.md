# S1-TASK.md — Segurança: quem pode ler a tabela `players`

> Tarefa de segurança fora das fases de produto. O agente lê `docs/ARCHITECTURE.md` e este arquivo.
> Status (08/11/2026): **desenho concluído (Passos 0 e 1 feitos).** Falta: S1b (mudança no app, AG) → instalar nos admins → S1a (SQL) → testes. Nada foi aplicado no banco. Prioridade: alta, **não urgente**.

## Cabeçalho a colar no INÍCIO de todo prompt do AG desta tarefa

```
Contexto: leia docs/ARCHITECTURE.md (seções 2, 4 e 9) e docs/S1-TASK.md antes de começar.
Regras: o app personal não pode mudar de comportamento visível; não altere fórmulas dos
calculators, nomes de tabelas/colunas do Supabase, RLS ou RPCs (o SQL é feito pelo Claude e
executado pelo Enzo, nunca por você); não altere chaves de SharedPreferences; não mexa na
proteção contra queda de internet (fila de envio, CacheStore, estado local da partida,
snapshot do elenco) além do que a tarefa descreve; não adicione pacotes; preserve os textos
de erro existentes. Só lib/data/supabase/ e lib/bootstrap_personal.dart podem importar
supabase_flutter. Se encontrar algo que o documento não cobre, NÃO decida: registre em
docs/DUVIDAS.md (arquivo, linha, o que viu) e continue com o resto.
IMPORTANTE: altere o CÓDIGO, não só a documentação.
Ao terminar: rode `flutter analyze` e `flutter test`, faça commits pequenos e me diga em
5 linhas o que mudou e o que ficou pendente. Mostre a saída de `git diff main --stat`.
```

## O problema (confirmado em 03/11/2026)

- A policy `players_select` é `auth.uid() IS NOT NULL`: **qualquer usuário logado lê todas as linhas de `players` de todos os grupos**, inclusive a coluna `email` (`has_column_privilege` = `true`).
- O cadastro no app é aberto e outras pessoas já criaram contas e grupos (BACKLOG B6).
- Tamanho real (Passo 0, 08/11): 79 jogadores no banco, 71 no Fut do INF, 8 sem grupo (nenhum com e-mail); **só 2 jogadores têm e-mail**; 17 usuários em `auth.users` (esses e-mails não são expostos pela API).
- Visitante sem login (`anon`) **não** lê nada. O site novo (Fase 2) não é afetado: nunca devolve `email`.

## Metas e não-metas

- **Meta:** estranho não vê jogadores de grupos alheios. Quem é de um grupo continua vendo exatamente o que vê hoje.
- **Meta:** zero mudança visível no app para o uso normal.
- **Não-meta:** esconder o e-mail de colegas do mesmo grupo (**estágio 2 descartado**: o app nunca exibe e-mail de jogadores — só chega no aparelho dentro do `select(*)` — e há apenas 2 e-mails no banco). Reavaliar só se o número crescer.
- **Não-meta:** mexer em INSERT/UPDATE/DELETE de `players` nem no resto do RLS.

## Resultados da investigação (Passos 0 e 1)

- `is_group_member(gid)`: verdadeiro se há em `group_members` do grupo um jogador com `creator_id = auth.uid()`.
- Funções `SECURITY DEFINER` (ignoram o RLS, então login e convites não são afetados): `claim_ghost_profile`, `approve_join_request`, `reject_join_request`, `handle_new_user_link_ghost`.
- **Quebra certa — `createGhostPlayer` (`players_repository.dart:155-184`):** grava o jogador com `creator_id` nulo, usa `.insert().select().single()` (pede a linha de volta) e só **depois** insere em `group_members`. Com a policy nova, a linha não é legível no `RETURNING` e o insert falha. → **S1b**.
- **Bug antigo — `players_repository.dart:138`:** quando o elenco do grupo vem vazio, o app faz `select()` em **todos** os jogadores e grava no cache do grupo (mistura grupos). Com a restrição devolveria só os visíveis. → **S1b** troca por lista vazia, sem tocar no caminho de erro/offline.
- Leituras com jogadores embutidos (`group_members → players(*)`, `match_lineups(*, players(*))`, `players!inner(...)`) continuam funcionando: os jogadores de grupos do usuário são visíveis. Os `update(...).select().single()` também, pois o jogador editado está no grupo ou é do próprio usuário.
- Nenhuma tela depende de ler jogador de outro grupo. Nenhuma tela exibe e-mail de jogador.
- `rating_history` (sem uso) não entra na regra de visibilidade; `session_arrivals` entra.

## Desenho

**S1a — SQL (`docs/sql/S1a_players_select_rls.sql`):** função `visible_player_ids()` (`SECURITY DEFINER`) devolve os ids visíveis para o usuário atual: membros dos grupos dele, mais quem aparece em escalações, eventos (autor/assistência) ou presenças desses grupos. A policy vira `creator_id = auth.uid() OR id IN (SELECT visible_player_ids())`. A subconsulta é calculada **uma vez por consulta** (e não por linha), para não pesar nas leituras que embutem jogadores (4709 escalações). Inclui bloco DESFAZER.

**S1b — app (AG):** `createGhostPlayer` passa a inserir o jogador **sem pedir a linha de volta**, insere em `group_members` e só então lê o jogador; e o plano B sem filtro do elenco passa a devolver lista vazia.

## Ordem de aplicação (importante)

1. **S1b:** AG implementa, Claude Code revisa, você testa e faz o merge.
2. **Instalar a versão nova nos admins** (quem cria jogadores). Com o app antigo, "adicionar jogador" quebra depois da S1a.
3. Backup com dados no mesmo dia; horário de pouco uso.
4. **S1a:** rodar o SQL; rodar os testes abaixo.
5. Se algo falhar, rodar o bloco DESFAZER na hora e me mandar o erro.

---

## S1b · `createGhostPlayer` sem RETURNING e fim do plano B sem filtro — AG, revisão CLAUDE

Branch: `fix/ghost-player-insert` (criada a partir da `main`, independente da T5) · Mexe no repositório de jogadores, perto do cache offline: exige revisão e o item 9 do checklist (modo avião).

```
[cabeçalho]
Contexto: vamos restringir o SELECT da tabela players no Supabase (RLS). Depois disso, um
insert que pede a linha de volta (RETURNING) só funciona se a linha já for legível pelo
usuário. Faça as mudanças abaixo em lib/data/supabase/players_repository.dart. O comportamento
visível do app não muda.

1) createGhostPlayer (~linhas 155-184). Hoje: .insert(...).select().single() com creator_id
   nulo e só depois insere em group_members. Mude para:
   a) gerar o id no app (já é gerado perto da linha 162; mantenha);
   b) inserir o jogador SEM .select() (sem RETURNING);
   c) inserir em group_members (como hoje);
   d) só então ler o jogador por id (select().eq('id', id), a mesma consulta de getPlayerById)
      e devolver o PlayerModel. Se a leitura falhar, não esconda o erro.
   Preserve exatamente: invalidação de cache (players:group:<groupId>), os textos de erro, a
   checagem de permissão e a chamada a GroupBootstrap.refreshLocalSnapshot feita pelas telas.
   Se já existir algum "desfazer" quando group_members falha, mantenha; se não existir, NÃO crie:
   registre em docs/DUVIDAS.md (jogador órfão com creator_id nulo fica invisível).

2) Plano B sem filtro (~linha 138): hoje, quando o elenco do grupo vem vazio ou dá erro, o
   código faz from('players').select() SEM filtro e grava essa lista no cache do grupo. Mude
   SOMENTE o ramo "elenco vem vazio": devolver lista vazia, sem consultar players sem filtro e
   sem gravar essa lista no cache do grupo. NÃO altere o ramo de erro/rede/cache offline
   (CacheStore): o comportamento offline fica idêntico. Se não ficar claro qual ramo é qual,
   NÃO mude nada aqui e registre em docs/DUVIDAS.md com as linhas.

3) Faça grep em lib/ por outros .insert(...).select( que envolvam a tabela players ou
   embutam players, e liste em docs/DUVIDAS.md (arquivo:linha). Não altere createPlayerWithUser
   (grava creator_id = userId) nem nada fora dos itens 1 e 2.

4) Testes (padrão dos testes de repositório existentes; sem pacotes novos; se o cliente
   Supabase não puder ser simulado, extraia a montagem do payload e a ordem das operações em
   funções puras e teste essas): (a) createGhostPlayer não pede a linha de volta no insert do
   jogador e só lê depois de inserir em group_members; (b) elenco vazio devolve [] sem consulta
   sem filtro; (c) caminho de erro com cache continua devolvendo o cache.

Aceite: analyze e test ok; git diff -M main --stat mostra só players_repository.dart, testes e
DUVIDAS.md; checklist manual itens 1 a 4 e 9; criar jogador e adicionar a uma pelada continua
funcionando com a policy ATUAL (a mudança é compatível com antes e depois da S1a).
```

### Prompt de revisão (Claude Code, somente leitura)

```
Revise a branch fix/ghost-player-insert em modo SOMENTE LEITURA. Não rode git checkout,
switch nem stash; para ver a versão antiga use `git show main:<arquivo>`. Use
`git diff -M main...HEAD`. Não corrija nada. Responda cada item com arquivo:linha e OK/PROBLEMA:
1. createGhostPlayer: o insert do jogador não pede mais a linha de volta? A ordem é insert
   player → insert group_members → leitura por id? A invalidação de cache e os textos de erro
   são os mesmos de main?
2. Se a inserção em group_members falhar, o que acontece com o jogador já inserido? Mudou algo
   em relação a main?
3. Plano B (~linha 138): só o ramo "elenco vazio" mudou? O ramo de erro/rede/cache offline
   está idêntico a main? Algo ainda grava a lista de todos os jogadores no cache de um grupo?
4. Algum outro método de players_repository.dart ou de outro arquivo foi alterado? (não deveria)
5. Os testes falhariam sem a correção? Cobrem a ordem das operações?
6. A fila de envio (pending_matches_v1), o CacheStore e o snapshot players_<groupId> foram
   tocados além do que a tarefa permite?
Termine com riscos para o app pessoal e se está seguro para merge.
```

---

## S1a — SQL

`docs/sql/S1a_players_select_rls.sql` (validado só em sintaxe). **Não rodar antes dos passos 1 a 3 da "Ordem de aplicação".**

## Testes da S1a

**Antes de aplicar** (medir a situação atual), no SQL Editor, simulando você logado (`COLE_SEU_USER_UUID` = `select id, email from auth.users;`):

```sql
begin;
set local role authenticated;
select set_config('request.jwt.claims',
  json_build_object('sub','COLE_SEU_USER_UUID','role','authenticated')::text, true);
select count(*) as vejo_antes from public.players;   -- hoje: 79
explain analyze
select count(*) from public.match_lineups l join public.players p on p.id = l.player_id;
rollback;
```

**Depois de aplicar**, repetir e comparar:

```sql
-- a) você (admin do Fut do INF): esperado >= 71 e a mesma contagem de joins de antes
begin;
set local role authenticated;
select set_config('request.jwt.claims',
  json_build_object('sub','COLE_SEU_USER_UUID','role','authenticated')::text, true);
select count(*) as vejo_depois from public.players;
explain analyze
select count(*) from public.match_lineups l join public.players p on p.id = l.player_id;
-- esperado: mesmo count do join de antes; tempo na mesma ordem de grandeza (milissegundos)
rollback;

-- b) um estranho (sem grupo e sem jogadores criados): esperado 0
begin;
set local role authenticated;
select set_config('request.jwt.claims',
  json_build_object('sub', gen_random_uuid()::text,'role','authenticated')::text, true);
select count(*) as estranho_ve from public.players;
rollback;

-- c) visitante sem login: esperado 0 e SEM erro
begin;
set local role anon;
select count(*) as anon_ve from public.players;
rollback;
```

Repetir (a) com o `sub` de **outro membro real** do grupo: deve ver o elenco do grupo.

**No app (celular), já com a policy aplicada:**
1. Entrar, ver grupos, ranking, estatísticas, carta de jogador, comparação e histórico (inclusive jogadores antigos).
2. **Criar um jogador novo** num grupo de teste e adicioná-lo a uma pelada; renomear; remover do elenco. (Cobre a S1b na prática.)
3. "Adicionar jogadores" numa pelada e abrir uma pelada antiga.
4. Conta nova (e-mail de teste): cadastrar, completar perfil, pedir entrada por código; no admin, aprovar e vincular a um fantasma.
5. Conferir que o site (Fase 2) e o `get_group_snapshot` seguem funcionando.
6. Medir o tempo de abrir o ranking do grupo (a leitura com 4709 escalações): não pode ficar perceptivelmente mais lento que antes.

Se **qualquer** item falhar: rodar o bloco DESFAZER do SQL e me mandar o erro.

## Registro

Adicionar ao `BACKLOG.md` (prioridade alta) e, depois de aplicado, ao `ARCHITECTURE.md` (seção de RLS). Esta tarefa abre uma **segunda exceção à regra de ouro 5** (substitui uma policy existente), reversível.
