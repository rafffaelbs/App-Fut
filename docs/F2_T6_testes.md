# F2_T6_testes.md — roteiro de testes da T6 (rodar depois do `F2_T6_share_link.sql`)

> O SQL foi validado só quanto à **sintaxe** (não foi executado em um Postgres). Por isso estes testes são obrigatórios antes de o site depender dele.
> Faça nesta ordem. Se qualquer teste falhar, pare e me mande o resultado. Para desfazer tudo, use o bloco "DESFAZER" no fim do `.sql`.

## 0. Antes de rodar o SQL (uma vez)

1. Backup do banco (Supabase → Database → Backups).
2. Conferir a regra de admin que vamos reaproveitar. Rode e me mande o resultado:
   ```sql
   select pg_get_functiondef('public.is_group_admin(text)'::regprocedure);
   ```
3. Achado de segurança (não mexe em nada, só consulta): a política `players_select` libera leitura a qualquer usuário logado. Veja se a coluna `email` está protegida:
   ```sql
   select has_column_privilege('authenticated', 'public.players', 'email', 'select') as authenticated_le_email,
          has_column_privilege('anon',          'public.players', 'email', 'select') as anon_le_email;
   ```

## 1. Rodar o `F2_T6_share_link.sql` inteiro

Deve terminar com `Success. No rows returned`. Se der erro, nada foi criado (é uma transação).

## 2. Testes estruturais (SQL Editor, como `postgres`)

```sql
-- a) anon e authenticated NÃO podem ler a tabela de tokens (esperado: false, false)
select has_table_privilege('anon', 'public.group_share_tokens', 'select')          as anon_le,
       has_table_privilege('authenticated', 'public.group_share_tokens', 'select') as auth_le;

-- b) quem pode executar cada função (esperado: veja a coluna "esperado")
select p.proname,
       has_function_privilege('anon', p.oid, 'execute')          as anon,
       has_function_privilege('authenticated', p.oid, 'execute') as authenticated,
       p.prosecdef                                                as security_definer
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in ('get_group_snapshot','get_group_share_token',
                    'rotate_group_share_token','revoke_group_share_token','_new_share_token')
order by 1;
-- esperado:
--   _new_share_token          anon=false authenticated=false
--   get_group_snapshot        anon=TRUE  authenticated=TRUE
--   get_group_share_token     anon=false authenticated=TRUE
--   rotate_group_share_token  anon=false authenticated=TRUE
--   revoke_group_share_token  anon=false authenticated=TRUE
--   (todas security_definer = true)

-- c) RLS ligado na tabela nova (esperado: true)
select relrowsecurity from pg_class where oid = 'public.group_share_tokens'::regclass;
```

## 3. Criar o link do Fut do INF

```sql
select id, name from public.groups;   -- confira o id do "Fut do INF"
```
```sql
insert into public.group_share_tokens (group_id, token)
values ('COLE_O_ID_DO_GRUPO', public._new_share_token())
returning group_id, token;
```
Guarde o `token` (ele é a "senha" do site). O link será `https://<site>/#/g/<token>`.

## 4. Testes pela API como visitante (`anon`) — no terminal

Troque `URL` e `ANON` pelos valores do seu projeto (Project Settings → API; a chave `anon`, nunca a `service_role`).

```bash
URL="https://SEU-PROJETO.supabase.co"
ANON="SUA_CHAVE_ANON"
H=(-H "apikey: $ANON" -H "Authorization: Bearer $ANON")

# a) leitura direta das tabelas: esperado [] ou erro de permissão (NUNCA dados)
for t in players groups matches match_events match_lineups seasons sessions group_members group_share_tokens; do
  echo "== $t"; curl -s "$URL/rest/v1/$t?select=*&limit=1" "${H[@]}"; echo
done

# b) token inválido: esperado erro com "invalid_link"
curl -s -X POST "$URL/rest/v1/rpc/get_group_snapshot" "${H[@]}" \
  -H "Content-Type: application/json" -d '{"p_token":"abc"}'; echo

# c) token válido: esperado JSON do grupo
TOKEN="COLE_O_TOKEN"
curl -s -X POST "$URL/rest/v1/rpc/get_group_snapshot" "${H[@]}" \
  -H "Content-Type: application/json" -d "{\"p_token\":\"$TOKEN\"}" > /tmp/snapshot.json
python3 -c "
import json; d=json.load(open('/tmp/snapshot.json'))
print({k:(len(v) if isinstance(v,list) else 'obj') for k,v in d.items()})
print('tamanho KB:', round(len(json.dumps(d))/1024,1))"

# d) vazamento: nenhuma destas palavras pode aparecer (esperado: 0 em todas)
for w in email creator_id invite_code sync_code goal_sound_url user_id '@'; do
  printf "%s: " "$w"; grep -c -- "$w" /tmp/snapshot.json
done

# e) funções de admin como visitante: esperado erro de permissão (não existe para anon)
curl -s -X POST "$URL/rest/v1/rpc/rotate_group_share_token" "${H[@]}" \
  -H "Content-Type: application/json" -d '{"p_group_id":"COLE_O_ID_DO_GRUPO"}'; echo
```

Me mande: a saída do item (a), o resumo do item (c) (contagens e tamanho) e os números do item (d).

## 5. Funções de admin (SQL Editor, simulando você logado)

Primeiro pegue o seu `id` de usuário: `select id, email from auth.users;`. Tudo dentro de uma transação que termina em `rollback`, para **não** mudar o token de verdade.

```sql
begin;
set local role authenticated;
select set_config('request.jwt.claims',
  json_build_object('sub','COLE_SEU_USER_UUID','role','authenticated')::text, true);

select public.get_group_share_token('COLE_O_ID_DO_GRUPO') as token_atual;   -- esperado: o token do passo 3
select public.rotate_group_share_token('COLE_O_ID_DO_GRUPO') as token_novo; -- esperado: outro token
rollback;
```

Teste negativo (usuário que NÃO é admin; esperado `Acesso negado: somente administradores.`):

```sql
begin;
set local role authenticated;
select set_config('request.jwt.claims',
  json_build_object('sub', gen_random_uuid()::text,'role','authenticated')::text, true);
select public.get_group_share_token('COLE_O_ID_DO_GRUPO');
rollback;
```

## 6. Conferir que o app não foi afetado

Abrir o app pessoal no celular: grupos, ranking, estatísticas e uma partida continuam normais (a T6 não altera nada que o app usa).
