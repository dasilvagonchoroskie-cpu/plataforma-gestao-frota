-- Apoio ao painel do gestor: pedidos de entrada com nome e CPF, e quem lê
-- os ajustes.
begin;
\ir apoio/fixtures.psql

select plan(9);

-- A conta D (sem vínculo) pede entrada na empresa X.
select pg_temp.como(pg_temp.fx('u_d'), format('select public.pedir_entrada(%L)',
  (select codigo_entrada from public.empresas where id = pg_temp.fx('empresa_x'))));

select is(
  pg_temp.como(pg_temp.fx('u_gestor_x'), $q$
    select jsonb_build_object('nome', p ->> 'nome', 'cpf', p ->> 'cpf', 'status', p ->> 'status')
    from jsonb_array_elements(public.pedidos_entrada_da_empresa()) p where p ->> 'status' = 'pendente' $q$),
  '{"nome": "Sem Vinculo", "cpf": "15350946056", "status": "pendente"}'::jsonb,
  'o gestor vê nome e CPF de quem pediu entrada');

select is(
  pg_temp.como(pg_temp.fx('u_dono_x'), $q$
    select to_jsonb(count(*)) from jsonb_array_elements(public.pedidos_entrada_da_empresa()) p
    where p ->> 'status' = 'aprovado' $q$),
  '2'::jsonb,
  'o dono vê os pedidos aprovados há pouco (motoristas A e B)');

select is(
  pg_temp.como(pg_temp.fx('u_dono_y'), $q$
    select to_jsonb(count(*)) from jsonb_array_elements(public.pedidos_entrada_da_empresa()) p
    where p ->> 'nome' in ('Sem Vinculo', 'Motorista A', 'Motorista B') $q$),
  '0'::jsonb,
  'a empresa Y não vê os pedidos da empresa X');

select is(pg_temp.erro_como(pg_temp.fx('u_a'), 'select public.pedidos_entrada_da_empresa()'), '42501',
  'motorista não lista pedidos de entrada');

select is(pg_temp.erro_como(pg_temp.fx('u_d'), 'select public.pedidos_entrada_da_empresa()'), '42501',
  'conta sem vínculo não lista pedidos de entrada');

-- Leitura dos ajustes: cada um vê só o que pode.
select pg_temp.como(pg_temp.fx('u_gestor_x'), format($q$
  insert into public.ajustes_gestor (id, empresa_id, tabela_alvo, registro_id, campo, valor_novo, motivo, autor_id)
  values (gen_random_uuid(), public.empresa_do_usuario(), 'fretes', %L, 'pedagio_centavos', '15000',
    'Recibo do pedágio', auth.uid())
  returning '{}'::jsonb $q$, pg_temp.fx('frete_a')));

select is(pg_temp.como(pg_temp.fx('u_a'), 'select to_jsonb(count(*)) from public.ajustes_gestor'), '1'::jsonb,
  'o motorista A lê o ajuste do próprio frete');
select is(pg_temp.como(pg_temp.fx('u_b'), 'select to_jsonb(count(*)) from public.ajustes_gestor'), '0'::jsonb,
  'o motorista B não lê ajuste do frete de A');
select is(pg_temp.como(pg_temp.fx('u_dono_x'), 'select to_jsonb(count(*)) from public.ajustes_gestor'), '1'::jsonb,
  'o dono lê os ajustes da empresa');
select is(pg_temp.como(pg_temp.fx('u_dono_y'), 'select to_jsonb(count(*)) from public.ajustes_gestor'), '0'::jsonb,
  'outra empresa não lê os ajustes');

select * from finish();
rollback;
