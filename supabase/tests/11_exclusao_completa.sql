-- Exclusão completa (aprovada pelo Evandro em 23/10/2026): excluir motorista e
-- empresa apaga também viagens, acertos, paradas e as modalidades da empresa;
-- antes, o dono baixa todos os dados (mesmo com o acesso encerrado).
begin;
\ir apoio/fixtures.psql

select plan(19);

create or replace function pg_temp.enviar(p_uid uuid, p_itens jsonb)
returns jsonb language sql as $$
  select pg_temp.como(p_uid, format('select public.sincronizar_lote(%L)', jsonb_build_object('itens', p_itens)))
$$;

insert into fx values
  ('viagem_b', '70000000-0000-4000-8000-000000000001'),
  ('acerto_b', '70000000-0000-4000-8000-000000000002'),
  ('parada_b', '70000000-0000-4000-8000-000000000003'),
  ('parada_a', '70000000-0000-4000-8000-000000000004');

-- O motorista B vira Baú, faz uma viagem e registra uma parada; o gestor fecha um acerto.
select pg_temp.como(pg_temp.fx('u_dono_x'), $q$select public.salvar_modalidade_empresa('bau', true)$q$);
select pg_temp.como(pg_temp.fx('u_dono_x'), format('select public.definir_modalidade_motorista(%L, %L)',
  pg_temp.fx('mot_b'), 'bau'));
select pg_temp.como(pg_temp.fx('u_dono_x'), $q$with t as (
  update public.empresas set paradas_ativas = true where id = public.empresa_do_usuario() returning id)
  select coalesce(jsonb_agg(id), '[]') from t$q$);
select pg_temp.enviar(pg_temp.fx('u_b'), jsonb_build_array(
  jsonb_build_object('tabela', 'viagens', 'dados', jsonb_build_object('id', pg_temp.fx('viagem_b'),
    'caminhao_id', pg_temp.fx('cam_x2'), 'modalidade', 'bau', 'placa_carreta', 'ABC1D23', 'engate_local', 'Cajamar',
    'engate_em', '2026-10-06T10:00:00Z', 'observacao', '')),
  jsonb_build_object('tabela', 'paradas', 'dados', jsonb_build_object('id', pg_temp.fx('parada_b'),
    'caminhao_id', pg_temp.fx('cam_x2'), 'motivo', 'refeicao', 'inicio_em', '2026-10-06T15:00:00Z',
    'fim_em', '2026-10-06T16:00:00Z'))));
select pg_temp.enviar(pg_temp.fx('u_a'), jsonb_build_array(
  jsonb_build_object('tabela', 'paradas', 'dados', jsonb_build_object('id', pg_temp.fx('parada_a'),
    'motivo', 'cafe', 'inicio_em', '2026-10-06T09:00:00Z', 'fim_em', '2026-10-06T09:10:00Z'))));
select pg_temp.como(pg_temp.fx('u_gestor_x'), format(
  'select public.fechar_acerto(%L, %L, %L, %L, 150000, %L, null)',
  pg_temp.fx('acerto_b'), pg_temp.fx('mot_b'), '2026-10-01', '2026-10-15', '[]'));

select is((select count(*)::int from public.viagens where motorista_id = pg_temp.fx('mot_b'))
  + (select count(*)::int from public.paradas where motorista_id = pg_temp.fx('mot_b'))
  + (select count(*)::int from public.acertos where motorista_id = pg_temp.fx('mot_b')), 3,
  'o motorista B tem viagem, parada e acerto');

-- ----------------------------------------------- todos os dados para o PDF

create temp table exp as select pg_temp.como(pg_temp.fx('u_dono_x'), 'select public.exportar_dados_empresa()') as j;
grant select on exp to authenticated;
select is((select jsonb_array_length(j -> 'motoristas') from exp), 2, 'o dono baixa os motoristas da empresa');
select is((select jsonb_array_length(j -> 'paradas') || ':' || jsonb_array_length(j -> 'viagens') || ':' ||
  jsonb_array_length(j -> 'acertos') || ':' || jsonb_array_length(j -> 'fretes_efetivos') from exp), '2:1:1:2',
  'paradas, viagens, acertos e fretes vão no arquivo');
