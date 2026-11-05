-- Combinado de pagamento (pedido de 05/11/2026): padrão da empresa com
-- exceção por motorista; o pedágio na comissão é uma escolha separada da base;
-- frete cheio (valor fechado). Só dono e gestor mudam o combinado.
begin;
\ir apoio/fixtures.psql

select plan(20);

create or replace function pg_temp.enviar(p_uid uuid, p_itens jsonb)
returns jsonb language sql as $$
  select pg_temp.como(p_uid, format('select public.sincronizar_lote(%L)', jsonb_build_object('itens', p_itens)))
$$;

insert into fx values
  ('f_antigo_bruto', '70000000-0000-4000-8000-000000000001'),
  ('f_novo',         '70000000-0000-4000-8000-000000000002'),
  ('f_cheio',        '70000000-0000-4000-8000-000000000003'),
  ('f_sem_pct',      '70000000-0000-4000-8000-000000000004');

-- ------------------------------------------------------- padrão da empresa

select is(pg_temp.erro_como(pg_temp.fx('u_dono_x'), format($q$update public.empresas
  set comissao_com_pedagio_padrao = true, salario_fixo_centavos = 250000 where id = %L$q$, pg_temp.fx('empresa_x'))), 'ok',
  'o dono muda o padrão da empresa (pedágio na comissão e salário fixo)');
select is((select comissao_com_pedagio_padrao::text || ':' || salario_fixo_centavos from public.empresas
  where id = pg_temp.fx('empresa_x')), 'true:250000', 'o padrão fica gravado');
select pg_temp.erro_como(pg_temp.fx('u_gestor_x'), format($q$update public.empresas
  set salario_fixo_centavos = 1 where id = %L$q$, pg_temp.fx('empresa_x')));
select is((select salario_fixo_centavos from public.empresas where id = pg_temp.fx('empresa_x')), 250000::bigint,
  'o gestor não muda o padrão da empresa');

-- ----------------------------------------------- exceção por motorista

select is(pg_temp.erro_como(pg_temp.fx('u_gestor_x'), format($q$update public.motoristas
  set percentual_comissao = 3, salario_fixo_centavos = 300000, comissao_com_pedagio = false where id = %L$q$,
  pg_temp.fx('mot_a'))), 'ok', 'o gestor põe um combinado só para um motorista (fixo + 3%)');
select is((select percentual_comissao::text || ':' || salario_fixo_centavos || ':' || comissao_com_pedagio::text
  || ':' || coalesce(comissao_sobre_bruto::text, 'padrão') from public.motoristas where id = pg_temp.fx('mot_a')),
  '3.0000:300000:false:padrão', 'o que não foi mudado segue o padrão da empresa');
select pg_temp.erro_como(pg_temp.fx('u_a'), format($q$update public.motoristas
  set salario_fixo_centavos = 999999 where id = %L$q$, pg_temp.fx('mot_a')));
select is((select salario_fixo_centavos from public.motoristas where id = pg_temp.fx('mot_a')), 300000::bigint,
  'o motorista não muda o próprio combinado');
select is(pg_temp.erro_como(pg_temp.fx('u_gestor_x'), format($q$update public.motoristas
  set percentual_comissao = 120 where id = %L$q$, pg_temp.fx('mot_a'))), '23514', 'comissão acima de 100% é recusada');
select is(pg_temp.erro_como(pg_temp.fx('u_gestor_x'), format($q$update public.motoristas
  set salario_fixo_centavos = -1 where id = %L$q$, pg_temp.fx('mot_a'))), '23514', 'salário negativo é recusado');
select is(pg_temp.erro_como(pg_temp.fx('u_dono_y'), format($q$update public.motoristas
  set salario_fixo_centavos = 1 where id = %L$q$, pg_temp.fx('mot_a'))), 'ok', 'dono de outra empresa: nada acontece');
select is((select salario_fixo_centavos from public.motoristas where id = pg_temp.fx('mot_a')), 300000::bigint,
  'e o combinado não muda');

-- ------------------------------------------------------- o que o app lê

