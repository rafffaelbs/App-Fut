# F0-TASK.md — Fase 0: rede de segurança e limpeza (✅ concluída, histórico)

> Só consulta. Todas as tarefas desta fase já estão na `main`. Os prompts ficam como registro do padrão usado.

## Cabeçalho a colar no INÍCIO de todo prompt

```
Contexto: leia docs/ARCHITECTURE.md e docs/INVENTARIO_SUPABASE.md (e docs/INVENTARIO_OFFLINE.md
quando a tarefa tocar fila, cache ou match_screen) antes de começar.
Regras: não mude comportamento visível do app; não altere fórmulas dos calculators,
nomes de tabelas/colunas do Supabase, RLS ou RPCs; não altere chaves de SharedPreferences;
não adicione pacotes; preserve os textos de erro existentes. Se encontrar algo que o
documento não cobre, NÃO decida: registre em docs/DUVIDAS.md (arquivo, linha, o que viu)
e continue com o resto.
Ao terminar: rode `flutter analyze` e `flutter test`, faça commits pequenos e
me diga em 5 linhas o que mudou e o que ficou pendente.
```

## FASE 0 — Rede de segurança e limpeza (todas podem rodar em paralelo)

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
Atenção: stats_calculator.dart lê SharedPreferences direto (getAllGroupMatches, ~linhas 100-124).
Para testar essas funções use SharedPreferences.setMockInitialValues({...}) com dados fixos
(não precisa de Supabase).
Aceite: flutter test passa; flutter analyze sem erros novos; lib/ sem alterações (git diff main --stat).
```

### T0b · Mover scripts de migração antigos — AG
Branch: `chore/move-legacy-scripts` · Revisão: não · **Confirmado pelo Enzo: não são mais usados**

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

### T0c · Remover código morto do sync — AG
Branch: `chore/remove-dead-sync-code` · Revisão: não

Motivo (do `INVENTARIO_OFFLINE.md`): a `SyncScreen` não é alcançável por nenhuma rota; o campo `_syncService` em `main.dart` nunca é usado; `importDataFromSupabase` (que apaga todo o `SharedPreferences` antes de restaurar) só é chamado pela tela órfã; `exportToFile`/`importFromFile` não têm chamadores. Remover isso também elimina o problema do `file_picker` v11 e os usos de `dart:io` desse arquivo.

```
[cabeçalho]
Remova código morto confirmado em docs/INVENTARIO_OFFLINE.md. Antes de apagar cada item,
confirme com grep em lib/ que não há outro uso. Se houver, NÃO apague e registre em
docs/DUVIDAS.md.
1) lib/screens/sync_screen.dart (sem rota que leve a ela) e seus imports.
2) lib/main.dart (~linha 154): o campo `_syncService` de _HomePageState, que nunca é usado
   (e o import, se ficar sem uso).
3) lib/services/sync_service.dart: remova importDataFromSupabase, exportToFile e
   importFromFile, e os imports que ficarem sem uso (dart:io, file_picker, share_plus,
   path_provider, se só esses métodos os usavam).
MANTENHA: exportDataToSupabase e getOrCreateSyncCode (usados por
match_screen._triggerBackgroundSync e admin_debug_screen) e as chamadas a
CacheSyncManager.recordCloudSyncSuccess.
MANTENHA a dependência file_picker no pubspec.yaml (será usada de novo mais adiante).
Aceite: analyze/test ok; checklist manual itens 1 a 4; 
`grep -rn "SyncScreen\|importDataFromSupabase\|exportToFile\|importFromFile" lib` retorna nada.
```

### T0d · Inventário de SharedPreferences (somente leitura) — AG
Branch: `docs/inventario-sharedprefs` · Revisão: **CLAUDE** (me mande o `.md`)

```
Tarefa somente de leitura. NÃO altere arquivos em lib/.
Gere docs/INVENTARIO_SHAREDPREFS.md. Liste TODAS as chaves usadas em SharedPreferences
(getString/setString/getInt/setInt/getBool/setBool/remove/containsKey e prefixos como
cache:, players_$groupId, match_history_$id, present_players_$id, pending_matches_v1,
ratings_snapshot_at_$groupId...). Para cada chave ou prefixo informe: arquivo e linha de
quem ESCREVE, quem LÊ, o que contém e a categoria:
 (a) cache de algo que também existe no Supabase
 (b) estado temporário de partida em andamento
 (c) fila de envio
 (d) preferência de configuração
 (e) dado que SÓ existe localmente (não está no Supabase)
Responda também:
1. Quais telas leem match_history_* (histórico local) em vez de repositórios?
2. Onde rating_history é gravado no fluxo de finalizar partida (savePendingMatch não
   grava rating_history)? Quem chama recordRatingsBatch, saveFullMatch e updateFullMatch, e quando?
3. Existe algum dado exibido nas telas que NÃO venha de repositório (só de SharedPreferences)?
Apenas fatos, com arquivo e número de linha. Não proponha mudanças.
```

### T0e · Código morto e telas inalcançáveis (somente leitura) — AG
Branch: `docs/codigo-morto` · Revisão: não (me mande só o resumo) · **Fazer antes da T1**

```
Tarefa somente de leitura. NÃO altere arquivos em lib/.
Gere docs/CODIGO_MORTO.md com:
1. Para CADA método público das classes em lib/repositories/ (actions_logs, group_members,
   groups, matches, players, ratings, seasons, session_arrivals, sessions): o número de
   chamadores FORA da própria classe, com arquivo:linha de cada um. Escreva "0 CHAMADORES"
   quando não houver nenhum. Considere chamadas via SupabaseService.instance.<repo>.<método>,
   por campos injetados e por outros repositórios.
2. Para CADA arquivo em lib/screens/: quem o abre (Navigator.push, rotas nomeadas,
   MaterialPageRoute, home:), com arquivo:linha. Escreva "INALCANÇÁVEL" se nenhuma rota ou
   botão chega nele. Atenção especial: group_ranking_screen.dart, ranking_screen.dart,
   expanded_ranking_screen.dart, season_stats_screen.dart, history_screen.dart,
   blank_screen.dart.
3. Para cada tela ALCANÇÁVEL de ranking ou estatística: de onde vêm os dados (repositório,
   SharedPreferences ou ambos), em uma linha por tela.
Apenas fatos, com arquivo e número de linha. Não proponha mudanças.
```

---

### T0g · Remover telas inalcançáveis (parte da Fase 0) — AG
Branch: `chore/remove-unreachable-screens` · Revisão: não · **Só rodar se o Enzo confirmar** (pergunta em aberto 3) · Pode rodar antes ou depois da T1; precisa estar pronta antes da T3e

```
[cabeçalho]
Conforme docs/CODIGO_MORTO.md, estas telas não são abertas por nenhuma rota ou botão:
lib/screens/expanded_ranking_screen.dart, group_ranking_screen.dart, tournament_screen.dart
e blank_screen.dart (esta só é aberta por tournament_screen).
1) Confirme com grep em lib/ e test/ que continuam sem uso. Se houver uso, NÃO apague e
   registre em docs/DUVIDAS.md.
2) Apague os 4 arquivos, o import não utilizado em lib/main.dart (~linha 5) e quaisquer
   imports que ficarem sem uso.
3) Widgets, utils ou constantes que ficarem sem NENHUM uso depois disso: NÃO apague; liste-os
   em docs/DUVIDAS.md.
Aceite: flutter analyze sem erros novos e flutter test ok;
`grep -rnw "ExpandedRankingScreen\|GroupRankingScreen\|TournamentScreen\|BlankScreen" lib test`
retorna nada; checklist manual itens 1 a 4.
```