select is((select count(*)::int from jsonb_array_elements((select j -> 'fretes_efetivos' from exp)) f
  where (f ->> 'empresa_id')::uuid <> pg_temp.fx('empresa_x')), 0, 'nada de outra empresa no arquivo');
select is((select jsonb_array_length(j -> 'motivos_parada') from exp), 10, 'os nomes dos motivos vão junto');
select is(pg_temp.erro_como(pg_temp.fx('u_gestor_x'), 'select public.exportar_dados_empresa()'), '42501',
  'o gestor não usa a exportação completa (só o dono)');
select is(pg_temp.erro_como(pg_temp.fx('u_a'), 'select public.exportar_dados_empresa()'), '42501',
  'o motorista não baixa os dados da empresa');
select is(pg_temp.erro_como(pg_temp.fx('u_d'), 'select public.exportar_dados_empresa()'), '42501',
  'quem não tem empresa não baixa nada');
select is(jsonb_array_length(pg_temp.como(pg_temp.fx('u_dono_y'), 'select public.exportar_dados_empresa()') -> 'motoristas'),
  1, 'o dono da outra empresa só recebe os dados dela');

-- --------------------------------------------- exclusão do motorista

select is(pg_temp.como(pg_temp.fx('u_gestor_x'), format('select public.excluir_motorista(%L)', pg_temp.fx('mot_b'))) ->> 'ok',
  'true', 'excluir motorista com viagem, acerto e parada funciona');
select is((select count(*)::int from public.viagens where motorista_id = pg_temp.fx('mot_b'))
  + (select count(*)::int from public.acertos where motorista_id = pg_temp.fx('mot_b'))
  + (select count(*)::int from public.paradas where motorista_id = pg_temp.fx('mot_b')), 0,
  'as viagens, os acertos e as paradas dele vão junto');
select is((select count(*)::int from public.auditoria
  where registro_id in (pg_temp.fx('viagem_b'), pg_temp.fx('acerto_b'), pg_temp.fx('parada_b'))), 0,
  'e a auditoria desses registros também');
select is((select count(*)::int from public.paradas where id = pg_temp.fx('parada_a')), 1,
  'as paradas do outro motorista ficam');

-- ----------------------------- empresa com acesso encerrado: dono ainda baixa

select public.bloquear_empresa(pg_temp.fx('empresa_x'), 'Teste encerrado.', 30);
select is(pg_temp.como(pg_temp.fx('u_gestor_x'), 'select to_jsonb(count(*)) from public.paradas')::text, '0',
  'com o acesso encerrado, o painel não vê mais nada');
select is(jsonb_array_length(pg_temp.como(pg_temp.fx('u_dono_x'), 'select public.exportar_dados_empresa()') -> 'paradas'),
  1, 'mas o dono ainda baixa todos os dados para o PDF');

-- ------------------------------------------------- exclusão da empresa

select is(pg_temp.como(pg_temp.fx('u_dono_x'), $q$select public.excluir_minha_empresa('Transportes X')$q$) ->> 'ok',
  'true', 'o dono exclui a empresa com paradas e modalidades');
select is((select count(*)::int from public.paradas where empresa_id = pg_temp.fx('empresa_x'))
  + (select count(*)::int from public.empresas_modalidades where empresa_id = pg_temp.fx('empresa_x'))
  + (select count(*)::int from public.fretes where empresa_id = pg_temp.fx('empresa_x')), 0,
  'paradas, modalidades e lançamentos da empresa vão junto');
select is((select count(*)::int from public.empresas_modalidades where empresa_id = pg_temp.fx('empresa_y')), 1,
  'a outra empresa continua com as modalidades dela');
select is(pg_temp.erro_como(pg_temp.fx('u_dono_x'), 'select public.exportar_dados_empresa()'), '42501',
  'depois da exclusão não sobra nada para baixar');

select * from finish();
rollback;
