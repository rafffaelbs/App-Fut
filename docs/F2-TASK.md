# F2-TASK.md — Fase 2: site somente leitura (iPhone), link secreto sem login

> **FASE 2 ENCERRADA em 15/11/2026** (site no ar em `https://app-fut-site.pages.dev/fut`). O que sobrou está em "Encerramento da Fase 2", no fim deste arquivo. A tarefa nova de estética do site (E1) segue em outra conversa. As tarefas T8 a T15 do `F3-TASK.md` são da Fase 3; por isso a estética do site passou a se chamar **E1**.

> **Fase atual.** O agente lê este arquivo e `docs/ARCHITECTURE.md` (seções 2, 4, 5, 7 e 9). Não precisa ler as outras fases.
> Ponto de partida: `main` com Fases 0, 1 e 1b concluídas (222 testes, 0 erros no analyze).
> Prompts marcados **RASCUNHO** serão revisados pelo Claude antes de serem usados (dependem do resultado de tarefas anteriores). Sempre que um prompt mudar, o Claude atualiza este arquivo.

## Status

| # | Tarefa | Quem | Branch | Situação |
|---|---|---|---|---|
| T5 | Telas seguras para web, flags `web_readonly`, esconder escrita | AG, revisão CLAUDE | `feat/web-readonly-screens` | ✅ na `main` em 08/11/2026 (revisada, 233 testes, testada no celular) |
| T6 | Tabela de token + funções SQL no Supabase | CLAUDE (SQL) + Enzo (executa) | sem branch (`docs/sql/`) | ✅ executada e testada em produção em 04/11/2026 (testes da API como visitante ok; falta só o teste de admin do passo 5, necessário antes da T6c) |
| T6b | Repositórios via token, `bootstrap_web`, `main_web` completo | AG, revisão CLAUDE | `feat/web-token-repos` | ✅ na `main` em 14/11/2026 (URL mantém o token no F5; teste do erro de conexão a repetir no site publicado) |
| T7 | Build + deploy no Cloudflare Pages + teste no iPhone | AG + Enzo | `feat/web-deploy` | ✅ no ar em 14/11/2026: `https://app-fut-site.pages.dev/fut` (302 para o link com token ok; 281 testes). **Falta:** teste no iPhone por um amigo (atalho da tela de início) |
| T6c | Tela do admin **no app** (não no site): ver, copiar, girar e desativar o link | AG, revisão CLAUDE | `feat/share-link-admin` | ⏸️ **adiada (backlog)** por decisão de 14/11. Enquanto isso, o token é girado pelo SQL Editor. Ao retomar: rodar antes o passo 5 de `sql/F2_T6_testes.md` |
| E1 | Estética e conteúdo do site e da carta: aba Peladas na carta (E1a), dashboard "Início" (E1b), melhorias no dashboard e estatísticas (E1c) | CLAUDE (desenho) + AG, revisão CLAUDE | por etapa | ✅ E1a, E1b e E1c concluídas em 15/11/2026 (308 testes passando) |
| T7b | Aposentar o site antigo (código, Vercel, `sync_data`) | AG + Enzo | `chore/remove-old-site` | ⏳ **por último**, depois da E1 (**RASCUNHO**) |

Ordem: T5, T6, T6b e T7 ✅ → **E1** (dashboard/legibilidade do site) → **T7b** (remover o site antigo). A **T6c** (tela de admin no app) está adiada no backlog. A T7b fica por último porque mexe no `match_screen` (proteção offline) e para não gerar conflito.
O site continua **somente leitura**; nenhuma função de admin é chamada por ele.

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

- ~~**Dashboard exclusivo do site**~~ → virou a **E1**.
- **Login opcional** (camada extra por cima do link) e **notificações de eventos**, exclusivas do app.
- **Peso do snapshot:** hoje ~1,7 MB de JSON. Se ficar lento no iPhone, carregar só a temporada atual.

### Perguntas em aberto da Fase 2

1. Guardar o token no navegador (localStorage) para abrir o site sem o link completo? Começa **não** (só lê da URL). Com o vazamento sendo aceitável, passa a ser aceitável como comodidade; mas não resolve o atalho da tela de início do iPhone (armazenamento separado do Safari). Reavaliar depois de testar no iPhone.
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

### Correção 2 da T6b: a URL perde o token (achada no teste local, 08/11/2026)

Sintoma (build release servido em localhost:5000): abre em `#/g/<token>`, o painel carrega, mas a barra passa a mostrar só `localhost:5000`; F5 então cai em "Link inválido". Isso quebra recarregar a página e "Adicionar à tela de início" no iPhone (o atalho grava a URL que estiver na barra). Provável causa: o Flutter web reescreve o fragmento para `#/` ao montar o MaterialApp/Navigator.

