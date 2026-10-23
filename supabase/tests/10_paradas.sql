-- Registro de paradas: desligado por padrão, só o dono liga, limite da empresa,
-- motivos no catálogo, envio sem internet e cada um vê só o que é seu.
begin;
\ir apoio/fixtures.psql

select plan(24);

create or replace function pg_temp.enviar(p_uid uuid, p_itens jsonb)
returns jsonb language sql as $$
  select pg_temp.como(p_uid, format('select public.sincronizar_lote(%L)', jsonb_build_object('itens', p_itens)))
$$;
create or replace function pg_temp.parada(p_id uuid, p_extra jsonb default '{}')
returns jsonb language sql as $$
  select jsonb_build_object('tabela', 'paradas', 'dados', jsonb_build_object(
    'id', p_id, 'caminhao_id', pg_temp.fx('cam_x1'), 'motivo', 'refeicao', 'inicio_em', '2026-10-10T15:00:00Z') || p_extra)
$$;
create or replace function pg_temp.qtd(j jsonb, k text) returns int language sql as $$
  select jsonb_array_length(j -> k)
$$;

insert into fx values
  ('par_1', '60000000-0000-4000-8000-000000000001'),
  ('par_2', '60000000-0000-4000-8000-000000000002'),
  ('par_3', '60000000-0000-4000-8000-000000000003');

-- ------------------------------------------------------ configuração

select is((select paradas_ativas::text || ':' || limite_sem_descanso_minutos from public.empresas
  where id = pg_temp.fx('empresa_x')), 'false:330', 'paradas desligadas por padrão; limite padrão de 5h30');
select is(pg_temp.como(pg_temp.fx('u_a'), 'select public.situacao_acesso()') -> 'empresa' -> 'motivos_parada', '[]'::jsonb,
  'desligado: o app do motorista não recebe os motivos (não mostra a aba)');
select is(pg_temp.como(pg_temp.fx('u_gestor_x'), $q$with t as (
  update public.empresas set paradas_ativas = true where id = public.empresa_do_usuario() returning id)
  select coalesce(jsonb_agg(id), '[]') from t$q$),
  '[]'::jsonb, 'o gestor não liga as paradas (só o dono)');
select is(pg_temp.erro_como(pg_temp.fx('u_dono_x'), $q$update public.empresas set limite_sem_descanso_minutos = 10
  where id = public.empresa_do_usuario()$q$), '23514', 'limite fora do razoável é recusado');
select pg_temp.como(pg_temp.fx('u_dono_x'), $q$with t as (
  update public.empresas set paradas_ativas = true, limite_sem_descanso_minutos = 300
  where id = public.empresa_do_usuario() returning id) select coalesce(jsonb_agg(id), '[]') from t$q$);
select is((select paradas_ativas::text || ':' || limite_sem_descanso_minutos from public.empresas
  where id = pg_temp.fx('empresa_x')), 'true:300', 'o dono liga e muda o limite');
select is(pg_temp.como(pg_temp.fx('u_a'), 'select public.situacao_acesso()') -> 'empresa' ->> 'limite_sem_descanso_minutos',
  '300', 'o app do motorista recebe o limite');
select is((select string_agg(x ->> 'codigo', ',') from jsonb_array_elements(
  pg_temp.como(pg_temp.fx('u_a'), 'select public.situacao_acesso()') -> 'empresa' -> 'motivos_parada') x
  where (x ->> 'conta_como_descanso')::boolean), 'refeicao,descanso,pernoite',
  'só refeição, descanso e pernoite contam como descanso (no catálogo, não no código)');
select is(jsonb_array_length(pg_temp.como(pg_temp.fx('u_a'), 'select public.situacao_acesso()') -> 'empresa' -> 'motivos_parada'),
  10, 'os dez motivos chegam ao app');
select is(pg_temp.como(pg_temp.fx('u_dono_y'), 'select public.situacao_acesso()') -> 'empresa' ->> 'paradas_ativas',
  'false', 'a outra empresa continua desligada');
