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
| C3 (invest.) | Investigar senha e RLS do histórico | Claude Code (leitura) | sem branch | ✅ feita em 16/11/2026 |
| C3a | Esconder ações de edição de quem não é admin | AG | `fix/admin-only-actions` | ✅ feita em 16/11/2026 |
| C3b | Conferir RLS real de matches/sessions | Enzo roda o SQL | sem branch | ✅ 16/11/2026: RLS correto (ver seção C3b) |
| C3c | Confirmação do admin (aparelho ou senha) e fim do `"0101"` | AG | `feat/admin-action-gate` | prompt pronto; depende da C3a |
| C1 | Preview "Entra:" no fim de partida | AG | `fix/entering-preview` | prompt pronto; exige teste de modo avião |
| C5 | Mover `F2_T6_share_link.sql` para `docs/sql/` (sem token) | Enzo fornece o arquivo | `docs/share-link-sql` | pendente |

Ordem: C2 ✅, C4 ✅, C3 ✅, C3b ✅, C3a ✅, C3c (depois da C3a), C1, C5. Estado de todas as tarefas: `docs/TASKS.md`.

## Decisões que valem para a fase C
- **C2:** nota e overall pela história inteira em todas as telas; gols, jogos e posição continuam respeitando o filtro de período.
- **C3:** todos veem a lista de partidas do histórico; só o admin altera (lixeira "Limpar tudo", lápis, toque longo de debug); mesmo o admin precisa de confirmação para alterar o histórico. Menu ⋮ do grupo (Editar/Excluir) só para admin. A confirmação dentro do app é atrito (principalmente contra alguém que pega o celular desbloqueado do admin), não segurança: a proteção real é o RLS exigir admin.
- **C3b (16/11/2026):** RLS conferido, está correto. `matches`, `match_events`, `match_lineups`, `rating_history` e `sessions` têm RLS ligado e uma policy `ALL` (`*_write`) com `is_group_admin(...)`. `is_group_admin` = criador do grupo, ou `group_members.role = 'admin'` cujo perfil (`players.creator_id`) é do usuário. Membro comum não altera nem apaga pelo banco (o `DELETE` barrado não dá erro: apaga 0 linhas, por isso a UI deve esconder). Diferença pequena: o app decide admin por `creator_id` ou `role`; o banco exige que o perfil do admin tenha sido criado por ele.
- **C3c (decisão do Enzo, 16/11/2026):** o risco é o celular do admin ficar disponível para outros. Confirmação em TODAS as ações destrutivas (lixeira, lápis, Editar/Excluir grupo, excluir pelada), não só no lápis. Nas Configurações: "Usar autenticação do aparelho (recomendado)" (digital ou PIN do celular) ou "Usar senha" (plano B, hash em SharedPreferences). Pacote `local_auth` aprovado; chaves novas de SharedPreferences aprovadas só para esta tarefa.
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
Tarefa C3a: esconder ações de edição de quem não é admin.
Branch: fix/admin-only-actions (crie a partir da main atualizada).

ANTES DE TUDO
- Leia docs/ARCHITECTURE.md (permissões e C3) e docs/C-TASK.md. Siga o CLAUDE.md. Responda em português simples. Não adicione pacotes.

CONTEXTO (já decidido e verificado)
- Todos veem a lista de partidas do histórico. Só o admin altera.
- O RLS real foi conferido e está correto (5 tabelas exigem is_group_admin). Esta tarefa é só de UI. NÃO altere RLS, SQL, repositórios, nomes de tabelas/colunas, RPCs, fórmulas nem chaves de SharedPreferences.

O QUE FAZER
1. Menu ⋮ "Editar / Excluir" da lista de grupos (lib/main_personal.dart:834-860):
   - Só aparece se features.canAdminister(isAdmin) for true, com isAdmin DAQUELE grupo (AppServices.instance.permissions.isAdmin(group.id)).
   - Carregue o admin de cada grupo junto com a lista (um Map<String,bool> no State, em paralelo com Future.wait). Enquanto não carregou ou se der erro, trate como false (trailing null).
