# F2-TASK.md — Fase 2: site somente leitura (iPhone), link secreto sem login

> **Fase atual.** O agente lê este arquivo e `docs/ARCHITECTURE.md` (seções 2, 4, 5, 7 e 9). Não precisa ler as outras fases.
> Ponto de partida: `main` com Fases 0, 1 e 1b concluídas (222 testes, 0 erros no analyze).
> Prompts marcados **RASCUNHO** serão revisados pelo Claude antes de serem usados (dependem do resultado de tarefas anteriores). Sempre que um prompt mudar, o Claude atualiza este arquivo.

## Status

| # | Tarefa | Quem | Branch | Situação |
|---|---|---|---|---|
| T5 | Telas seguras para web, flags `web_readonly`, esconder escrita | AG, revisão CLAUDE | `feat/web-readonly-screens` | ⏳ pronta para começar |
| T6 | Tabela de token + funções SQL no Supabase | CLAUDE (SQL) + Enzo (executa) | sem branch (arquivo `docs/sql/`) | ⏳ pode rodar em paralelo à T5 |
| T6b | Repositórios via token, `bootstrap_web`, `main_web` completo | AG, revisão CLAUDE | `feat/web-token-repos` | ⏳ depende de T5 e T6 (**RASCUNHO**) |
| T7 | Build + deploy no Cloudflare Pages + teste no iPhone | AG + Enzo | `feat/web-deploy` | ⏳ depende de T6b (**RASCUNHO**) |
| T6c | Tela do admin no app: ver, copiar e girar o link | AG, revisão CLAUDE | `feat/share-link-admin` | ⏳ opcional, depois da T7 (**RASCUNHO**) |
| T7b | Aposentar o site antigo (código, Vercel, `sync_data`) | AG + Enzo | `chore/remove-old-site` | ⏳ **só no fim**, depois de validar (**RASCUNHO**) |

Ordem: **T5 e T6 em paralelo** → T6b → T7 → uso real por algumas semanas → (T6c quando quiser) → T7b.

## Cabeçalho a colar no INÍCIO de todo prompt do AG desta fase

```
Contexto: leia docs/ARCHITECTURE.md (seções 2, 4, 5, 7 e 9) e docs/F2-TASK.md antes de começar.
Regras: o app personal (isReadOnly = false) não pode mudar de comportamento visível;
não altere fórmulas dos calculators, nomes de tabelas/colunas do Supabase, RLS ou RPCs
(o SQL da Fase 2 é feito pelo Claude e executado pelo Enzo, nunca por você);
não altere chaves de SharedPreferences; não mexa na proteção contra queda de internet
(fila de envio, CacheStore, estado local da partida, snapshot do elenco);
não adicione pacotes; preserve os textos de erro existentes.
Só lib/data/supabase/ e lib/bootstrap_personal.dart podem importar supabase_flutter.
Se encontrar algo que o documento não cobre, NÃO decida: registre em docs/DUVIDAS.md
(arquivo, linha, o que viu) e continue com o resto.
IMPORTANTE: altere o CÓDIGO, não só a documentação.
Ao terminar: rode `flutter analyze` e `flutter test`, faça commits pequenos e me diga em
5 linhas o que mudou e o que ficou pendente. Mostre a saída de `git diff main --stat`.
```

## Rotina de git (vale para toda tarefa com branch)

```
git checkout main
git pull
git checkout -b <branch>
# o AG trabalha aqui
git diff -M main --stat
flutter analyze
flutter test
# se houver revisão: Claude Code revisa; corrija; teste no celular ou com flutter run -d linux
git checkout main
git merge <branch>
git push
```

## Decisões da Fase 2 (fechadas em 03/11/2026)

- **Acesso:** link secreto, **sem login** por enquanto. Login pode vir depois como camada extra (`AuthService` já é interface; `hasAuth` da web fica `false`).
- **Um token por grupo, um link por grupo.** O link define o grupo; o site não tem seletor de grupo, só o de temporada que já existe.
- **Formato do link:** `https://<domínio>/#/g/<token>`. O token fica depois do `#`, que o navegador não envia ao servidor (não aparece em logs de hospedagem).
- **O que o site mostra:** nomes e notas (inclusive as agregadas da comunidade). **Nunca** devolve e-mail, `creator_id`, ids de usuário (`auth`), logs de admin nem códigos de convite.
- **Sem `match_screen` na web.** Partida ao vivo e notificações de eventos ficam exclusivas do app, para o futuro.
- **F1 (cosméticos):** na web `hasCosmetics = true` (só exibição). A gestão já some por `isReadOnly`.
- **F2 (botões que dão erro):** esconder, não recusar. Faz parte da T5.
- **Segurança é no banco:** a chave `anon` fica no site; `anon` não tem `SELECT` direto em nenhuma tabela. Só funções `SECURITY DEFINER` com token.
- **Hospedagem:** Cloudflare Pages, com build no GitHub Actions (o Flutter não vem instalado lá).
- **Site antigo (React/Vercel) e `sync_data`:** removidos só no fim (T7b). Até lá, o envio do pacote continua rodando sem efeito.
- **Repositório:** hoje público; o Enzo pretende fechar a parte pessoal (app e site) e deixar aberto o app offline. Decisão fica para depois do app offline. Por isso a segurança **não pode depender do código ser secreto**.
- **Login/token e notificações:** não entram na Fase 2.

