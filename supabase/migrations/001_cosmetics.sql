-- 001_cosmetics.sql — cosméticos do redesign (Bola de Ouro, efeitos novos, Craque do Mês com estrelas)
-- Rodar manualmente no SQL Editor do Supabase. Estratégia "expandir, depois contrair":
-- esta migração NÃO remove nada, então o app atual continua funcionando.

-- 1) Ampliar os valores permitidos de name_effect (hoje: gold, silver, bronze)
--    Confirme o nome da constraint antes (ex.: select conname from pg_constraint where conrelid = 'public.players'::regclass;)
alter table public.players drop constraint if exists players_name_effect_check;
alter table public.players
  add constraint players_name_effect_check
  check (name_effect is null or name_effect in ('diamond','gold','fire','silver','bronze'));

-- 2) Bola de Ouro (melhor da temporada)
alter table public.players
  add column if not exists golden_ball boolean not null default false;

-- 3) Craque do Mês com contador de estrelas (0 = sem; 1 a 6)
alter table public.players
  add column if not exists monthly_star_count integer not null default 0
  check (monthly_star_count between 0 and 6);

-- 4) Migrar quem já tinha o destaque mensal para 1 estrela
update public.players
   set monthly_star_count = 1
 where monthly_highlight = true and monthly_star_count = 0;

-- 5) (SÓ DEPOIS de o app novo estar em uso e o código não ler mais monthly_highlight)
-- alter table public.players drop column monthly_highlight;
