# Implementation Plan — AI-Friendly Refactoring (`lib/`)

Escopo exclusivo: `lib/`. Objetivo: tipagem forte, null-safety defensiva e SRP (widgets < 200 linhas).

---

## Diagnóstico atual

| Área | Situação |
|------|----------|
| `lib/models/` | **Inexistente** — todo domínio vive em `Map<String, dynamic>` |
| JSON / prefs | Chaves espalhadas (`sessions_`, `players_`, `match_history_`, `seasons_`, `app_groups`, `team_red_`, etc.) |
| Null safety | `!` em prefs (`getString(...)!`), em maps (`session!['jogadores']`) e em lookups (`globalStats[pid]!`) |
| Acoplamento | Screens e utils leem/escrevem maps crus; widgets de match já existem mas ainda recebem `Map` |
| `sessions_screen.dart` | **637 linhas** — dialog de criar/editar (~375 linhas), delete dialog e card da lista embutidos |
| Arquivos críticos por tamanho | `match_screen` 2988, `ranking_screen` 2612, `player_detail` 2381, `group_ranking` 1792 (fora do escopo imediato deste plano, mas modelos os desbloqueiam) |

### Shapes JSON observados (para models)

**Group** (`app_groups`): `id`, `name`, `createdAt`

**Session / Pelada** (`sessions_{groupId}`):
- `id`, `title`, `date` (display `dd/MM/yyyy`), `timestamp` (ISO)
- `status` (`Em Andamento` | outros)
- `jogadores` (int — jogadores por time), `duration` (min)
- `win_limit` (0 = infinito), `streak_action` (`split` | `dual_exit`), `draft_mode` (bool)

**Player** (`players_{groupId}`): `id`, `name`, `icon?`, `rating?`, `manual_badges?` (`[{icon, title, ...}]`)

**Match** (`match_history_{sessionId}`):
- `scoreRed`, `scoreWhite`, `date` / `session_date`
- `players`: `{ red: [], white: [], gk_red, gk_white }`
- `events`: `[{ type, player|playerId, assist|assistId, ... }]` (`goal`, `own_goal`, `yellow_card`, `red_card`)

**Season** (`seasons_{groupId}`): `id`, `startDate`, `endDate`, `isPreSeason?`, `parentSeasonId?`

**PlayerStats** (calculado, não persistido como entidade única): `id`, `name`, `games`, `wins`, `draws`, `losses`, `goals`, `assists`, `ga`, `yellow`, `red`, `ratings`, `nota`

---

## Fase 1 — Data Models fortemente tipados (`lib/models/`)

### 1.1 Criar pasta e convenção
- Criar `lib/models/`.
- Cada model: campos explícitos, `factory X.fromJson(Map<String, dynamic>)`, `Map<String, dynamic> toJson()`.
- Parsers defensivos: `int.tryParse`, casts com fallback (`??`), nunca assumir tipo do JSON legado.
- Manter **compatibilidade de chaves** com o JSON atual (ex.: `jogadores`, não renomear no storage nesta fase).

### 1.2 Models prioritários (ordem de criação)

| Arquivo | Classe | Prioridade | Consumidores imediatos |
|---------|--------|------------|------------------------|
| `group.dart` | `Group` | P0 | `main.dart` |
| `session.dart` | `Session` | P0 | `sessions_screen`, `stats_calculator`, `site_data_generator` |
| `player.dart` | `Player`, `PlayerBadge` | P0 | `players_screen`, widgets match/player, `player_identity` |
| `match_event.dart` | `MatchEvent` | P1 | `stats_calculator`, `match_screen`, `player_detail` |
| `match.dart` | `Match`, `MatchPlayers` | P1 | history / ranking / stats |
| `season.dart` | `Season` | P1 | `manage_seasons_screen`, `stats_calculator` |
| `player_stats.dart` | `PlayerStats` | P1 | `calculateGlobalStats`, ranking, comparison |
| `badge_definition.dart` | `BadgeDefinition` | P2 | `manage_badges_screen` |

### 1.3 Detalhes por model

**`Session`**
```dart
// campos: id, title, date, timestamp, status, jogadores, duration,
//         winLimit, streakAction, draftMode
// helpers: bool get isLive => status == 'Em Andamento';
//          DateTime? get dateTime => DateTime.tryParse(timestamp ?? '');
```
- `fromJson`: `win_limit` → `winLimit`, `draft_mode` → `draftMode`, `streak_action` → `streakAction`.
- Defaults: `jogadores: 5`, `duration: 8`, `winLimit: 3`, `streakAction: 'split'`, `draftMode: false`, `status: 'Em Andamento'`.

**`Player`**
- `fromJson` usa mesma regra de `ensurePlayerIds` / `playerIdFromObject` (id vazio → fallback `name`).
- `manual_badges` → `List<PlayerBadge>`.

**`Match` / `MatchEvent`**
- Encapsular `eventPlayerId` logic no model (`playerId`, `assistId` com legado `player`/`assist`).
- `MatchPlayers` com `List<Player> red/white` e `Player? gkRed/gkWhite`.