2. Histórico (lib/screens/history_screen.dart):
   - Adicione bool _isAdmin = false, carregado no initState com permissions.isAdmin(widget.groupId) (try/catch → false; setState só se mounted). Mesmo padrão de group_dashboard_screen.dart:119-127.
   - Getter: bool get _canAdminister => AppServices.instance.features.canAdminister(_isAdmin).
   - Troque os "!isReadOnly" por _canAdminister em: lixeira "Limpar tudo" (260-276), lápis (326-330) e toque longo (314-316).
   - Coloque if (!_canAdminister) return; na primeira linha de _clearHistory, _promptPasswordForEdit e _showDebugInfo.
   - TODOS continuam vendo a lista, os cards expandidos e o botão Exportar. Membro comum não vê nenhum botão ou menu de alteração.
   - Para admin, tudo fica igual a hoje, inclusive a senha "0101". NÃO altere, mova nem comente a senha (é a tarefa C3c).
3. Não toque em repositórios, match_screen, proteção offline/outbox nem no site somente leitura (isReadOnly continua escondendo tudo; o app público continua com isAdmin = true).
4. Testes (padrão de test/screens/history_screen_readonly_test.dart e test/helpers/test_app_services.dart; amplie o stub de permissões se precisar, sem mudar o comportamento atual dele):
   - Histórico, membro comum (isAdmin = false): NÃO aparece Icons.delete_forever nem Icons.edit, o toque longo NÃO abre o debug, a lista ("2 x 1") continua visível.
   - Histórico, admin (isAdmin = true): lixeira e lápis aparecem, o toque longo abre o debug. O teste existente "isReadOnly = false (personal): long press abre _showDebugInfo" vai precisar de um admin no stub: ajuste só o stub, sem enfraquecer a verificação.
   - Histórico, isReadOnly = true: continua sem nenhuma ação.
   - Lista de grupos (main_personal): membro comum não vê o ⋮; admin vê Editar e Excluir. Se a tela for difícil de testar como está, diga qual extração mínima seria necessária ANTES de refatorar; não refatore por conta própria.
5. Docs: marque C3a como feita em docs/TASKS.md e docs/C-TASK.md. Deixe C3c pendente.
6. Rode flutter analyze e flutter test e informe os números (antes: 322; esperado: 322 + os novos, 0 falhas, sem problemas novos no analyze).

ENTREGA
- Commits pequenos em português na branch, sem merge na main.
- Relatório final simples: arquivos alterados (arquivo:linha), testes novos, números do analyze e do test, e o que ficou de fora ou surpreendeu.
```

**Depois:** revisão em sessão nova do Claude Code e teste manual do Enzo com uma conta de membro comum.

---

## C3b: RLS real de matches/sessions (resultado)

Conferido pelo Enzo em 16/11/2026 com `pg_policies`, `pg_class` e `pg_get_functiondef`: RLS ligado nas 5 tabelas; uma policy `ALL` por tabela (`matches_write`, `match_events_write`, `match_lineups_write`, `rating_history_write`, `sessions_write`), todas com `is_group_admin(...)` em `USING` e `WITH CHECK`. **Nada a corrigir no banco.** Detalhes na seção "Decisões".

---

## C3c: confirmação do admin nas ações destrutivas (sem o `"0101"`)

**Contexto:** o risco real é o celular do admin ficar disponível para outros. O RLS já barra membro comum; esta tarefa é atrito para quem pega o aparelho do admin. Depende da C3a (os botões já só existem para admin).

**Aceite:**
- Uma única função de confirmação, usada em: lixeira "Limpar tudo", lápis de edição, Editar e Excluir do grupo (menu ⋮) e excluir pelada.
- Nas Configurações, o admin escolhe: "Usar autenticação do aparelho (recomendado)" ou "Usar senha". Padrão: aparelho.
- O `"0101"` some do código. Nenhuma senha literal no repositório.
- Testes com autenticador falso (sem biometria real).

**Pacotes e chaves:** `local_auth` e `crypto` (hash da senha) aprovados pelo Enzo em 16/11/2026. Chaves novas de SharedPreferences aprovadas só para esta tarefa: `admin_gate_mode`, `admin_gate_pass_hash`, `admin_gate_pass_salt` (registrar em `docs/INVENTARIO_SHAREDPREFS.md`).

**Prompt (AG):** cole o cabeçalho da fase C e depois:

```
Tarefa C3c: confirmação do admin nas ações destrutivas. Branch: feat/admin-action-gate (a partir da main, com a C3a já mesclada).

ANTES DE TUDO: leia docs/ARCHITECTURE.md (C3) e docs/C-TASK.md (C3, C3b, C3c). Siga o CLAUDE.md. Responda em português simples.

AUTORIZADO NESTA TAREFA (exceção às regras): adicionar os pacotes local_auth e crypto ao pubspec.yaml e 3 chaves NOVAS de SharedPreferences (admin_gate_mode, admin_gate_pass_hash, admin_gate_pass_salt). Nada além disso. Não altere repositórios, RLS, SQL, tabelas/colunas, fórmulas nem chaves de SharedPreferences existentes. Não mexa no match_screen nem na proteção offline.