### Exceção à regra de ouro 5 (vale só para T6 e T6c)

A regra 5 diz para não alterar tabelas, RLS e RPCs. A Fase 2 exige uma exceção **somente aditiva**: **1 tabela nova** (`group_share_tokens`) e **funções novas**. Nada existente é alterado. Quem executa é o Enzo no SQL Editor do Supabase, depois de um backup, com o SQL entregue pelo Claude. O token fica em tabela separada (e não em coluna de `groups`) para que a leitura normal de `groups` por qualquer membro nunca o exponha.

### Perguntas em aberto da Fase 2

1. Guardar o token no navegador (localStorage) para abrir o site sem o link completo? Começa **não** (só lê da URL). Reavaliar depois de testar no iPhone ("Adicionar à tela de início").
2. Domínio próprio ou `*.pages.dev`? Decidir na T7.
3. `session_arrivals` (presentes da pelada) entra no snapshot? Depende de alguma tela de leitura precisar disso; o AG confere na T6b e registra.

---

## T5 · Telas seguras para web e modo somente leitura — AG, revisão CLAUDE

Branch: `feat/web-readonly-screens` · Pode rodar em paralelo à T6

Objetivo: o código passa a poder rodar no navegador sem quebrar, e com `isReadOnly = true` nenhum recurso de escrita aparece. **Não** cria repositórios novos nem bootstrap (isso é a T6b).

```
[cabeçalho]
Tarefa: deixar as telas de leitura prontas para Flutter Web em modo somente leitura.
O app personal NÃO muda de comportamento (nele isReadOnly = false).

1) Compatibilidade com web.
   Rode: grep -rn "dart:io\|path_provider\|screenshot\|share_plus\|file_picker\|audioplayers" lib
   Registre em docs/DUVIDAS.md cada ocorrência (arquivo:linha) e se funciona ou não na web.
   - ranking_screen.dart e history_screen.dart (salvar/compartilhar imagem): use import
     condicional ou kIsWeb. Na web o botão de compartilhar/salvar imagem fica ESCONDIDO
     (não reimplemente nada). No celular nada muda.
   - Não deve sobrar import de dart:io, File ou path_provider alcançável a partir das telas
     de leitura sem proteção (kIsWeb ou import condicional).
   - Pacotes usados só por telas de escrita/admin não precisam ser portados, apenas não
     podem ser alcançados em modo somente leitura.

2) Flags da web. Em lib/app/app_features.dart adicione a configuração "web_readonly"
   conforme a coluna web_readonly da seção 5 do ARCHITECTURE.md:
   hasAuth=false, hasMembershipManagement=false, hasCosmetics=TRUE (só exibição),
   hasGoalSounds=false, hasAuditLog=false, hasSiteSync=false, hasCloudDraftSync=false,
   hasAdminDebug=false, hasDbExportImport=false, isReadOnly=TRUE.
   Crie teste unitário no padrão de test/app/app_features_test.dart.
   Não mude a configuração do personal.

3) F2 · esconder o que grava. Com isReadOnly = true, NENHUM botão, FAB, item de menu,
   swipe, long-press ou diálogo que grave pode aparecer. A lista de ações de escrita está
   em docs/DUVIDAS.md item 19: confirme cada uma no código, e procure outras que a lista
   não cite (grep por .update(, .insert(, .delete(, AppServices.instance.*.create/update/
   delete/set/remove/log/approve/reject/promote/demote). Use !isReadOnly (ou canAdminister,
   que já inclui !isReadOnly). Esconder em vez de mostrar e recusar. Não troque textos de erro.
   Atenção a player_detail.dart (editar nome, ícone, som de gol, atribuir prêmio, atributos
   da comunidade) e a manage_badges_screen.dart (nenhum caminho até ela na web).

4) match_screen NÃO existe na web. Ache com grep todos os lugares que abrem a MatchScreen
   (grep -rn "MatchScreen(" lib). Com isReadOnly = true: não mostre "iniciar/continuar
   partida" e a pelada abre apenas as telas de leitura (ranking, histórico, estatísticas).
   Não altere o interior de match_screen.dart.

5) Telas que leem o snapshot local players_<groupId> (SharedPreferences), como
   PlayerComparisonScreen: confirme com teste que, com o snapshot VAZIO, elas buscam o
   elenco por AppServices.instance.players (o fallback da Fase 1b). Se alguma ainda depender
   só do snapshot, corrija com o mesmo padrão e avise.

6) Crie lib/main_web.dart como entrypoint PROVISÓRIO: define as flags web_readonly e roda um
   MaterialApp com a mensagem "Site em construção". Sem bootstrap, sem repositórios novos.

7) Rode `flutter build web -t lib/main_web.dart`. Se falhar por pacote não suportado,
   NÃO decida: registre em DUVIDAS.md. Obs.: o build do placeholder não prova que as telas
   funcionam na web; a prova vem na T6b/T7. A garantia desta tarefa é o grep do item 1.

Aceite: analyze e test ok; app personal idêntico (checklist manual itens 1 a 4);
`grep -rn "dart:io" lib` só aparece em arquivos protegidos por import condicional/kIsWeb;
git diff -M main --stat sem mexer em match_screen.dart além do estritamente necessário
(idealmente nada); teste novo das flags web.
```