**`PlayerStats`**
- Substituir o map retornado por `calculateGlobalStats`.
- Método `copyWith` / mutação controlada para agregação incremental se necessário.

### 1.4 Helpers de lista (opcional mas recomendado)
- `lib/models/json_parsers.dart`: `parseString`, `parseInt`, `parseBool`, `parseDateTime`, `asMapList`.
- Evita duplicar casts em cada `fromJson`.

### 1.5 Critérios de aceite Fase 1
- [ ] Pasta `lib/models/` com models P0 + P1.
- [ ] Nenhum model depende de Flutter (só Dart).
- [ ] `toJson()` produz as **mesmas chaves** lidas hoje pelo app.
- [ ] Round-trip mental: JSON prefs → `fromJson` → `toJson` ≈ original (campos conhecidos).

---

## Fase 2 — Null safety e desacoplamento (`lib/screens/`, `lib/utils/`)

### 2.1 Padrão de leitura prefs (aplicar em todos os loaders)

**Antes**
```dart
jsonDecode(prefs.getString(key)!)
```

**Depois**
```dart
final String? raw = prefs.getString(key);
if (raw == null || raw.isEmpty) return [];
final decoded = jsonDecode(raw);
// mapear com Model.fromJson
```

Arquivos com `getString(...)!` / decode inseguro:
- `lib/screens/sessions_screen.dart`
- `lib/utils/stats_calculator.dart`
- `lib/utils/site_data_generator.dart`
- demais screens que carregam `players_`, `match_history_`, `seasons_` (ao tocar nelas)

### 2.2 Substituir acesso a map em UI / utils

| Local | Problema | Correção |
|-------|----------|----------|
| `sessions_screen.dart` | `session!['title']`, `session!['jogadores']`, etc. | `Session?` + campos tipados; branch `if (session != null)` |
| `main.dart` | `group!['name']`, `group!['id']` | `Group?` tipado |
| `stats_calculator.dart` | `globalStats[pid]!['ratings']`, `(a as Map)['session_date']` | `PlayerStats`, `Match.sessionDate` |
| `site_data_generator.dart` | dezenas de `!` em events/stats | models + `?? 0` / early continue |
| `player_identity.dart` | opera em `Map` | overload/`Player` + manter bridge legado temporário |
| `match_dialogs.dart` | `Map player` + `player['name']` | `Player` |
| widgets `player_field_slot`, `player_card`, `waitlist_card`, `match_*` | `Map<String, dynamic>` | `Player` / `PlayerStats` |

### 2.3 Desacoplar utils do formato cru

1. **`player_identity.dart`**
   - Preferir APIs tipadas: `String playerIdOf(Player p)`, `List<Player> ensurePlayerIdsTyped(...)`.
   - Manter funções `dynamic` como thin wrappers deprecados até migrar call sites.

2. **`stats_calculator.dart`**
   - `Future<List<Match>> getAllGroupMatches(...)`.
   - `Map<String, PlayerStats> calculateGlobalStats(List<Match>)`.
   - Remover `(a as Map)` e `matchPlayerEvents[pid]!['g']! + 1` → contadores locais tipados ou classe `MatchEventTally`.

3. **`site_data_generator.dart`**
   - Reutilizar `getAllGroupMatches` / `calculateGlobalStats` tipados (reduzir duplicação com stats_calculator).
   - Onde ainda exportar JSON para o site, converter **no final** com `.toJson()`, não manter map o tempo todo.

4. **`match_dialogs.dart`**
   - Assinatura `showRemovePopup(context, Player player, VoidCallback onConfirm)`.

### 2.4 Screens — ordem de migração (baixo risco → alto)

1. `sessions_screen.dart` — `List<Session>` (junto com Fase 3).
2. `main.dart` — `List<Group>` (escopo `lib/`, arquivo na raiz de lib).
3. `players_screen.dart` — `List<Player>`.
4. `manage_seasons_screen.dart` — `List<Season>`.
5. `history_screen.dart` / `edit_match_screen.dart` — `Match`.
6. `stats_calculator` consumers: `ranking_screen`, `player_detail`, `player_comparison`, `group_ranking` — migrar **assinaturas** primeiro; UI interna pode continuar gradual.
7. `match_screen.dart` / `draft_screen.dart` — por último (maior superfície).

### 2.5 Regras de null-safety (checklist por PR)

- [ ] Proibido `prefs.getString(k)!` sem null-check.
- [ ] Proibido `map!['field']` em widgets; usar model ou `map['field']` com `??`.
- [ ] Lookups: `final v = map[id]; if (v == null) continue;` em vez de `map[id]!`.
- [ ] `DateTime.parse` → `DateTime.tryParse` + fallback.
- [ ] Tipos explícitos: sem `var` em listas/agregações novas.
- [ ] Funções de callback: `void Function()` / tipos concretos, não `Function` cru.

