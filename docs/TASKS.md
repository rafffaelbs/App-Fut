# TASKS.md — Plano de tarefas

Legenda de quem faz: **AG** = Antigravity (executa) · **CLAUDE** = Claude (desenha ou revisa).
Fluxo de cada tarefa: criar a branch → fazer → `flutter analyze` + `flutter test` → commit → (se houver revisão) mandar para o Claude → merge na `main` → teste manual (checklist da seção 8 do `ARCHITECTURE.md`) quando indicado.

## Cabeçalho a colar no INÍCIO de todo prompt

```
Contexto: leia docs/ARCHITECTURE.md e docs/INVENTARIO_SUPABASE.md antes de começar.
Regras: não mude comportamento visível do app; não altere fórmulas dos calculators,
nomes de tabelas/colunas do Supabase, RLS ou RPCs; não adicione pacotes; preserve os
textos de erro existentes. Se encontrar algo que o documento não cobre, NÃO decida:
registre em docs/DUVIDAS.md (arquivo, linha, o que viu) e continue com o resto.
Ao terminar: rode `flutter analyze` e `flutter test`, faça commits pequenos e
me diga em 5 linhas o que mudou e o que ficou pendente.
```

---

## FASE 0 — Rede de segurança

### T0 · Testes de caracterização dos cálculos — AG
Branch: `test/characterization-calculators` · Revisão: não precisa

```
[cabeçalho]
Tarefa: criar testes de caracterização para lib/utils/rating_calculator.dart,
overall_calculator.dart e stats_calculator.dart, em test/utils/.
NÃO altere nenhum arquivo em lib/.
Para cada função pública: no mínimo 5 casos com entradas fixas e variadas
(incluindo: zero eventos, sequência de vitórias, goleiro, nota nos limites 0.0 e 10.0,
jogador sem nota da comunidade). O valor esperado é o resultado ATUAL do código:
rode, copie o valor e fixe no teste. Não "corrija" nada que pareça estranho: apenas
registre em docs/DUVIDAS.md.
Se alguma função não for testável sem Flutter binding ou Supabase, anote no DUVIDAS.md.
Aceite: flutter test passa; flutter analyze sem erros novos; lib/ sem alterações (git diff main --stat).
```

### T0b · Separar scripts legados — AG
Branch: `chore/move-legacy-scripts` · Revisão: não · **Só execute depois que o Enzo confirmar que não usa mais**

```
[cabeçalho]
Mova (git mv) lib/services/data_migration_service.dart e
lib/services/fix_event_times_service.dart para tool/legacy/. Eles são scripts de
migração antigos e não devem fazer parte do app. Remova qualquer import/uso deles em
lib/ (telas, botões de debug, main). Se algo no app depender deles, liste em
docs/DUVIDAS.md e NÃO apague a funcionalidade: apenas deixe um comentário TODO.
Aceite: flutter analyze sem erros; app compila; grep por "data_migration_service" e
"fix_event_times_service" em lib/ retorna nada.
```

---

## FASE 1 — Interfaces (o app personal continua idêntico)

### T1 · Criar as interfaces de repositório — AG, revisão CLAUDE
Branch: `refactor/domain-interfaces`

```
[cabeçalho]
Crie classes abstratas em lib/domain/repositories/ (um arquivo por interface, nome em
snake_case, ex.: players_repository.dart) seguindo EXATAMENTE a seção 4 do
docs/ARCHITECTURE.md:
GroupsRepository, SeasonsRepository, SessionsRepository, MatchesRepository,
RatingsRepository, SessionArrivalsRepository, PlayersRepository,
PlayerAccountRepository, MembershipRepository, GoalSoundRepository,
ActionLogsRepository.
Copie as assinaturas públicas dos repositórios atuais em lib/repositories/
(mesmos nomes, parâmetros, valores padrão e tipos de retorno). Distribua os métodos
entre as interfaces conforme o mapa da seção 4. Não inclua isCurrentUserAdmin em
MembershipRepository. Em SessionsRepository adicione:
  Future<Map<String, dynamic>?> getRuntimeState(String sessionId);
Crie também lib/domain/services/auth_service.dart e permission_service.dart com as
assinaturas da seção 4.3 (e a classe AppAuthException(String message)).
Somente arquivos NOVOS: não altere nenhum arquivo existente nesta tarefa.
Aceite: flutter analyze ok; git diff main --stat mostra apenas arquivos novos em lib/domain/.
```