```
[cabeçalho]
Branch: feat/web-token-repos (continue nela). Não mexa no personal nem no Supabase.
Problema: no web, depois que o painel abre, a URL deixa de ter '#/g/<token>' e F5 mostra
"Link inválido". A URL do navegador DEVE continuar '#/g/<token>' durante todo o uso:
ao abrir, ao navegar entre telas, ao voltar e após F5.
1) Investigue por que o fragmento é perdido (rota inicial '/', reporte de rota ao engine do
   Flutter web, pushReplacement etc.) e registre a causa em docs/DUVIDAS.md.
2) Corrija só no caminho web (main_web.dart / bootstrap_web.dart): por exemplo, definir a
   rota inicial como '/g/<token>' com onGenerateRoute que leva ao painel, e garantir que
   navegar entre telas não troque a URL por outra sem o token. Se algum Navigator.push
   alterar a URL, resolva no web sem mudar as telas compartilhadas com o personal.
3) O token continua só em memória e na URL: nada em localStorage/sessionStorage/cookie.
4) Teste (widget ou unit) para o que for testável: a rota inicial contém o token, e
   extractTokenFromUrl lê o token da rota. Documente o teste manual abaixo.
Aceite: analyze e test ok; personal intacto. Teste manual (build release):
`flutter build web -t lib/main_web.dart --release`, `cd build/web`, `python3 -m http.server 5000`,
abrir http://localhost:5000/#/g/<token>, abrir ranking, voltar, F5 várias vezes: a URL
mantém o token e o painel recarrega.
```

## T7 · Build, deploy no Cloudflare Pages e teste no iPhone — AG + Enzo · **RASCUNHO**

Branch: `feat/web-deploy` · Depende de T6b (merge na `main`)

**Decisão (08/11/2026):** vazamento do link não é grave para o Enzo (nomes e notas já são públicos para o grupo; se vazar, gira-se o token). Por isso vale um **link curto amigável** por redirecionamento: `https://app-fut-site.pages.dev/fut` → `/#/g/<token>`. O token fica num secret do GitHub (`FUT_TOKEN`) e o workflow gera o `web/_redirects` na hora; assim não entra no repositório e girar o token = trocar o secret + rodar o deploy. **A confirmar na T7:** se o Cloudflare Pages aceita `#` no destino do `_redirects`; se não aceitar, usa-se o link completo. O link curto **não** dispensa a Correção 2 da T6b (URL manter `#/g/<token>`), porque o atalho da tela de início do iPhone grava a URL da barra.

**O que o Enzo faz (uma vez, no painel):**
1. Criar conta/projeto no Cloudflare Pages (modo *Direct Upload*, nome sugerido: `app-fut-site`).
2. Criar um API Token (permissão *Cloudflare Pages: Edit*) e anotar o *Account ID*.
3. No GitHub (repo → Settings → Secrets and variables → Actions): criar `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID` e `FUT_TOKEN` (o token atual do Fut do INF; ao final, gire o token no banco e atualize este secret).

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
6) Tela de carregamento: em web/index.html, um fundo escuro (#121620) com um texto/spinner simples
   visível até o Flutter iniciar (hoje a página fica em branco por instantes).
7) Link curto: no workflow, antes do deploy, gere build/web/_redirects com a linha
   "/fut /#/g/${{ secrets.FUT_TOKEN }} 302" (nunca imprimir o secret nos logs).
Aceite: o workflow roda verde; o site abre em https://app-fut-site.pages.dev/#/g/<token> e
em https://app-fut-site.pages.dev/fut (se o Cloudflare aceitar o '#'; senão, registre).
```

### Correções pós-revisão da T7 (prompt do AG, 14/11/2026)

Revisão do Claude Code: workflow seguro quanto a gatilhos e vazamento do token; ajustes: permissões, actions por SHA, travar na `main`, `paths-ignore`, service worker (`--pwa-strategy=none`), `start_url` do manifest (o atalho do iPhone grava a URL; `/fut` redireciona ao link com token). **Fora de escopo por decisão:** `--no-web-resources-cdn` (decidir depois de ver o Network) e cabeçalhos de cache (o Pages já revalida).

```
[cabeçalho]
Branch: feat/web-deploy (continue nela). Mexa SOMENTE em .github/workflows/deploy-web.yml,
web/ e docs/DUVIDAS.md. Não adicione pacotes. Nunca imprima nem escreva o FUT_TOKEN.
1) deploy-web.yml:
   - build: flutter build web --release -t lib/main_web.dart --pwa-strategy=none
   - permissions: só contents: read (remova deployments: write)
   - fixe actions/checkout, subosito/flutter-action e cloudflare/wrangler-action por SHA de
     commit, com comentário "# v4" etc. Se não conseguir obter os SHAs, mantenha as tags e
     registre em DUVIDAS.md que ficou pendente.
   - no job: if: github.ref == 'refs/heads/main'
   - gatilho push: paths-ignore: ['docs/**', '**.md']
   - concurrency: mantenha o grupo, cancel-in-progress: false
   - flutter-version: fixe na versão que o Enzo usa (ele informa ao rodar flutter --version);
     enquanto não souber, deixe "# TODO versão" e avise.
   - remova o passo redundante que copia robots.txt/_headers (o Flutter já copia web/ para build/web).
