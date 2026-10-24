# CLAUDE.md — App do Fut

App Flutter de gestão de pelada de futsal: partidas ao vivo, escalação, estatísticas, ranking, avaliações e prêmios dos jogadores. Backend em Supabase (Postgres + Auth). O dono do projeto é o Enzo, que escreve em português do Brasil.

## Contexto de uso

- O grupo joga todo sábado. Em cada sábado há uma **session** com várias **matches** (times `red` e `white`). Quem ganha N partidas seguidas sai e volta para o fim da fila (ordem de chegada em `session_arrivals`).
- Existe ranking do dia, ranking da temporada (`seasons`), nota por jogador (`rating`) e histórico (`rating_history`).
- Prêmios:
  - **Craque do Mês**: moldura safira + estrelas cumulativas.
  - **Prêmios de temporada** (Bola de Ouro, Artilheiro, etc.): efeito no nome. Novos prêmios virão.

## Estrutura

```
lib/
  config/        configuração (ambiente, Supabase)
  constants/     constantes e listas fixas (efeitos, textos)
  models/        modelos de dados
  repositories/  acesso a dados (Supabase)
  screens/       telas
  services/      serviços (sync, lógica externa)
  test/          testes
  theme/         tema, cores, tipografia
  utils/         helpers
  widgets/       componentes reutilizáveis (subpastas por área)
  main.dart
```

## Banco de dados (Supabase, schema `public`)

Tabelas principais: `groups`, `players`, `group_members`, `seasons`, `sessions`, `matches`, `match_lineups`, `match_events`, `rating_history`, `session_arrivals`, `custom_badges`, `group_join_requests`, `group_action_logs`, `sync_data`.

Campos de cosméticos em `players` (não alterar o schema sem pedir):

- `name_effect`: `NULL | 'diamond' | 'gold' | 'fire' | 'silver' | 'bronze'` (constraint no banco)
- `monthly_highlight` (bool): Craque do Mês ativo
- `monthly_star_count` (int, 0 a 6): estrelas acumuladas
- `golden_ball` (bool): Bola de Ouro
- `manual_badges` (jsonb): badges manuais

`match_events.event_type`: `goal | own_goal | yellow_card | red_card`. Assistências vêm de `assist_player_id`.

## Regras de design dos cosméticos

- Cada camada visual tem uma função: **moldura** = conquista de destaque (safira = Craque do Mês, dourada = Bola de Ouro); **efeito no nome** = prêmio da temporada; **estrelas** = histórico acumulado.
- Não repetir a mesma informação em dois elementos (nada de ícone + cor + moldura dizendo a mesma coisa).
- Ícones de medalha/troféu/fogo/diamante só na tela de edição, como legenda. Nas telas de jogo e ranking, só o efeito no nome.
- Cards do campo são pequenos: priorizar número, foto, nome e nota. Evitar truncar nomes.
- Um único componente renderiza nome com efeito. Não duplicar estilo de efeito por tela.
- A lista de efeitos (valor, rótulo, ícone, descrição, estilo) fica em um só lugar, em `constants/`.

## Convenções

- Idioma da UI e dos textos: português do Brasil. Código, nomes de classes e variáveis em inglês, seguindo o que já existe no projeto.
- Antes de criar um widget novo, procurar em `lib/widgets/` se já existe algo parecido.
- Acesso ao Supabase só via `repositories/` ou `services/`, nunca direto em telas.
- Cores e estilos vêm de `theme/`, sem valores soltos nas telas.
- Mudanças pequenas e focadas, com commits separados por tarefa.
- Não mudar schema do banco, nem fazer migrações, sem confirmar com o Enzo.

## Comandos

```
flutter pub get
flutter analyze
flutter test
flutter run
```

Rodar `flutter analyze` e `flutter test` antes de dar uma tarefa como concluída.

## Tarefas em andamento

- Simplificação dos cosméticos: ver `docs/app-do-fut-cosmeticos.md`.

## Em caso de dúvida

Se o código contradisser a documentação, seguir o código e avisar. Se uma decisão de produto não estiver clara (ex.: o que significa um elemento visual), perguntar ao Enzo antes de remover ou mudar.