select is(pg_temp.erro_como(pg_temp.fx('u_a'), $q$insert into public.motivos_parada (codigo, nome) values ('xx', 'Xx')$q$),
  '42501', 'ninguém do app mexe nos motivos');

-- -------------------------------------------------------- envio do celular

create temp table r1 as select pg_temp.enviar(pg_temp.fx('u_a'), jsonb_build_array(
  pg_temp.parada(pg_temp.fx('par_1')),
  pg_temp.parada(pg_temp.fx('par_2'), '{"motivo": "outro", "descricao": "Esperando a balança", "inicio_em": "2026-10-10T18:00:00Z"}')
)) as r;
grant select on r1 to authenticated;
select is((select pg_temp.qtd(r, 'aceitos') || '/' || pg_temp.qtd(r, 'rejeitados') from r1), '2/0',
  'o motorista envia as paradas feitas sem internet');
select is((select coalesce(fim_em::text, 'aberta') || ':' || ajustado from public.paradas where id = pg_temp.fx('par_1')),
  'aberta:false', 'a parada fica aberta até retomar');
select is(pg_temp.qtd(pg_temp.enviar(pg_temp.fx('u_a'), jsonb_build_array(
  pg_temp.parada(pg_temp.fx('par_1'), '{"fim_em": "2026-10-10T16:10:00Z"}'))), 'aceitos'), 1, 'retomar a viagem fecha a parada');
select is(pg_temp.qtd(pg_temp.enviar(pg_temp.fx('u_a'), jsonb_build_array(
  pg_temp.parada(pg_temp.fx('par_2'), '{"motivo": "outro", "descricao": "Esperando a balança", "inicio_em": "2026-10-10T18:00:00Z", "fim_em": "2026-10-10T19:00:00Z", "ajustado": true}'))),
  'aceitos'), 1, 'esqueceu de retomar: informa o horário');
select is((select (fim_em - inicio_em)::text || ':' || ajustado || ':' || descricao from public.paradas
  where id = pg_temp.fx('par_2')), '01:00:00:true:Esperando a balança', 'e a parada fica marcada como ajustada');
select is(pg_temp.qtd(pg_temp.enviar(pg_temp.fx('u_a'), jsonb_build_array(
  pg_temp.parada(pg_temp.fx('par_3'), '{"fim_em": "2026-10-10T14:00:00Z"}'))), 'rejeitados'), 1,
  'retomar antes de parar é recusado');
select is(pg_temp.qtd(pg_temp.enviar(pg_temp.fx('u_a'), jsonb_build_array(
  pg_temp.parada(pg_temp.fx('par_3'), '{"motivo": "cochilo"}'))), 'rejeitados'), 1, 'motivo fora do catálogo é recusado');
select is(pg_temp.qtd(pg_temp.enviar(pg_temp.fx('u_b'), jsonb_build_array(
  pg_temp.parada(pg_temp.fx('par_1'), '{"fim_em": "2026-10-10T17:00:00Z"}'))), 'rejeitados'), 1,
  'outro motorista não mexe na parada');
select is((select fim_em from public.paradas where id = pg_temp.fx('par_1')), '2026-10-10T16:10:00Z'::timestamptz,
  'e a parada continua como estava');

-- ---------------------------------------------------------- quem vê o quê

select is(pg_temp.como(pg_temp.fx('u_b'), 'select to_jsonb(count(*)) from public.paradas')::text, '0',
  'outro motorista não vê as paradas');
select is(pg_temp.como(pg_temp.fx('u_gestor_x'), 'select to_jsonb(count(*)) from public.paradas')::text, '2',
  'o gestor vê as paradas da empresa');
select is(pg_temp.como(pg_temp.fx('u_dono_y'), 'select to_jsonb(count(*)) from public.paradas')::text, '0',
  'a outra empresa não vê');
select is(jsonb_array_length(pg_temp.como(pg_temp.fx('u_a'), 'select public.baixar_alteracoes()') -> 'paradas'), 2,
  'celular novo baixa as paradas');
select ok((select count(*) from public.auditoria where tabela = 'paradas' and registro_id = pg_temp.fx('par_2')) >= 2,
  'cada mudança da parada fica na auditoria');

select * from finish();
rollback;
