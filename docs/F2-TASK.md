# F2-TASK.md — Fase 2: site somente leitura (iPhone), link secreto sem login

> **Fase atual.** O agente lê este arquivo e `docs/ARCHITECTURE.md` (seções 2, 4, 5, 7 e 9). Não precisa ler as outras fases.
> Ponto de partida: `main` com Fases 0, 1 e 1b concluídas (222 testes, 0 erros no analyze).
> Prompts marcados **RASCUNHO** serão revisados pelo Claude antes de serem usados (dependem do resultado de tarefas anteriores). Sempre que um prompt mudar, o Claude atualiza este arquivo.

## Status

| # | Tarefa | Quem | Branch | Situação |
|---|---|---|---|---|
| T5 | Telas seguras para web, flags `web_readonly`, esconder escrita | AG, revisão CLAUDE | `feat/web-readonly-screens` | 🔎 feita pelo AG em 03/11; **aguardando revisão do Claude Code**, `flutter analyze`/`test` e teste manual antes do merge |
| T6 | Tabela de token + funções SQL no Supabase | CLAUDE (SQL) + Enzo (executa) | sem branch (`docs/sql/`) | ✅ executada e testada em produção em 04/11/2026 (testes da API como visitante ok; falta só o teste de admin do passo 5, necessário antes da T6c) |
| T6b | Repositórios via token, `bootstrap_web`, `main_web` completo | AG, revisão CLAUDE | `feat/web-token-repos` | ⏳ prompt pronto; começa quando a T5 estiver na `main` |
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

### Achado de segurança fora do escopo da Fase 2 (S1) — decidir depois

A política `players_select` (`auth.uid() is not null`) permite que **qualquer usuário logado**, de qualquer grupo, leia **todas** as linhas de `players`, que inclui a coluna `email`. Como o cadastro no app é aberto e a chave `anon` é pública, isso pode expor nomes e e-mails dos jogadores de todos os grupos (a confirmar pela consulta 0.3 do `F2_T6_testes.md`; pode haver proteção por coluna). **A Fase 2 não depende disso e não mexe nisso** (desenho e plano em `docs/S1-TASK.md`; o estágio 2 foi descartado: só 2 e-mails no banco) (o site novo nunca devolve `email`), mas vale uma tarefa própria depois da T6: restringir o `SELECT` a jogadores de grupos onde o usuário é membro (ou criados por ele), com cuidado para não quebrar `claim_ghost_profile`, convites e pedidos de entrada. Registrar no `BACKLOG.md` com prioridade alta.

### Ideias para depois da validação do site

- **Dashboard exclusivo do site:** tela inicial própria da web (destaques da temporada, última pelada), sem abas de admin, reaproveitando os mesmos repositórios.
- **Login opcional** (camada extra por cima do link) e **notificações de eventos**, exclusivas do app.
- **Peso do snapshot:** hoje ~1,7 MB de JSON. Se ficar lento no iPhone, carregar só a temporada atual.

### Perguntas em aberto da Fase 2

1. Guardar o token no navegador (localStorage) para abrir o site sem o link completo? Começa **não** (só lê da URL). Reavaliar depois de testar no iPhone ("Adicionar à tela de início").
2. Domínio próprio ou `*.pages.dev`? Decidir na T7.
3. ~~`session_arrivals` no snapshot?~~ Entrou (chave `arrivals`). O AG confere na T6b se alguma tela usa e registra.
4. A tabela `custom_badges` existe no banco (política `custom_badges_select`), mas os docs dizem que as insígnias personalizadas vivem só no aparelho. Confirmar se a tabela tem dados; se tiver, decidir se entra no snapshot.

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

### Correções pós-revisão (prompt do AG, 08/11/2026)

Decisão do Enzo: o menu ⋮ das peladas fica **escondido para quem não é admin** no app personal (documentar). Itens 5 e 6 vieram da segunda revisão.

```
[cabeçalho]
Branch: feat/web-readonly-screens (continue nela). Correções pós-revisão da T5:
1) lib/widgets/session/session_list_tile.dart ~linhas 95-115: reindente o itemBuilder do
   menu. Só formatação, sem mudar lógica.
2) Registre em docs/DUVIDAS.md (item novo) que, no app personal, o menu ⋮ de editar/excluir
   pelada passou a ficar escondido para quem não é admin (antes aparecia e mostrava
   "Apenas administradores podem alterar as peladas."), alinhado à regra da seção 5 do
   ARCHITECTURE e ao item 2.4 do Plano de Ação. Cite sessions_screen.dart e session_list_tile.dart.
3) docs/DUVIDAS.md #19: as linhas de main_personal.dart citadas (186, 312, 644, 675) estão
   desatualizadas; corrija para as atuais (258, 384, 834, 870).
4) settings_screen.dart (~170-250): confirme que, com isReadOnly = true, NENHUMA entrada de
   gestão aparece (ManageMembers, ManageSeasons, ManageJoinRequests, AdminDebug, ManageBadges).
   Se algo aparecer, esconda com canAdminister e liste o que mudou.
5) history_screen.dart ~linha 314: o toque longo que abre _showDebugInfo (mostra match_id e
   session_id) não pode funcionar com isReadOnly = true. Desative-o nesse modo. No personal
   (isReadOnly = false) fica igual.
6) player_detail.dart: as gravações em SharedPreferences nas linhas ~1237, 1282, 1336, 1653 e
   2314. Para cada uma, registre em docs/DUVIDAS.md de quais botões/fluxos ela é alcançada e
   qual proteção (_canEditProfile, _canAdminister, isReadOnly) cobre o caminho. Se alguma for
   alcançável com isReadOnly = true, proteja e avise. Não mude chaves de SharedPreferences.
Aceite: analyze e test ok; git diff -M main --stat só com esses arquivos (mais o que a T5 já
tinha); personal idêntico exceto o menu das peladas.
```