### Prompt de revisão (colar no Claude Code, somente leitura)

```
Revise a branch feat/web-readonly-screens em modo SOMENTE LEITURA. Não rode git checkout,
switch nem stash; para ver a versão antiga use `git show pre-refactor:<arquivo>` ou
`git show main:<arquivo>`. Use `git diff -M main...HEAD`.
Verifique e responda cada item com arquivo:linha:
1. Existe algum import de dart:io, File ou path_provider alcançável pelas telas de leitura
   (ranking, histórico, estatísticas, elenco, carta do jogador, comparação) sem proteção?
2. Com isReadOnly = true, sobrou algum botão, FAB, menu, swipe, long-press ou diálogo que
   grave algo? Compare com a lista do docs/DUVIDAS.md #19 e procure os que ela não cita.
3. Algum caminho ainda abre a MatchScreen em modo somente leitura?
4. A configuração do personal mudou? (deve estar idêntica)
5. As telas de comparação/adicionar jogadores funcionam com o snapshot players_<groupId> vazio?
6. match_screen.dart foi alterado? Se sim, o que e por quê?
7. Os textos de erro existentes foram preservados?
Liste riscos e regressões possíveis no app personal. Não corrija nada.
```

---

## T6 · Token e funções no banco — CLAUDE (SQL), Enzo executa

Sem branch. O Claude entrega `docs/sql/F2_T6_share_link.sql` (e um arquivo de testes). **O banco é de produção** (o grupo "Fut do INF" tem os dados reais do Enzo): tudo é aditivo e roda dentro de uma transação.

### Passo 0 — consultas para o Claude desenhar o SQL (o Enzo roda e cola o resultado)

Rodar no SQL Editor do Supabase (somente leitura):

```sql
-- 1) colunas das tabelas envolvidas
select table_name, column_name, data_type, is_nullable, column_default
from information_schema.columns
where table_schema = 'public'
  and table_name in ('groups','players','group_members','seasons','sessions',
                     'matches','match_lineups','match_events','session_arrivals')
order by table_name, ordinal_position;

-- 2) políticas RLS atuais
select tablename, policyname, cmd, roles, qual, with_check
from pg_policies where schemaname = 'public' order by tablename, policyname;

-- 3) funções que já existem em public
select p.proname, pg_get_function_identity_arguments(p.oid) as args, p.prosecdef as security_definer
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' order by 1;
```

### Desenho (resumo; o SQL final vem depois do passo 0)