select is(pg_temp.como(pg_temp.fx('u_a'), 'select public.situacao_acesso()') #>> '{motorista,salario_fixo_centavos}',
  '300000', 'o celular dele recebe o combinado só dele');
select is(pg_temp.como(pg_temp.fx('u_a'), 'select public.situacao_acesso()') #>> '{empresa,comissao_com_pedagio_padrao}',
  'true', 'e o padrão da empresa');

-- ------------------------------------------------------- fretes

select pg_temp.enviar(pg_temp.fx('u_a'), jsonb_build_array(
  pg_temp.frete(pg_temp.fx('f_sem_pct'), pg_temp.fx('cam_x1')) #- '{dados,percentual_comissao}'));
select is((select percentual_comissao from public.fretes where id = pg_temp.fx('f_sem_pct')), 3::numeric,
  'frete sem a comissão (app antigo): vale a do combinado dele');
select pg_temp.enviar(pg_temp.fx('u_a'), jsonb_build_array(
  pg_temp.frete(pg_temp.fx('f_antigo_bruto'), pg_temp.fx('cam_x1'), '{"comissao_sobre_bruto": true}')));
select is((select comissao_com_pedagio from public.fretes where id = pg_temp.fx('f_antigo_bruto')), true,
  'app antigo com "Frete + pedágio": o pedágio entra na comissão');
select pg_temp.enviar(pg_temp.fx('u_a'), jsonb_build_array(
  pg_temp.frete(pg_temp.fx('f_antigo_bruto'), pg_temp.fx('cam_x1'), '{"comissao_sobre_bruto": true, "origem": "Rio Verde"}')));
select is((select comissao_com_pedagio::text || ':' || origem from public.fretes where id = pg_temp.fx('f_antigo_bruto')),
  'true:Rio Verde', 'app antigo mudando o frete não mexe no pedágio');
select pg_temp.enviar(pg_temp.fx('u_a'), jsonb_build_array(
  pg_temp.frete(pg_temp.fx('f_novo'), pg_temp.fx('cam_x1'), '{"comissao_sobre_bruto": true, "comissao_com_pedagio": false}')));
select is((select comissao_sobre_bruto::text || ':' || comissao_com_pedagio::text from public.fretes
  where id = pg_temp.fx('f_novo')), 'true:false', 'app novo: base e pedágio são escolhas separadas');
select pg_temp.enviar(pg_temp.fx('u_a'), jsonb_build_array(
  pg_temp.frete(pg_temp.fx('f_cheio'), pg_temp.fx('cam_x1'),
    '{"frete_cheio": true, "valor_frete_cheio_centavos": 500000, "valor_tonelada_centavos": 0}')));
select is((select frete_cheio::text || ':' || valor_frete_cheio_centavos from public.fretes_efetivos
  where id = pg_temp.fx('f_cheio')), 'true:500000', 'frete cheio: o valor fechado fica gravado e o painel lê');
select is(pg_temp.enviar(pg_temp.fx('u_a'), jsonb_build_array(
  pg_temp.frete(gen_random_uuid(), pg_temp.fx('cam_x1'), '{"valor_frete_cheio_centavos": -5}'))) -> 'rejeitados' -> 0 ->> 'motivo',
  'invalido', 'valor do frete cheio negativo é recusado');

-- ------------------------------------------------------- correção

select is(pg_temp.erro_como(pg_temp.fx('u_gestor_x'), format($q$insert into public.ajustes_gestor
  (id, empresa_id, tabela_alvo, registro_id, campo, valor_novo, motivo, autor_id)
  values (gen_random_uuid(), %L, 'fretes', %L, 'comissao_com_pedagio', 'false', 'Combinado sem pedágio', auth.uid())$q$,
  pg_temp.fx('empresa_x'), pg_temp.fx('f_antigo_bruto'))), 'ok', 'o gestor corrige se o pedágio entra');
select is((select comissao_com_pedagio::text || ':' || array_to_string(campos_ajustados, ',') from public.fretes_efetivos
  where id = pg_temp.fx('f_antigo_bruto')), 'false:comissao_com_pedagio', 'a correção vale no painel e fica marcada');

select * from finish();
rollback;