Antes do merge: `grep -rn "match_history_full" lib test tool docs` (o arquivo foi removido nesta branch). Teste manual no celular: menu das peladas como admin e como não admin, aba Campo, iniciar partida, **compartilhar ranking e exportar histórico** (código movido para `share_helper`).

---

## T6 · Token e funções no banco — CLAUDE (SQL), Enzo executa

Sem branch. O Claude entrega `docs/sql/F2_T6_share_link.sql` (e um arquivo de testes). **O banco é de produção** (o grupo "Fut do INF" tem os dados reais do Enzo): tudo é aditivo e roda dentro de uma transação.

### Arquivos (em `docs/sql/`)

- `F2_T6_share_link.sql` — cria a tabela `group_share_tokens` e as funções. Roda numa transação. Aditivo.
- `F2_T6_testes.md` — roteiro de testes na ordem: backup, rodar, testes estruturais, criar o link do Fut do INF, testes pela API como visitante (`anon`), testes de admin, conferência do app.

**Validação:** a sintaxe SQL e PL/pgSQL foi conferida com o parser do Postgres, mas o script **não foi executado** num banco. Os testes do roteiro são obrigatórios.

### Desenho final (já refletido no SQL)

- **Tabela** `group_share_tokens(group_id text pk → groups, token text unique, created_at, rotated_at)`. RLS ligado, sem policy, sem privilégio para `anon`/`authenticated`. Ids de grupo são `text` neste banco.
- **Token:** 2 UUIDs v4 sem hífen (64 hex, ≈244 bits), gerado no banco por `_new_share_token()` (interna, sem permissão para a API).
- **`get_group_snapshot(p_token text) returns jsonb`** — `SECURITY DEFINER`, `search_path` fixo. Erro único `invalid_link` para token inexistente, curto ou revogado. Chaves do JSON: `group`, `seasons`, `sessions`, `members`, `players`, `matches`, `lineups`, `events`, `arrivals` (listas, exceto `group`), todas com os **mesmos nomes de coluna das tabelas**.
  - `groups` e `players` usam **lista permitida de colunas**. Ficam de fora: `players.email`, `players.creator_id`, `players.goal_sound_url`, `groups.creator_id`, `groups.invite_code`, `groups.sync_code`.
  - `players` inclui os do grupo **e** quem aparece no histórico do grupo (lineups/eventos/assistências), para não surgir "Desconhecido" para quem saiu do elenco.
  - `sessions` vem completa (inclui campos de estado ao vivo; são inofensivos e evitam falha de parse nos modelos). `arrivals` entra no snapshot (responde a pergunta em aberto 3); o AG confirma na T6b se alguma tela usa.
  - Não entram: logs de admin, pedidos de entrada, `rating_history`, `sync_data`.
- **`get_group_share_token`, `rotate_group_share_token`, `revoke_group_share_token`** (`p_group_id text`): só `authenticated` e só quem passa em `public.is_group_admin(p_group_id)` (a mesma regra do RLS do app).
- **Permissões:** `anon` só executa `get_group_snapshot`.
- **Aviso à T6b:** os modelos (`PlayerModel` etc.) precisam aceitar a ausência de `email` e `creator_id`; o AG confere e, se algum modelo exigir, registra em DUVIDAS.md em vez de decidir sozinho.

---

## T6b · Repositórios via token e `bootstrap_web` — AG, revisão CLAUDE

Branch: `feat/web-token-repos` · Depende da T5 (na `main`) · T6 já está no banco.

**Formato real do snapshot** (testado em produção): objeto com `group` (objeto) e as listas `seasons`, `sessions`, `members`, `players`, `matches`, `lineups`, `events`, `arrivals`, todos com os nomes de coluna das tabelas. No Fut do INF: 543 partidas, 4709 escalações, 1676 eventos, 72 jogadores, ~1,7 MB de JSON. Token inválido/revogado → erro Postgrest com `code = P0001` e `message = invalid_link`. `players` **não** traz `email`, `creator_id` nem `goal_sound_url`; `groups` não traz `creator_id`, `invite_code` nem `sync_code`.

