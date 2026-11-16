# DIAGNOSTICO_AG_2026-11-15.md: diagnóstico do AG e verificação

**Origem:** o AG leu os docs, rodou `flutter analyze` e `flutter test` e olhou trechos do código. A verificação foi feita pelo Claude Code em sessão nova, **somente leitura**, e os números abaixo foram reconferidos na tarefa C4 (15/11/2026). Regra: o código vale; o que não foi verificado fica como "a verificar".

| ID | Achado | Resultado | Tarefa |
|---|---|---|---|
| A1 | Preview "Entra:" do diálogo de fim de partida sugere quem está saindo | **CONFIRMADO.** `_calculateEnteringPlayers` (`match_screen.dart:3682-3702`) só pula quem fica em campo e quem desistiu. O fluxo real (`_processMatchExit`, 4119-4180) está certo. Possível mesmo defeito em `enteringForSplit` (3611-3614): **a verificar** | C1 |
| A2 | Nota difere entre Elenco e carta | **CONFIRMADO.** Elenco usa a história inteira (`players_screen.dart:108-132`, `player_comparison_screen.dart:94-95`, `group_bootstrap.dart:193`); a carta usava o período escolhido (`player_detail.dart:340, 3871`). Decisão do Enzo: história inteira. **Já corrigido e mesclado** (`fix/rating-all-history`, merge `027fb03`) | C2 (feita) |
| A3 | Envio ao site antigo "a cada 90 s" | **CONFIRMADO com correção:** `_scheduleSiteSync` é um Timer de uso único de 90 s, rearmado após cada partida finalizada (`match_screen.dart:3713-3725`), não um ciclo. É a T7b (por último). Dependências: `_siteSyncTimer` (`match_screen.dart:70`), `dispose` (137-140), `_triggerBackgroundSync` (4301), `_recordSyncHistory` (4318), `hasSiteSync` (`app_features.dart:40, 66`), `SiteSyncService`, `SupabaseSiteSyncService`, `my_sync_code`, `SiteDataGenerator`, `sync_data`, `AppServices.siteSync` (`app_services.dart:73`), `bootstrap_personal.dart:44, 71` (criação e registro; a referência `bootstrap_personal:161` do relato original não bate com o código atual; o `:161` existe em `bootstrap_web.dart`, que passa `siteSync: null`), `admin_debug_screen.dart:36-40` | T7b |
| A4 | Botões de alteração aparecem para quem não é admin | **CONFIRMADO em duas telas:** menu ⋮ da lista de grupos (`main_personal.dart:834-860`, só `isReadOnly`; o repositório exige admin em `groups_repository.dart:320, 349`) e ações do histórico (`history_screen.dart:260-262` lixeira, 314 toque longo, 326-328 lápis; só `isReadOnly`, sem checar admin). O lápis pede a senha fixa `"0101"` (`history_screen.dart:213`; o AG citou a linha 212) | C3 (C3a, C3b, C3c) |
| A5 | RLS de `players` | Já existia (**S1**), sem mudança. A S1 trata da **leitura** de `players` (policy `players_select`, que expõe e-mail). A edição de colunas da própria linha é a DUVIDAS #28 | S1 |
| A6 | `match_screen.dart` e `player_detail.dart` grandes demais | Backlog: **4.330** e **4.385** linhas | backlog |
| A7 | Avisos do `flutter analyze` | Backlog: 263 itens, **14 `warning`**, resto `info`, 0 erros | backlog |
| A8 | Fase 3 | Já existia, sem mudança | Fase 3 |
| A9 | Histórico da nota da comunidade | Já existia (BACKLOG §2), sem mudança | backlog |

**Suíte real (rodada em 15/11/2026 na branch `docs/atualizacao-2026-11-15`, partindo da `main` em `027fb03`): 322 testes, todos passando** (`flutter test`). Os docs diziam 320; os 2 testes a mais vieram da C2.

**Isolamento do Supabase:** 16 arquivos importam `supabase_flutter` (os docs diziam 14), todos dentro de `lib/data/supabase/` (15 na raiz + `readonly/snapshot_source.dart`). A regra 2 continua válida.