2) web/manifest.json: "start_url": "/fut" (sem token: /fut redireciona para /#/g/<token>).
3) web/_headers: mantenha as linhas atuais e acrescente "X-Robots-Tag: noindex, nofollow" em /*.
4) docs/DUVIDAS.md: registre o que mudou e por quê; corrija o item 41 (o \n aparece quebrado).
Ao terminar: flutter analyze e flutter test; git diff main --stat; resumo em 5 linhas.
```

**Depois do primeiro deploy (Enzo):**
- `curl -sI https://app-fut-site.pages.dev/_redirects` não pode devolver o token.
- `curl -sI https://app-fut-site.pages.dev/fut` deve dar 302 com `Location: /#/g/...` (confirmar que o `#` chegou).
- DevTools → Network: ver se há chamadas a `gstatic.com`/`googleapis.com` (decidir `--no-web-resources-cdn` só se incomodar).
- Para trocar o `FUT_TOKEN`: atualizar o secret e rodar o workflow manualmente (workflow_dispatch).

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

## T6c · Tela do admin NO APP: ver, copiar, girar e desativar o link — AG, revisão CLAUDE · **ADIADA (backlog)**

> Decisão de 14/11/2026: não é prioridade (o link já funciona; o token é girado pelo SQL Editor). A tela é do **app do celular** (configurações, só para admin), nunca do site. O prompt abaixo fica guardado e pronto para quando for retomada.

Branch: `feat/share-link-admin` · Parte da `main` atual · **Pré-requisito:** teste de admin (passo 5 de `docs/sql/F2_T6_testes.md`: `get_/rotate_/revoke_group_share_token` com usuário admin, com JWT simulado e rollback). Se esse teste não passou, não comece.

**Funções do banco (já existem, assinaturas reais):** `get_group_share_token(p_group_id text) returns text` (null = link desativado/inexistente), `rotate_group_share_token(p_group_id text) returns text` (cria ou troca e devolve o token), `revoke_group_share_token(p_group_id text) returns void`. Só `authenticated` e só admin do grupo; não-admin recebe erro "Acesso negado".

**Aviso de desenho (importante):** o link curto `/fut` é gerado no deploy a partir do secret `FUT_TOKEN`. Se o admin girar o token no app, o link completo novo funciona na hora, mas `/fut` e o atalho da tela de início (`start_url: "/fut"`) ficam apontando para o token antigo **até** o Enzo atualizar o secret `FUT_TOKEN` no GitHub e rodar o workflow (workflow_dispatch). A tela deve avisar isso em texto simples ao girar. (Melhoria futura possível: `/fut` resolver o token atual em tempo de execução.)

```
[cabeçalho]
Tarefa: tela de admin no app para ver, copiar, girar e desativar o link do site.
Branch: feat/share-link-admin. Não mexa em match_screen, bootstrap_web, lib/data/supabase/readonly/,
chaves de SharedPreferences, nem em tabelas/RLS/RPCs do Supabase.
1) lib/domain/repositories/share_link_repository.dart: interface ShareLinkRepository com
   Future<String?> getToken(String groupId), Future<String> rotate(String groupId) e
   Future<void> revoke(String groupId). Registre em AppServices (campo shareLinks) e nos
   test helpers.
2) lib/data/supabase/supabase_share_link_repository.dart: implementa chamando
   client.rpc('get_group_share_token' | 'rotate_group_share_token' | 'revoke_group_share_token',
   params: {'p_group_id': groupId}). Erro de acesso negado vira uma exceção própria
   (ShareLinkAccessDenied); outros erros passam como estão. Só lib/data/supabase/ importa supabase_flutter.
   Ligue em bootstrap_personal (apenas a linha do novo repositório).
3) Constante com a base do site: lib/config/web_site_config.dart com
   `const kWebSiteBaseUrl = 'https://app-fut-site.pages.dev';`. Link completo =
   '$kWebSiteBaseUrl/#/g/<token>'. (O app web NÃO usa esta tela.)
4) Tela lib/screens/share_link_screen.dart e item "Link do site" em settings_screen.dart,
   visível SOMENTE com canAdminister e !isReadOnly. Estados: carregando; sem link
   ("Link desativado" + botão "Gerar link"); com link (mostra o link, botão Copiar com SnackBar
   "Link copiado", botão "Girar link" com confirmação "O link atual deixará de funcionar para
   todos. Quem tem o link antigo precisará do novo." e, depois de girar, o aviso sobre atualizar
   o secret FUT_TOKEN e rodar o deploy para o link curto /fut; botão "Desativar link" com
   confirmação); erro de rede com "Tentar de novo"; acesso negado com mensagem simples.
   O token completo nunca vai para debugPrint/log.
5) Testes com fakes (sem Supabase real, sem token real): repositório fake; telas nos estados
   acima; item de configurações some para não admin e com isReadOnly; copiar usa o link completo.
6) docs/DUVIDAS.md: registre o que mudou e o aviso sobre o /fut.
Aceite: analyze e test ok; git diff main --stat só com os arquivos da tarefa; personal igual
exceto o novo item de configurações para admins.
```

Revisão CLAUDE: o item some para não admin; erros tratados; token fora de logs; isolamento do Supabase; sem alteração no fluxo da partida.

**Teste manual (Enzo, no celular, como admin e como não admin):** ver link; copiar e abrir no navegador; girar e conferir que o link antigo dá "Link inválido" e o novo abre; desativar e reativar; conta não admin não vê o item. Depois de girar de verdade, atualizar `FUT_TOKEN` no GitHub e rodar o workflow.

---

## E1 · Dashboard do site e carta do jogador mais completa — CLAUDE (desenho) + AG, revisão CLAUDE

Branch por etapa · Próxima tarefa. Respostas do Enzo (15/11/2026): (1) a carta do jogador deveria mostrar o histórico das peladas em que ele jogou; (2) dashboard com resumo das peladas, **craque do mês atual e do mês passado** e outros destaques; (3) sem pedidos específicos dos amigos por enquanto: aceita sugestões, que o Claude Code levanta lendo o código e o Claude valida.

**Princípio:** sem escrita, sem tabelas novas, sem alterar fórmulas existentes (funções novas vão em arquivos novos). Telas exclusivas do site ficam em `lib/screens/web/`, ligadas só pelo `main_web`. A aba da E1a é aditiva e de leitura, então aparece no app e no site (se o Enzo preferir só no site, esconder com `isReadOnly`).

| Etapa | O que | Quem | Situação |
|---|---|---|---|
| E1.0 | Levantamento das telas do site, definição de "craque" no app e ideias de destaques | Claude Code (somente leitura) | ✅ feito em 15/11 (decisões abaixo) |
| E1a | Aba "Peladas" na carta do jogador | AG, revisão CLAUDE | ✅ concluída em 15/11 |
| E1b | Dashboard "Início" do site | AG, revisão CLAUDE | ✅ concluída em 15/11 |
| E1c | Melhorias no Dashboard e reformulação da tela de Estatísticas | AG | ✅ concluída em 15/11 (308 testes passando) |

### E1.0 · Levantamento e ideias (colar no Claude Code, somente leitura)

```
SOMENTE LEITURA: não edite arquivos; não rode git checkout, switch nem stash; para a versão
antiga use `git show pre-refactor:<arquivo>`.
Contexto: o site (main_web, flag isReadOnly) lê um snapshot do grupo (grupo, temporadas, sessões,
membros, jogadores, partidas, escalações, eventos, presenças) e reaproveita telas do app.
Queremos um dashboard (tela inicial do site) com destaques. Responda:
1) Telas que o site mostra hoje: arquivo, o que mostra, se é compartilhada com o app, e como o
   main_web chega a cada uma.
2) Como o app define "craque" (da pelada, do mês, da temporada)? Onde é calculado (arquivo:linha),
   com qual critério e desempate? Há funções reutilizáveis para filtrar por mês/período e para
   ranking? O que significa "G+A" e como goleiros são tratados.
3) Proponha 6 a 8 destaques para o dashboard usando SÓ dados do snapshot. Para cada um: dado
   necessário, se já existe função pronta ou precisa de função nova (em arquivo novo, sem alterar
   fórmulas existentes) e esforço (P/M/G). Inclua obrigatoriamente: craque do mês atual e do mês
   passado, resumo da última pelada; o resto é sugestão sua (ex.: artilheiro e garçom do mês,
   sequência de vitórias, presença, melhor dupla).
4) Desempenho no iPhone com ~540 partidas e ~4,7 mil escalações: o que calcular uma vez e guardar
   em memória.
Entregue um relatório curto, com tabela nos itens 1 e 3. Não escreva código.
```

### E1a · Aba "Peladas" na carta do jogador (AG)

Branch: `feat/player-recent-sessions` (a partir da `main`).

```
[cabeçalho]
Tarefa: na carta do jogador (player_detail.dart), no bloco do gráfico de evolução (que já tem as
abas de notas e de participações em gols), adicionar mais uma aba "Peladas": lista das 3 últimas
peladas (sessions) em que o jogador participou, cada uma com data, nome da pelada e resumo:
gols, assistências, G+A, vitórias, empates e derrotas naquela pelada. Botão "Ver mais" que abre a
lista completa (bottom sheet ou tela simples, rolável). A lista segue o MESMO filtro de período
que a carta já usa para os gráficos.
Regras: sem escrita; sem novas chamadas de rede (use os dados que a carta já carrega); não altere
fórmulas existentes nem chaves de SharedPreferences; a aba aparece no app e no site (somente
leitura), sem botões de edição. Reuse a lógica atual de V/E/D e de gols/assistências; se precisar
de uma função nova (agrupar por pelada), crie em arquivo novo (ex.: lib/utils/player_session_summary.dart),
pura e testável, sem tocar nos calculators. Goleiros: siga como a carta já trata goleiros e registre
em docs/DUVIDAS.md. Cuidado: player_detail.dart é grande e tem proteções de escrita/offline;
mude o mínimo e não mexa nelas.
Testes: unit da função nova (ordem por data, filtro de período, jogador sem peladas, partidas em
que ele não jogou não contam) e teste de consistência: soma de gols/assistências/V/E/D da lista
completa = totais que a carta mostra para o mesmo filtro. Widget test da aba (3 itens + "Ver mais"
e estado vazio "Sem peladas no período").
Aceite: analyze e test ok; git diff -M main --stat só com player_detail.dart, arquivos novos e testes.
```

Revisão CLAUDE (Claude Code, somente leitura): consistência dos totais, filtro de período, proteções de escrita de `player_detail.dart` intactas, app e site sem regressão.

### E1.0 · Resultado (15/11/2026) e decisões do Enzo

Relatório do Claude Code (resumo): o site só mostra telas do app; não existe "craque" calculado em lugar nenhum (o "Craque do Mês" é um selo manual: `monthly_highlight`, `monthly_star_count`, `craque_mes_count`); o ranking da pelada ordena por G+A, depois gols, depois nota, sem mínimo; G+A = gols + assistências (gol contra não conta; assistência só em evento de gol); goleiros são tratados de 3 jeitos nas telas; não há função pública para filtrar por mês/período; riscos: duas fórmulas de nota (base 6,0 e 7,0), fuso horário (`MatchModel.fromMap` sem `.toLocal()`), partida sem data vira "agora", `arrivals` vem vazio no snapshot, a tela do dashboard recria a aba a cada troca e o cálculo no Safari trava a thread principal.

Decisões do Enzo:
1. **"Craque do mês" = selo manual (oficial). "Destaque do mês" = líder calculado**, mostrado do mês atual (parcial) e do passado, com o selo oficial ao lado quando existir.
2. **Mínimo de 5 partidas no mês** para entrar no destaque calculado.
3. **Goleiros fora do destaque agora**; "Goleiro do mês" numa segunda versão.
4. **Escopo da v1:** destaque do mês atual e do passado, resumo da última pelada, artilheiro e garçom do mês. Fica para depois: sequência de vitórias, melhor dupla, mais assíduo, goleiro do mês.
5. Escolhas técnicas da Claude: mês pela **data da pelada** (não pelo horário de cada partida); partidas sem data ignoradas; desempate **G+A, gols, vitórias, nome** (sem nota, para não depender das fórmulas divergentes); o resumo da última pelada **não recalcula o craque da pelada**: o toque abre o Ranking da pelada, que já existe; dashboard como **nova primeira aba "Início" só no site**, resultados calculados uma vez e guardados fora do `State`.

### E1b · Dashboard "Início" do site (AG)

Branch: `feat/web-dashboard` (a partir da `main`). Independe da E1a (arquivos diferentes).

```
[cabeçalho]
Tarefa: criar a aba "Início" (dashboard) do site, somente leitura, e funções puras de destaques.
Regras gerais: sem escrita; sem nova chamada de rede (use os repositórios que já leem o snapshot);
não altere fórmulas existentes, telas do app personal nem chaves de SharedPreferences; nada de
SharedPreferences nesta aba. A aba aparece SOMENTE quando AppServices.instance.features.isReadOnly
for true (site); no app personal o group_dashboard_screen fica idêntico.
1) lib/utils/dashboard_highlights.dart (arquivo novo, funções puras e testáveis, sem tocar nos
   calculators nem nas telas). Copie a lógica de soma por jogador de season_stats_screen.dart
   (~297-438, privada) para cá em vez de alterar a tela. Convenções: G+A = gols + assistências;
   gol contra não conta; assistência só em evento de gol. Jogadores de linha apenas (excluir
   goleiros pelo mesmo critério que season_stats_screen usa para tirá-los dos pódios).
   - Mês = chave 'aaaa-MM' da DATA DA PELADA (sessão), em horário local. Ignore partidas sem
     pelada/data (nunca use DateTime.now() como data).
   - monthlyHighlight(mês): top 3 por G+A, depois gols, depois vitórias, depois nome. Só entra
     quem tem 5 ou mais partidas no mês. Devolve por jogador: gols, assistências, G+A, partidas,
     vitórias.
   - topScorerOfMonth e topAssisterOfMonth (mesma soma e mesmo mínimo de 5 partidas; ordena por
     gols / por assistências; desempate vitórias, nome).
   - lastSessionSummary: pelada mais recente já finalizada: id, nome, data, nº de partidas, total
     de gols, maior goleada (placar e times), artilheiro(s) da pelada.
2) Resultados calculados UMA vez após o snapshot carregar (mês atual e mês anterior + última
   pelada) e guardados fora do State (objeto único em memória, no estilo do GroupBootstrap), sem
   recalcular a cada troca de aba. Não use compute() no web. Renderize o primeiro quadro antes do
   cálculo (esqueleto/spinner). A nova aba precisa se manter viva (não recriar ao trocar de aba).
3) group_dashboard_screen.dart: com isReadOnly, acrescentar a aba "Início" como PRIMEIRA aba
   (o site abre nela). Sem isReadOnly nada muda.
4) Tela lib/screens/web/home_dashboard_screen.dart, cartões em coluna (mobile primeiro; em tela
   larga, conteúdo centralizado com largura máxima ~720):
   - "Destaque do mês · <mês atual> (parcial)": top 3 com avatar, nome, gols, assistências, jogos.
   - "Destaque do mês · <mês passado>": idem.
   - "Craque do mês (selo oficial)": jogadores com monthly_highlight verdadeiro, se houver; senão
     não mostra o cartão. Registre em docs/DUVIDAS.md o que esse campo guarda de fato (só o
     portador atual, ou há informação de mês?) e que o snapshot o traz.
   - "Última pelada": data, nome, nº de partidas, gols, maior goleada, artilheiro. Tocar abre o
     TournamentDashboardScreen dessa pelada, igual a sessions_screen.dart:154.
   - "Artilheiro do mês" e "Garçom do mês" (mês atual; mostre também o do mês passado em linha menor).
   - Estados vazios claros: "Poucos jogos neste mês" (menos de 5 partidas), "Sem peladas ainda".
   Tocar em um jogador abre o player_detail existente. Use o tema e os avatares já usados no ranking.
5) Testes com dados sintéticos: unit das funções (mês pela data da pelada: pelada de 31/10 à noite
   fica em outubro; mínimo de 5 partidas; desempate G+A→gols→vitórias→nome; gol contra ignorado;
   assistência só em gol; goleiro excluído; partida sem data ignorada; mês sem dados; última pelada
   com empate de artilheiros). Widget test da aba "Início" com isReadOnly=true (cartões e estados
   vazios) e teste de que a aba NÃO existe com isReadOnly=false.
6) docs/DUVIDAS.md: registre as definições (Destaque calculado ≠ selo manual; mês pela data da pelada;
   desempate; mínimo 5) e o que descobriu sobre monthly_highlight.
Aceite: analyze e test ok; git diff -M main --stat só com os arquivos novos, group_dashboard_screen.dart,
testes e docs; app personal idêntico.
```

Revisão CLAUDE (Claude Code, somente leitura): mês pela data da pelada e fuso; cálculo uma vez e fora do `State`; aba só com `isReadOnly`; goleiros fora; sem escrita nem SharedPreferences; funções novas sem alterar as existentes; desempenho (sem `compute()` no web).

---

### E1c · Melhorias no Dashboard e Reformulação das Estatísticas (AG)

✅ **Concluída em 15/11/2026** (308 testes passando, 0 erros no `dart analyze`).

**O que foi feito:**
1. **Dashboard (`lib/screens/web/home_dashboard_screen.dart`):**
   - Saudação personalizada no topo: `"Bem-vindo ao $groupTitle, $_myPlayerName!"` no app mobile quando o perfil do usuário logado é identificado via `AppServices.instance.members.getMyMembership`. No site (web) ou para visitante/anônimo, exibe `"Bem-vindo ao $groupTitle!"`.
   - Hero card com gradiente escuro refinado e chips de resumo rápido para a data da última pelada e jogador #1 do mês.
   - Ícones dos jogadores atualizados para usar bordas de tier baseadas no Overall (`showTierBorder: true`).
   - Badges de tier integrados nos cartões de Artilheiros e Garçons do mês.
2. **Tela de Estatísticas (`lib/screens/season_stats_screen.dart`):**
   - **Remoção do cabeçalho duplicado:** Retirada a `AppBar` interna redundante que gerava 2 setas de voltar sobrepostas com o `GroupDashboardScreen`. Substituída por título discreto no corpo com botão de recarregar e `RefreshIndicator` nativo.
   - **Rankings no topo:** A classificação geral agora é a primeira seção após os seletores de período da temporada.
   - **Padrão do ranking de pelada:**
     - Pódio Top 3 com pedestais proporcionais (2º, 1º e 3º), medalhas de ouro/prata/bronze, avatares com borda de tier (`showTierBorder: true`), estrelas cosméticas (`StarsBadge`), `GoalsAssistsText`, resumo de cartões (`🟨/🟥`), Hat-Tricks (`🎩 HT`), Nota Média (`RatingPill`), partidas e W/D/L (`WdlText`).
     - Top 4 a 8 exibido em cartões com layout e métricas idênticas às do ranking da pelada.
     - Filtro de ordenação interativo (G+A, Nota Média, Gols, Assistências, Vitórias, Partidas, Cartões, Hat Tricks) e alternância crescente/decrescente.
     - Alternador de abas entre Linha e Goleiros (com Clean Sheets, vitórias e média de gols sofridos).
     - Modal de tabela completa ("Ver todos"): substituídas as colunas de "Rating" e "Forma" por **"Nota Média"** (com `RatingPill`), e incluídas as colunas de **Cartões** (com detalhe de amarelos/vermelhos) e **Hat Tricks**.
   - **Reposicionamento dos quadros e evolução:** O gráfico de evolução (`EvolutionChartCard`) e os quadros de gols contra, nota média, taxa de vitórias e duplas dinâmicas (`_buildBoards()`) foram movidos para baixo do ranking geral, seguidos pelos pódios por categoria.
3. **Componente de Avatar (`lib/widgets/shared/ranking_player_bits.dart`):**
   - Adicionado o parâmetro `showTierBorder: bool = false` em `RankAvatar`, calculando o overall via `playerOverallOf(player)` e aplicando as cores e espessuras de borda de acordo com o tier (`overallColor`): Lendária ($\ge 85$), Platina ($80-84$) e Ouro ($< 80$).

---

### E1d · Estilos de Avatares (Fundo vs Auréola), Atualizações Recentes do Grupo e Notificações (AG)

✅ **Concluída em 15/11/2026** (320 testes passando, 0 erros no `dart analyze`).

**O que foi feito:**
1. **Personalização do Estilo Visual de Rating dos Avatares:**
   - **Gerenciador Centralizado (`lib/services/avatar_style_manager.dart`):** Singleton com `AvatarRatingStyle` (`off`, `halo`, `background`) e contextos por tela (`ranking`, `dashboard`, `stats`, `match`). Persistência em `SharedPreferences` (`avatar_style_*`) e reatividade via `ValueNotifier`. Padrão: Fundo no ranking, dashboard e estatísticas, e Auréola na partida.
   - **Painel em Configurações (`lib/screens/settings_screen.dart`):** Seletor segmentado (`Desligado`, `Auréola`, `Fundo`) para cada tela, além de 4 botões de presets rápidos (*Fundo no Ranking, Auréola na Partida*; *Tudo Fundo*; *Tudo Auréola*; *Desligar Tudo*).
   - **Adaptação dos Componentes:**
     - `RankAvatar` (`lib/widgets/shared/ranking_player_bits.dart`): Quando em modo `background`, preenche o círculo com o gradiente do tier do rating (`LinearGradient(palette.gradient)`), centraliza a foto recortada dentro de `ClipOval` e omite a borda/halo externo. Quando `halo`, aplica a borda/halo de tier com glow. Em `off`, mantém fundo neutro sem destaque.
     - `FifaCard` / `_SmallChip` (`lib/widgets/player/fifa_card.dart`): Respeita a preferência de partida (`AvatarContext.match`).
     - `SeasonStatsScreen` (`lib/screens/season_stats_screen.dart`): Conectado a `AvatarContext.stats`.
2. **Seção de Atualizações Recentes no Dashboard:**
   - **Modelo (`lib/models/milestone_update.dart`):** Estrutura de dados para marcos históricos (`MilestoneType`: jogos no total/temporada, gols no total/temporada, assistências no total/temporada, vitórias acumuladas, hat-trick e clean sheet de goleiro).
   - **Cálculo Cronológico (`lib/utils/group_milestones_calculator.dart`):** Analisa as partidas da mais antiga para a mais recente acumulando totais e detectando passagens de limites (10, 25, 50, 75, 100, 150, 200...). Ordena o resultado do mais recente para o menos recente.
   - **Store (`lib/services/dashboard_store.dart`):** Adicionado campo `updates` no `DashboardData`, calculado durante a carga dos dados do grupo.
   - **Exibição (`lib/screens/web/home_dashboard_screen.dart`):** Card de atualizações com badges, datas, navegação para a tela do jogador e abas de alternância (*Todas do Grupo* / *Minhas Notificações*).
3. **Central de Notificações Exclusiva do App Móvel:**
   - **Botão na AppBar (`lib/screens/group_dashboard_screen.dart`):** Ícone de sino com badge de não lidas, restrito ao app móvel autenticado (`!kIsWeb && hasAuth && _myPlayerId != null`). Oculto na versão web somente leitura.
   - **Modal de Notificações (`lib/widgets/shared/notifications_sheet.dart`):** Apresenta as atualizações filtradas para o jogador logado em 1ª pessoa (*"Você alcançou 100 jogos na temporada"*), com persistência do timestamp de leitura (`last_seen_notif_${groupId}_${playerId}`).
4. **Testes Criados (12 novos testes):**
   - `test/utils/group_milestones_calculator_test.dart` (6 testes).
   - `test/services/avatar_style_manager_test.dart` (4 testes).
   - `test/widgets/notifications_sheet_test.dart` (2 testes).

---

## T7b · Aposentar o site antigo — AG + Enzo · **RASCUNHO, por último**

Branch: `chore/remove-old-site` · Só depois de a E1 estar na `main` e o site novo em uso pelos amigos. Faça com a `main` limpa, sem outras branches abertas que mexam em `match_screen`.

**Enzo (nesta ordem):** 1) confirmar que o site novo funciona para os amigos; 2) apagar o projeto do site React na Vercel; 3) conferir no Supabase se mais alguma coisa usa `sync_data` / `my_sync_code`; 4) por último, `drop table sync_data` (SQL entregue pelo Claude, com backup antes).

**AG (código):** remover `SiteSyncService`, `SupabaseSiteSyncService`, `SiteDataGenerator`, a flag `hasSiteSync`, `_scheduleSiteSync` e `_triggerBackgroundSync` do `match_screen`, o campo `siteSync` do `AppServices`, o uso de `my_sync_code` e os trechos do painel de debug que dependem disso; remover do repositório qualquer pasta ou arquivo do site React antigo (se existir); atualizar `ARCHITECTURE.md`, `BACKLOG.md` e `DUVIDAS.md`. **Atenção:** mexe em `match_screen`, onde fica a proteção offline. Exige revisão do Claude Code (prompt com a proibição de `git checkout`/`switch`/`stash`) e o **teste do modo avião (item 9 do checklist)**. Não alterar a chave `pending_matches_v1` nem as outras chaves protegidas. A coluna `groups.sync_code` fica (não apagar sem decisão separada). O prompt completo será escrito quando chegar a hora.

---

## Encerramento da Fase 2 (15/11/2026)

**Entregue:** link secreto por grupo sem login (T6); site Flutter Web somente leitura lendo um snapshot por token (T5, T6b); URL mantém o token; build e deploy automático no Cloudflare Pages via GitHub Actions, com link curto `/fut` e `start_url` do atalho (T7); dashboard "Início" e aba "Peladas" na carta do jogador (E1a, E1b); melhorias visuais no dashboard e reformulação completa da tela de estatísticas da temporada no padrão do ranking de pelada com pódio, top 4-8, cartões, HT e bordas de tier (E1c); personalização de estilo de avatar (fundo vs auréola por tela), seção de atualizações recentes e notificações exclusivas para o perfil logado no app (E1d). 320 testes passando na suíte.

**Pendências que não bloqueiam o encerramento:**
1. **Merge** de E1a (`feat/player-recent-sessions`), E1b (`feat/web-dashboard`), E1c e E1d na `main`. Recomendado: revisão do Claude Code em sessão nova, somente leitura. Conferir que o app personal não teve quebras.
2. **Teste no iPhone** por um amigo (Safari → Adicionar à Tela de Início → abrir pelo ícone). Se o atalho abrir "Link inválido", o `start_url: "/fut"` não valeu no iOS.
3. **Teste do erro de conexão no site publicado** (DevTools → Network request blocking → `*supabase.co*` → recarregar → "Tentar de novo").
4. Conferir `curl -s https://app-fut-site.pages.dev/_redirects | grep -c <início do token>` = 0.
5. **T7b** (remover o site antigo): só quando o site novo estiver em uso pelos amigos; mexe no `match_screen`, então precisa de revisão e do teste de modo avião.
6. **T6c** (tela de admin no app para ver/girar o link): adiada (backlog). Antes, rodar o passo 5 de `sql/F2_T6_testes.md`.
7. **E1c e E1d concluídas em 15/11**; eventuais novos refinamentos estéticos pontuais no futuro podem ser feitos conforme feedback.
8. Antes de divulgar o link: decidir se gira o token (o atual passou por prints e chat); se girar, atualizar o secret `FUT_TOKEN` no GitHub e rodar o workflow.
9. Registrar no `BACKLOG.md`: tela de admin do link (T6c); sequência de vitórias, melhor dupla, mais assíduo e goleiro do mês no dashboard; `/fut` resolver o token atual em tempo de execução (hoje exige atualizar `FUT_TOKEN` após girar); `--no-web-resources-cdn` se o Network mostrar chamadas ao Google; selo "Craque do mês" não guarda o mês (só o portador atual).
10. Ajustes de documentação listados em `TASKS.md` (regra 5 do `ARCHITECTURE.md` com as exceções aditivas da T6 e da S1, seção 7, Fut do INF não apagado, contagem de testes atualizada para 320).