**Regra de dados:** o repositório é público. Os testes usam **JSON sintético** (nomes inventados). Nunca commitar um snapshot real nem colar dados reais em fixtures.

```
[cabeçalho]
Tarefa: fazer o site ler os dados do grupo por token, sem login, reaproveitando as telas.

1) lib/data/supabase/readonly/ (novo; fica dentro de lib/data/supabase/ porque usa o cliente
   Supabase). Crie SnapshotSource: chama client.rpc('get_group_snapshot', params: {'p_token': token})
   UMA vez, guarda o JSON em memória (sem SharedPreferences, sem CacheStore) e permite recarregar
   (pull-to-refresh). Erro P0001/invalid_link vira um tipo próprio (ex.: InvalidLinkException);
   qualquer outro erro vira "sem conexão, tente de novo" com botão de tentar novamente.
   O payload tem ~1,7 MB: mostre indicador de carregamento e decodifique sem travar a UI.
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
7) Testes: repositórios com JSON SINTÉTICO (dados inventados); escrita lança UnsupportedError;
   token inválido; modelos aceitam ausência de email/creator_id (se algum modelo exigir, registre
   em DUVIDAS.md em vez de alterar).
Aceite: analyze/test ok; `flutter run -d chrome -t lib/main_web.dart` abre o link
http://localhost:<porta>/#/g/<token> e mostra ranking e histórico do grupo; nenhuma tela de
escrita aparece; personal idêntico.
```

Revisão CLAUDE: `lib/data/supabase/readonly/` completo, `bootstrap_web.dart` e `main_web.dart` (o Enzo me manda esses arquivos; prompt de revisão no mesmo padrão da T5, incluindo a proibição de `git checkout`).

---

### Correções pós-revisão da T6b (prompt do AG, 08/11/2026)

Revisão do Claude Code achou: erro de rede virando "link inválido", ausência de `InvalidLinkException` (previsto no prompt original), sem sanitização no app (o RPC já filtra; é segunda barreira), prefetch gravando no SharedPreferences (localStorage na web), `utils/` importando `data/prefs/`, conversão repetida do snapshot. `readonly/` está dentro de `data/supabase/`: não é exceção nova à regra 5.

```
[cabeçalho]
Branch: feat/web-token-repos (continue nela). Não mexa em fórmulas de calculators,
tabelas/colunas/RLS/RPCs do Supabase, chaves de SharedPreferences, bootstrap_personal nem
main_personal. Não adicione pacotes.
1) snapshot_source.dart: crie InvalidLinkException. Em load(), capture PostgrestException com
   code 'P0001' ou mensagem contendo 'invalid_link' e lance InvalidLinkException. Qualquer outro
   erro (rede, timeout, formato) passa como está, sem virar link inválido.
2) bootstrap_web.dart e main_web.dart: BootstrapWebResult ganha estado "erro de conexão"
   separado de "link inválido". Só InvalidLinkException (e token ausente) vira InvalidLinkScreen.
   Outros erros mostram tela com "Não foi possível carregar. Verifique a internet" e botão
   "Tentar de novo" que repete o bootstrap. No debugPrint, não imprima $e: mensagem fixa.
3) Sanitização (segunda barreira; o RPC já filtra): em UM helper dentro do SnapshotSource, remova
   email, creator_id, invite_code, sync_code e goal_sound_url antes de qualquer fromMap.
4) SnapshotSource guarda em memória as listas já convertidas (PlayerModel, MatchModel) para não
   reconverter a cada chamada.
5) GroupBootstrap.prefetch: com AppServices.instance.features.isReadOnly, não grave no
   SharedPreferences; só devolva os dados em memória.
6) extractTokenFromUrl: aceite somente o fragmento '#/g/<token>'.
7) stats_calculator.dart (getAllGroupMatches): (a) confirme que SupabaseMatchesRepository() e
   SupabasePlayersRepository() sem argumentos usam o mesmo client do bootstrap_personal e
   registre em docs/DUVIDAS.md; (b) remova o import de data/prefs/ em utils/ (a camada utils não
   pode depender de data/prefs); use o que AppServices já expõe; (c) teste para o ramo
   AppServices.isInitialized == true.
8) Confirme (grep) que nada na web abre match_screen com isReadOnly = true; registre em DUVIDAS.
9) Testes novos, dados sintéticos: P0001 vira InvalidLinkException; rede/timeout NÃO vira link
   inválido (tela de erro com tentar de novo); JSON com campos faltando não quebra; email,
   creator_id, invite_code, sync_code e goal_sound_url nunca chegam aos modelos; prefetch em
   readonly não grava no SharedPreferences.
10) docs/ARCHITECTURE.md: registre que lib/data/supabase/readonly/ faz parte de data/supabase/
    (por isso pode importar supabase_flutter) e que bootstrap_web usa SupabaseConfig.client.
Aceite: analyze e test ok; git diff -M main --stat só com arquivos esperados; personal intacto.
```

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