1. FUNÇÃO ÚNICA (ex.: lib/services/admin_action_gate.dart):
   Future<bool> confirmAdminAction(BuildContext context, {required String motivo})
   - Lê o modo em SharedPreferences (admin_gate_mode: 'device' (padrão) ou 'password').
   - Atrás de uma interface (ex.: DeviceAuthenticator) para os testes usarem um falso; a implementação real usa local_auth.
   - Modo 'device': local_auth.authenticate com biometricOnly: false (digital OU PIN/padrão do aparelho). Se o aparelho não tem nenhum bloqueio de tela (isDeviceSupported() false ou nada cadastrado), mostre "Ative um bloqueio de tela no celular ou escolha 'Usar senha' nas Configurações" e devolva false. Nunca deixe passar por falha.
   - Modo 'password': diálogo pedindo a senha do app (campo oculto). Confira por hash SHA-256 com sal aleatório (Random.secure), nunca guardando a senha em texto. Se ainda não há senha definida, avise "Defina a senha nas Configurações" e devolva false. Após 5 erros seguidos, bloqueie por 30 segundos (só em memória). Link "Esqueci a senha": pede a autenticação do aparelho e, se passar, deixa definir uma senha nova; se o aparelho não tiver bloqueio, explique que só limpando os dados do app.
   - Qualquer erro/exceção/cancelamento = false (a ação NÃO acontece).
2. USO (chamar ANTES da ação; se devolver false, não faz nada):
   - history_screen.dart: lixeira "Limpar tudo" (antes do diálogo "Limpar") e lápis (_promptPasswordForEdit passa a usar a função; remover o diálogo "Acesso Restrito" e o "0101").
   - main_personal.dart: Editar e Excluir do menu ⋮ do grupo (843-844).
   - sessions_screen.dart: excluir pelada (_confirmDeleteSession, ~129-134).
   - O toque longo de debug NÃO pede confirmação (só mostra IDs).
   - App público (isAdmin sempre true) e site somente leitura: sem mudança de comportamento no site. Se o app público rodar em plataforma sem local_auth, trate como "aparelho sem suporte" (mensagem + usar senha).
3. CONFIGURAÇÕES (settings_screen.dart, só se features.canAdminister(isAdmin)): seção "Segurança do administrador" com duas opções: "Usar autenticação do aparelho (recomendado)" e "Usar senha". Ao escolher "Usar senha" sem senha definida: pedir para criar (mínimo 4 dígitos, digitar duas vezes). Com senha definida: opções "Trocar senha" (pede a atual) e voltar para "aparelho". A escolha é por aparelho, não por grupo. Texto curto explicando cada opção em português simples.
4. ANDROID/IOS: android/app/src/main/kotlin/com/example/app_do_fut/MainActivity.kt deve estender FlutterFragmentActivity (exigência do local_auth); AndroidManifest com android.permission.USE_BIOMETRIC; ios/Runner/Info.plist com NSFaceIDUsageDescription ("Confirmar ações do administrador"). Só isso nos arquivos nativos.
5. TESTES (autenticador falso; padrão dos testes existentes):
   - modo aparelho: autenticou → ação roda; falhou/cancelou → não roda; sem bloqueio de tela → não roda e mostra a mensagem.
   - modo senha: correta → roda; errada → não roda; 5 erros → bloqueio; sem senha definida → não roda; o hash salvo NÃO contém a senha em texto.
   - history: lixeira e lápis chamam a confirmação; com false, o repositório não é chamado.
   - configurações: aparece só para admin; trocar de modo grava a chave certa.
   - grep final: nenhum "0101" nem senha literal em lib/.
6. DOCS: docs/INVENTARIO_SHAREDPREFS.md (3 chaves novas), TASKS.md e C-TASK.md (C3c feita), ARCHITECTURE.md (nota C3).
7. Rode flutter analyze e flutter test e informe os números. Commits pequenos, sem merge. Relatório final simples com arquivo:linha e o que ficou de fora.
```

**Depois:** revisão em sessão nova do Claude Code (prompt abaixo) e teste no aparelho do Enzo: (1) modo aparelho com digital; (2) modo aparelho cancelando; (3) modo senha certa e errada; (4) celular sem bloqueio de tela.

**Prompt de REVISÃO (Claude Code, sessão nova, somente leitura):**

```
REVISÃO da tarefa C3c (branch feat/admin-action-gate). Somente leitura: não edite nada, não rode git checkout, switch nem stash (use git diff main...feat/admin-action-gate e git show para ler a branch). Não rode nada contra o banco. Responda em português simples, com arquivo:linha, separando "PROBLEMA" (precisa corrigir), "ATENÇÃO" (decidir) e "OK".