### 2.6 Critérios de aceite Fase 2
- [ ] `sessions_screen` + `stats_calculator` + `player_identity` + `match_dialogs` sem bang em maps de domínio.
- [ ] Loaders de prefs com guard de null/empty.
- [ ] Widgets em `lib/widgets/match/` e `lib/widgets/player/` aceitam models tipados (ou typedef temporário documentado).

---

## Fase 3 — Extrair UI de `sessions_screen.dart` → `lib/widgets/`

Arquivo atual: **637 linhas**, 4 responsabilidades no State:
1. Persistência load/save
2. `_showSessionDialog` (bottom sheet monolítico ~L56–431)
3. `_deleteSession` (AlertDialog ~L433–470)
4. `build` + card da lista (~L472–636)

Meta: screen orquestradora **< 200 linhas**.

### 3.1 Novos arquivos

```
lib/widgets/session/
  session_list_tile.dart      # card da ListView (Material/InkWell/ListTile/menu)
  session_form_sheet.dart     # bottom sheet criar/editar
  session_delete_dialog.dart  # confirmação de exclusão
```

(Alternativa aceitável: `lib/widgets/sessions/` — manter um único prefixo de pasta.)

### 3.2 Contratos sugeridos

**`SessionListTile`**
```dart
class SessionListTile extends StatelessWidget {
  final Session session;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  // UI: status live border, title, date, jogadores x jogadores, PopupMenu
}
```

**`SessionFormSheet`**
```dart
// showSessionFormSheet(
//   BuildContext context, {
//   Session? existing,
//   required void Function(Session result) onSubmit,
// })
// Contém: controllers, date picker, win limit, streak toggle, draft toggle
// Não acessa SharedPreferences — só devolve Session montada
```

**`SessionDeleteDialog`**
```dart
// Future<bool> showSessionDeleteDialog(BuildContext context);
// true se confirmou exclusão
```

### 3.3 `sessions_screen.dart` após extração

Responsabilidades restantes:
- `List<Session> sessions` + `isLoading`
- `_loadSessions` / `_saveSessions` usando `Session.fromJson` / `toJson`
- handlers: open → `TournamentDashboardScreen`, edit/create → sheet, delete → dialog
- `Scaffold` + `ListView.builder` + FAB

### 3.4 Passos de execução (ordem)

1. Criar `Session` model (Fase 1) e migrar estado da screen para `List<Session>`.
2. Extrair `session_list_tile.dart` e trocar o `itemBuilder`.
3. Extrair `session_delete_dialog.dart`.
4. Extrair `session_form_sheet.dart` (maior diff — mover StatefulBuilder + fields).
5. Remover bangs e maps residuais na screen.
6. Conferir `wc -l` da screen < 200.

### 3.5 Critérios de aceite Fase 3
- [ ] `lib/screens/sessions_screen.dart` < 200 linhas.
- [ ] Dialogs/sheets/cards em `lib/widgets/session/` (ou equivalente).
- [ ] Zero `Map<String, dynamic>` de sessão na UI da screen.
- [ ] Comportamento preservado: criar, editar, excluir, ordenar por timestamp desc, navegar ao dashboard, draft/win_limit/streak.

---

## Ordem global de execução

```
Fase 1.1–1.2  models P0 (Group, Session, Player)
     ↓
Fase 3        extrair widgets de sessions (depende de Session)
     ↓
Fase 2        null-safety em sessions + utils ligados a Session/Player
     ↓
Fase 1.2      models P1 (Match, MatchEvent, Season, PlayerStats)
     ↓
Fase 2        stats_calculator + site_data_generator + widgets match/player
     ↓
Fase 2.4      demais screens (incremental)
```

---

## Fora de escopo (não fazer neste plano)

- Refatorar por completo `match_screen.dart` / `ranking_screen.dart` / `player_detail.dart` (só adaptar às novas assinaturas quando necessário).
- Mudar schema de chaves no SharedPreferences ou migrar dados em massa.
- Alterar pastas fora de `lib/`.
- Renomear chaves JSON legadas (`jogadores` → `playersPerTeam` no storage) — apenas nomes Dart internos.

---

## Verificação

Após cada fase:
1. Analisar arquivos tocados (leitura + grep por `Map<String, dynamic>` e `!` restantes no caminho migrado).
2. Se o ambiente tiver Flutter SDK: `dart analyze lib/` (ou `flutter analyze lib/`).
3. Smoke manual: abrir grupo → listar peladas → criar/editar/excluir → abrir dashboard.

---

## Tracking rápido

- [ ] **F1** Models P0 em `lib/models/`
- [ ] **F1** Models P1 (Match, Event, Season, PlayerStats)
- [ ] **F3** `session_list_tile.dart`
- [ ] **F3** `session_form_sheet.dart`
- [ ] **F3** `session_delete_dialog.dart`
- [ ] **F3** `sessions_screen.dart` < 200 linhas + tipado
- [ ] **F2** prefs null-guards em sessions/utils
- [ ] **F2** `stats_calculator` / `player_identity` / `match_dialogs` tipados
- [ ] **F2** widgets `lib/widgets/match|player` tipados
)
