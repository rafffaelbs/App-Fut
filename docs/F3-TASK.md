# F3-TASK.md — Fase 3: app público offline, 1 grupo (⏳ detalhar depois da Fase 2)

> Ainda sem prompts. Eles serão escritos no padrão da F2-TASK.md quando a Fase 2 estiver validada.

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

## FASE 3 — App público offline (1 grupo)  ·  *detalhar depois do gate*

| # | Tarefa | Quem |
|---|---|---|
| T8 | Schema drift + `schemaVersion` + migrações | **CLAUDE** |
| T9 | Repositórios locais simples (CRUD) seguindo o modelo que eu entregar | AG |
| T10 | Repositórios locais com transação (`createGroup`, `saveFullMatch`, `updateFullMatch`, `updatePartialMatch`, `deleteMatch`, `savePendingMatch`, `replaceArrivals`, `createGhostPlayer`) + `LocalMatchOutbox` (grava direto, `pending` sempre 0) | **CLAUDE** |
| T11 | Exportar/importar `.db` (`VACUUM INTO`, `integrity_check`, backup antes de importar) | **CLAUDE** |
| T12 | `bootstrap_public.dart`, `main_public.dart`, auth local fixo, grupo e temporada criados no primeiro uso | AG |
| T13 | Tema neutro, nome, ícone, flags do public desligando recursos do personal | AG |
| T14 | Implementar no SQLite: tabela `custom_badges`, `MatchHistoryStore` derivado das tabelas (convertendo para o formato da súmula local), e limpar `players_*`/`cache:*` depois de importar um `.db` (decisões na seção 10 do ARCHITECTURE) | **CLAUDE** |
| T15 | Build Android do app público (assinatura, ícone, nome) | AG |