- **Tabela nova** `group_share_tokens(group_id pk → groups, token text unique not null, created_at, rotated_at)`. RLS ligado e **nenhuma policy**: ninguém lê direto, só pelas funções.
- **Token:** 2 UUIDs v4 concatenados sem hífen (≈244 bits de aleatoriedade), gerados no banco; nunca no cliente.
- **`get_group_snapshot(p_token text) returns jsonb`** — `SECURITY DEFINER`, `set search_path = public, pg_temp`. Token inexistente ou revogado devolve o mesmo erro genérico. Devolve, só do grupo do token: `group`, `seasons`, `sessions`, `players`, `members` (apenas `player_id` e `role`), `matches`, `lineups`, `events`. Os campos usam os **mesmos nomes de coluna das tabelas**, para os modelos atuais (`fromMap`) funcionarem sem adaptação. **Fora:** e-mail, `creator_id`, ids de usuário, logs, pedidos de entrada, código de convite, estado de execução da pelada.
- **`get_group_share_token(p_group_id uuid)`**, **`rotate_group_share_token(p_group_id uuid)`**, **`revoke_group_share_token(p_group_id uuid)`** — só admin do grupo (mesma regra do app: criador do grupo OU `role = 'admin'`), usando `auth.uid()`.
- **Permissões:** `revoke all on function ... from public`; `grant execute` de `get_group_snapshot` a `anon` e `authenticated`; as funções de admin só a `authenticated`.
- **Antes de rodar:** backup (Supabase → Database → Backups, ou exportação). Rodar tudo em `begin; ... commit;`.

### Testes que o Enzo roda depois (o Claude entrega os comandos exatos)

1. Com a chave `anon`, `GET /rest/v1/players`, `/matches`, `/groups`, `/group_share_tokens` etc. devem **negar acesso ou voltar vazios**.
2. `get_group_snapshot` com token inválido → erro genérico; com token do Fut do INF → JSON só desse grupo.
3. Procurar no JSON as palavras `email`, `creator_id`, `user_id`, `invite` (não pode haver nenhuma).
4. Girar o token e conferir que o antigo para de funcionar.
5. O app personal (celular) continua funcionando normalmente.

---

## T6b · Repositórios via token e `bootstrap_web` — AG, revisão CLAUDE · **RASCUNHO**

Branch: `feat/web-token-repos` · Depende de T5 e T6 · O Claude confirma este prompt (formato exato do JSON) quando a T6 estiver pronta.

```
[cabeçalho]
Tarefa: fazer o site ler os dados do grupo por token, sem login, reaproveitando as telas.

1) lib/data/supabase/readonly/ (novo; fica dentro de lib/data/supabase/ porque usa o cliente
   Supabase). Crie SnapshotSource: chama a RPC get_group_snapshot(p_token) UMA vez, guarda o
   JSON em memória (sem SharedPreferences, sem CacheStore) e permite recarregar (pull-to-refresh).
2) Classes Token*Repository que implementam as interfaces de LEITURA de lib/domain/repositories/
   lendo do SnapshotSource e filtrando em memória: TokenGroupsRepository, TokenSeasonsRepository,
   TokenSessionsRepository, TokenMatchesRepository, TokenPlayersRepository,
   TokenMembershipRepository (apenas getMembers/getMyMembership somente leitura).
   Use os modelos existentes (fromMap/fromJson); NÃO crie modelos novos nem altere fórmulas.
   Todo método de ESCRITA lança UnsupportedError('Site somente leitura').
   SessionArrivalsRepository: devolva vazio e registre em DUVIDAS.md quais telas lêem presentes.
3) Serviços nulos: NullAuthService (isSignedIn=false, sem usuário), PermissionService com
   isAdmin sempre false, MatchOutbox sem pendências (pending=0, flush não faz nada),
   MatchHistoryStore e CustomBadgesRepository vazios, ActionLogsRepository que não faz nada.
   siteSync e diagnostics = null no AppServices.
4) lib/bootstrap_web.dart: inicializa o Supabase (URL e chave anon como no bootstrap_personal),
   lê o token de Uri.base.fragment (formato "/g/<token>"), carrega o snapshot e monta o
   AppServices com as classes acima e AppFeatures web_readonly.
5) lib/main_web.dart completo (substitui o placeholder da T5): se não há token ou o token é
   inválido/revogado, mostra uma tela simples "Link inválido ou desativado. Peça um novo link ao
   administrador." (sem detalhes técnicos). Com token válido, abre direto o painel do grupo.
   Sem login, sem HomePage de grupos, sem convite.
6) Mantenha o isolamento: só lib/data/supabase/ e os bootstraps importam supabase_flutter.
7) Testes: repositórios com um JSON de exemplo; escrita lança UnsupportedError; token inválido.
Aceite: analyze/test ok; `flutter run -d chrome -t lib/main_web.dart` abre o link
http://localhost:<porta>/#/g/<token> e mostra ranking e histórico do grupo; nenhuma tela de
escrita aparece; personal idêntico.
```