Confira, nesta ordem:
1. ESCOPO: git diff main...feat/admin-action-gate --stat. Só podem mudar: a função de confirmação, history_screen, main_personal, sessions_screen, settings_screen, testes, docs, pubspec (apenas local_auth e crypto), MainActivity.kt, AndroidManifest e Info.plist. Qualquer mudança em repositórios, match_screen, proteção offline/outbox, RLS/SQL, fórmulas ou chaves de SharedPreferences existentes é PROBLEMA.
2. PACOTES: pubspec.yaml e pubspec.lock só ganharam local_auth e crypto (e dependências deles)? Versões compatíveis com o SDK do projeto? Nenhum outro pacote?
3. ARQUIVOS NATIVOS:
   - MainActivity.kt estende FlutterFragmentActivity (não FlutterActivity) e o import está certo.
   - AndroidManifest tem USE_BIOMETRIC e nada a mais (nenhuma permissão extra).
   - Info.plist tem NSFaceIDUsageDescription.
   - Há tema Android que o local_auth exige (ex.: LaunchTheme/NormalTheme herdando de Theme.AppCompat/Material)? Aponte risco de crash no Android.
   - Existem outros flavors/pastas (ex.: app público, web) com MainActivity ou manifest próprios que também precisariam do ajuste?
4. SEGURANÇA DA FUNÇÃO (confirmAdminAction):
   - Em TODO erro, exceção, cancelamento, timeout, sem suporte ou sem bloqueio de tela, devolve false? Existe algum caminho que devolve true sem autenticar (try/catch que engole e segue, default true, if invertido)?
   - Modo padrão é 'device'? O que acontece se o valor salvo for lixo ou ausente?
   - biometricOnly está false (aparelho = digital ou PIN) como decidido?
   - Senha: hash SHA-256 com sal aleatório (Random.secure), senha nunca salva nem logada em texto (grep em debugPrint/print), comparação do hash correta, bloqueio de 30 s após 5 erros funciona e não zera ao fechar/abrir o diálogo.
   - "Esqueci a senha" só deixa redefinir depois de autenticar pelo aparelho; sem bloqueio de tela, não deixa.
   - Trocar de "senha" para "aparelho" ou trocar a senha exige confirmação? (Alguém com o celular desbloqueado não pode desligar a proteção sem passar por ela.) Se não exige, é PROBLEMA.
5. USO: a confirmação é chamada ANTES da ação e o false realmente impede (lixeira, lápis, Editar e Excluir do grupo, excluir pelada)? Algum caminho chega às ações sem passar por ela (outro botão, atalho, toque longo, outra tela)? Rode um grep por deleteMatch, updatePartialMatch, deleteSession, deleteGroup, updateGroup em lib/ e liste quem chama cada um. O "0101" e qualquer senha literal sumiram de lib/ (grep "0101", "senha", "password")?
6. CONFIGURAÇÕES: a seção só aparece para features.canAdminister(isAdmin); a escolha é por aparelho; as 3 chaves novas são as únicas novas, com os nomes combinados (admin_gate_mode, admin_gate_pass_hash, admin_gate_pass_salt); estão em docs/INVENTARIO_SHAREDPREFS.md.
7. SITE E APP PÚBLICO: o site somente leitura não mudou de comportamento e não importa local_auth de forma que quebre o build web (kIsWeb / import condicional)? O app público continua funcionando em plataforma sem suporte (mensagem + senha)?
8. TESTES: cobrem tudo o que o prompt da C3c pede (aparelho ok/falha/sem bloqueio; senha certa/errada/5 erros/sem senha/hash sem texto; history; configurações)? Os testes usam o autenticador falso, sem depender de biometria real? Algum teste foi enfraquecido para passar? Rode flutter analyze e flutter test e informe os números (baseline: 322 + os novos da C3a).
9. RISCOS PARA O ENZO TESTAR NO APARELHO: liste o que só dá para ver num celular de verdade (digital, cancelar, PIN, celular sem bloqueio) e o que pode surpreender o admin (ex.: ficar sem acesso, mensagens confusas).

Termine com: veredito (pode mesclar / corrigir antes) e a lista curta do que o AG precisa corrigir.
```

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