Revisão CLAUDE: o Enzo me manda o conteúdo de `lib/domain/` (só essa pasta).

### T2 · AuthService e PermissionService — AG, revisão CLAUDE (só o PermissionService)
Branch: `refactor/auth-permission` · Depende de T1

```
[cabeçalho]
1) Crie lib/data/supabase/supabase_auth_service.dart (implements AuthService) usando o
   cliente Supabase atual. Converta AuthException em AppAuthException(message) com a
   mesma mensagem que as telas mostram hoje.
2) Crie lib/data/supabase/supabase_permission_service.dart (implements PermissionService)
   movendo a lógica atual de GroupMembersRepository.isCurrentUserAdmin (creator_id do
   grupo OU role == 'admin'). requireAdmin lança a MESMA exceção e mensagem que os
   repositórios lançam hoje.
3) Substitua os usos diretos de auth:
   - lib/main.dart linhas ~68, 70, 589 (AuthGate e logout)
   - lib/screens/login_screen.dart linhas ~30, 35 (signUp/signInWithPassword) e o import
     de supabase_flutter
   - lib/screens/complete_profile_screen.dart linha ~94 (signOut)
   - supabase_config.dart: currentUser/currentUserId passam a vir do AuthService
4) Todo uso de isCurrentUserAdmin (repositórios e telas listados na seção 5 do
   inventário) passa a chamar PermissionService.isAdmin / requireAdmin. Nos
   repositórios, receba PermissionService no construtor.
5) Remova isCurrentUserAdmin de GroupMembersRepository.
Por enquanto o acesso aos serviços pode ser por um campo estático temporário em
SupabaseService (será substituído na T3b).
Aceite: flutter analyze e flutter test ok; grep "isCurrentUserAdmin" em lib/ retorna
nada; comportamento idêntico (checklist manual itens 1, 7 e 8).
```

Revisão CLAUDE: `supabase_permission_service.dart` + o diff de um repositório (ex.: `seasons_repository.dart`).

### T3a · Mover e renomear os repositórios Supabase — AG
Branch: `refactor/supabase-data-layer` · Depende de T1 e T2

```
[cabeçalho]
1) Mova (git mv) cada arquivo de lib/repositories/*_repository.dart para
   lib/data/supabase/ e renomeie a classe com prefixo Supabase
   (PlayersRepository -> SupabasePlayersRepository, etc.).
2) Cada classe passa a "implements" a(s) interface(s) de lib/domain/repositories/
   conforme o mapa da seção 4. SupabasePlayersRepository implementa
   PlayersRepository, PlayerAccountRepository e GoalSoundRepository;
   SupabaseGroupMembersRepository implementa MembershipRepository.
3) Implemente SessionsRepository.getRuntimeState com a consulta que hoje está em
   match_screen.dart linhas ~410-415 (mesmas colunas, mesmo comportamento).
4) Mova lib/config/supabase_config.dart para lib/data/supabase/supabase_config.dart.
5) Atualize os imports. Não mude a lógica interna dos métodos.
Aceite: flutter analyze ok; flutter test ok; app compila.
```

### T3b · AppServices no lugar do SupabaseService.instance — AG
Branch: `refactor/app-services` · Depende de T3a

```
[cabeçalho]
1) Crie lib/app/app_services.dart: uma classe que guarda as INTERFACES
   (groups, members, seasons, players, playerAccounts, goalSounds, sessions, matches,
   ratings, sessionArrivals, actionLogs, auth, permissions) e um acesso estático
   AppServices.instance (definido uma vez na inicialização).
2) Crie lib/bootstrap_personal.dart que inicializa o Supabase (o que hoje está em
   SupabaseConfig/ main) e monta o AppServices com as implementações Supabase*.
3) Crie lib/main_personal.dart chamando o bootstrap e rodando o app. lib/main.dart
   passa a apenas chamar main_personal.
4) Substitua em TODO o código fora de lib/data/supabase/ os usos de
   SupabaseService.instance.* por AppServices.instance.* (tipados pelas interfaces).
5) Apague lib/repositories/supabase_service.dart e a pasta lib/repositories/ se vazia.
Aceite: flutter analyze ok; flutter test ok; a verificação de isolamento do Supabase
(seção 2, regra 2 do ARCHITECTURE.md) imprime apenas services legados
(sync_service, cache_sync_manager e, se a T0b ainda não foi feita, data_migration_service
e fix_event_times_service), que serão tratados na T3c/T0b; checklist manual completo.
```