Revisão CLAUDE: `lib/data/supabase/readonly/` completo, `bootstrap_web.dart` e `main_web.dart` (o Enzo me manda esses arquivos; prompt de revisão no mesmo padrão da T5, incluindo a proibição de `git checkout`).

---

## T7 · Build, deploy no Cloudflare Pages e teste no iPhone — AG + Enzo · **RASCUNHO**

Branch: `feat/web-deploy` · Depende de T6b

**O que o Enzo faz (uma vez, no painel):**
1. Criar conta/projeto no Cloudflare Pages (modo *Direct Upload*, nome sugerido: `app-fut-site`).
2. Criar um API Token (permissão *Cloudflare Pages: Edit*) e anotar o *Account ID*.
3. No GitHub (repo → Settings → Secrets and variables → Actions): criar `CLOUDFLARE_API_TOKEN` e `CLOUDFLARE_ACCOUNT_ID`.

```
[cabeçalho]
Tarefa: publicar o site Flutter Web no Cloudflare Pages via GitHub Actions.
1) .github/workflows/deploy-web.yml: dispara em push na main (e manualmente, workflow_dispatch).
   Passos: checkout, subosito/flutter-action (canal stable, versão fixada igual à do projeto),
   flutter pub get, flutter analyze, flutter test, flutter build web --release -t lib/main_web.dart,
   publicar build/web com cloudflare/wrangler-action (pages deploy build/web --project-name=app-fut-site)
   usando os secrets CLOUDFLARE_API_TOKEN e CLOUDFLARE_ACCOUNT_ID.
2) web/index.html: <meta name="robots" content="noindex, nofollow"> e <meta name="referrer"
   content="no-referrer">. Título e ícone neutros (nome do grupo vem do app).
3) web/robots.txt com "User-agent: *" e "Disallow: /".
4) web/_headers (Cloudflare Pages) com Referrer-Policy: no-referrer e X-Content-Type-Options: nosniff.
5) Se o build web exigir ajuste de manifest/ícones, faça o mínimo e registre em DUVIDAS.md.
Aceite: o workflow roda verde; o site abre em https://app-fut-site.pages.dev/#/g/<token>.
```

**Teste manual no iPhone (Safari) — checklist do Enzo:**
1. Abrir o link: carrega ranking e estatísticas? Quanto demora a primeira vez?
2. Navegar: temporada, histórico de uma pelada, carta do jogador, comparação.
3. Nenhum botão de editar/apagar/criar aparece em lugar nenhum.
4. Girar a tela e rolar listas longas.
5. Abrir sem token (`https://.../`) → mensagem de link inválido.
6. Girar o token (SQL) e reabrir o link antigo → link inválido.
7. "Adicionar à tela de início": o atalho continua abrindo o grupo? (alimenta a pergunta em aberto 1)
8. Conferir que o app personal no celular segue normal.

---

## T6c · Tela do admin: ver, copiar e girar o link — AG, revisão CLAUDE · **RASCUNHO, opcional**

Branch: `feat/share-link-admin` · Depois da T7. Até lá, o Enzo pega o token pelo SQL Editor.

Escopo previsto: interface `ShareLinkRepository` (`getShareLink(groupId)`, `rotate(groupId)`, `revoke(groupId)`) implementada em `lib/data/supabase/` chamando as funções `get_/rotate_/revoke_group_share_token`; item "Link do site" na tela de configurações, visível só com `canAdminister` (e `hasMembershipManagement`); botões Copiar, Girar (com confirmação: "o link antigo deixará de funcionar") e Desativar. O prompt completo será escrito quando a T7 estiver validada.

---

## T7b · Aposentar o site antigo — AG + Enzo · **RASCUNHO, só no fim**

Branch: `chore/remove-old-site` · Só depois de o site novo estar validado e em uso.

**Enzo:** apagar o projeto do site React na Vercel; por último, `drop table sync_data` no Supabase (depois de conferir que nada mais a usa).

**AG (código):** remover `SiteSyncService`, `SupabaseSiteSyncService`, `SiteDataGenerator`, a flag `hasSiteSync`, `_scheduleSiteSync` e `_triggerBackgroundSync` do `match_screen`, o campo `siteSync` do `AppServices`, o uso de `my_sync_code`, e os trechos do painel de debug que dependem disso; atualizar `ARCHITECTURE.md` e `BACKLOG.md`. **Atenção:** mexe em `match_screen`, onde fica a proteção offline. Exige revisão do Claude, prompt com a proibição de `git checkout` e o **teste do modo avião (item 9 do checklist)**. Não alterar a chave `pending_matches_v1` nem as outras chaves protegidas. O prompt completo será escrito quando chegar a hora.
