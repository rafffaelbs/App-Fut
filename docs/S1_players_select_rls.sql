-- =====================================================================
-- S1_players_select_rls.sql  ·  Segurança S1  ·  RASCUNHO (não rodar ainda)
-- =====================================================================
-- Problema: a policy players_select é (auth.uid() IS NOT NULL): qualquer usuário
-- logado lê TODAS as linhas de `players` (inclui a coluna email) de TODOS os grupos.
--
-- Correção (estágio 1): cada usuário só lê jogadores que:
--   (a) ele mesmo criou (creator_id = auth.uid()), OU
--   (b) são membros de um grupo do qual ele é membro, OU
--   (c) aparecem em escalações/eventos de partidas de um grupo do qual ele é membro
--       (inclui quem saiu do elenco mas tem histórico: evita "Desconhecido").
--
-- EXCEÇÃO à regra de ouro 5: SUBSTITUI uma policy existente (players_select) e cria
-- 1 função nova. Nenhum dado, tabela ou coluna é alterado. Reversível (ver fim).
--
-- Só rodar depois de: (1) backup com dados, (2) consultas do Passo 0 do S1-TASK.md,
-- (3) investigação do Passo 1 concluída, (4) ajustes necessários neste arquivo.
-- =====================================================================

begin;

-- Função auxiliar SECURITY DEFINER: lê as tabelas sem passar pelo RLS (evita recursão
-- de policy) e reaproveita is_group_member(), a mesma regra que o RLS do app já usa.
-- Devolve false para visitante (auth.uid() nulo).
create or replace function public.can_read_player(pid text)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select auth.uid() is not null and (
    exists (
      select 1 from public.group_members gm
      where gm.player_id = pid
        and public.is_group_member(gm.group_id)
    )
    or exists (
      select 1
      from public.match_lineups l
      join public.matches m on m.id = l.match_id
      where l.player_id = pid
        and public.is_group_member(m.group_id)
    )
    or exists (
      select 1
      from public.match_events e
      join public.matches m on m.id = e.match_id
      where (e.player_id = pid or e.assist_player_id = pid)
        and public.is_group_member(m.group_id)
    )
  );
$$;

-- anon também precisa de EXECUTE, senão a policy dá erro (em vez de lista vazia)
-- quando um visitante consulta players. Para ele a função devolve false.
revoke all on function public.can_read_player(text) from public;
grant execute on function public.can_read_player(text) to anon, authenticated;

-- Substitui a policy frouxa
drop policy if exists players_select on public.players;

create policy players_select on public.players
  for select
  to public
  using (creator_id = auth.uid() or public.can_read_player(id));

commit;

-- =====================================================================
-- DESFAZER (volta exatamente ao comportamento anterior):
--
--   begin;
--   drop policy if exists players_select on public.players;
--   create policy players_select on public.players
--     for select to public using (auth.uid() is not null);
--   drop function if exists public.can_read_player(text);
--   commit;
-- =====================================================================