### T3c · Tirar sync_service e cache_sync_manager do caminho — AG
Branch: `refactor/backup-service` · Depende de T3b · **Responder antes**: esses dois ainda são usados?

```
[cabeçalho]
lib/services/sync_service.dart e lib/services/cache_sync_manager.dart usam a tabela
sync_data do Supabase.
1) Crie lib/domain/services/backup_service.dart (interface mínima com os métodos
   públicos que as telas usam hoje de SyncService e CacheSyncManager).
2) Mova as implementações para lib/data/supabase/ (supabase_backup_service.dart etc.)
   implementando essa interface; registre no AppServices.
3) As telas passam a usar AppServices.instance.backup (pode ser nulo quando
   AppFeatures.hasCloudBackup for false; trate o nulo escondendo o recurso).
Aceite: a verificação de isolamento (regra 2) imprime NADA; flutter analyze ok;
checklist manual completo.
```

### T4 · AppFeatures e flavor personal — AG
Branch: `feat/app-features` · Depende de T3c

```
[cabeçalho]
1) Crie lib/app/app_features.dart com as flags da seção 5 do ARCHITECTURE.md
   (hasAuth, hasMembershipManagement, hasCosmetics, hasGoalSounds, hasAuditLog,
   hasCloudBackup, hasDbExportImport, isReadOnly) e a configuração "personal"
   (tudo como na coluna personal).
2) Registre em AppServices.
3) Nas telas, a visibilidade de recursos passa a ser: AppFeatures permite E
   PermissionService.isAdmin (quando aplicável) E !isReadOnly. Telas e botões a
   cobrir: engrenagem do GroupDashboardScreen (ManageJoinRequests, ManageMembers,
   ManageBadges, ManageSeasons, AdminDebug), FAB de SessionsScreen e PlayersScreen,
   opções de cosméticos/atributos no PlayerDetail e ManageBadgesScreen, upload de
   som de gol, tela de login/AuthGate (hasAuth).
No personal tudo continua aparecendo exatamente como hoje.
Aceite: flutter analyze/test ok; checklist manual completo idêntico ao anterior.
```

**Gate:** Enzo roda o checklist manual no celular → merge na `main` → me avisa. A partir daqui eu entrego os prompts detalhados da Fase 2 e 3.

---

## FASE 2 — Site somente leitura (iPhone)  ·  *detalhar depois do gate*

| # | Tarefa | Quem |
|---|---|---|
| T5 | Proteger `dart:io`/`path_provider`/`screenshot`/`share_plus` nas 3 telas de ranking/histórico (import condicional ou `kIsWeb`); `main_web.dart` com `isReadOnly = true`; esconder todo recurso de escrita | AG |
| T6 | Modelo de acesso e policies RLS de `SELECT` (login por e-mail **ou** link público) | **CLAUDE** |
| T7 | Build web, hospedagem e checagem no Safari do iPhone | AG |

## FASE 3 — App público offline  ·  *detalhar depois do gate*

| # | Tarefa | Quem |
|---|---|---|
| T8 | Schema drift + `schemaVersion` + migrações | **CLAUDE** |
| T9 | Repositórios locais simples (CRUD) seguindo o modelo que eu entregar | AG |
| T10 | Repositórios locais com transação (`createGroup`, `saveFullMatch`, `updateFullMatch`, `updatePartialMatch`, `deleteMatch`, `savePendingMatch`, `replaceArrivals`, `createGhostPlayer`) | **CLAUDE** |
| T11 | Exportar/importar `.db` (`VACUUM INTO`, `integrity_check`, backup antes de importar) | **CLAUDE** |
| T12 | `bootstrap_public.dart`, `main_public.dart`, auth local fixo, grupo e temporada criados no primeiro uso | AG |
| T13 | Tema neutro, nome, ícone, remover recursos do personal no public | AG |
| T14 | Build Android do app público (assinatura, ícone, nome) | AG |

---

## Perguntas em aberto (afetam as tarefas)

1. `sync_service` / `cache_sync_manager` (tabela `sync_data`) ainda são usados? → define T3c.
2. `data_migration_service` / `fix_event_times_service` ainda são usados? → define T0b (se não, mover ou apagar).
3. Web somente leitura: quem usa iPhone entra com **e-mail e senha** ou abre **um link sem login**? → define T6.
4. App público: **um grupo só** (suposição atual) ou várias peladas/grupos?
