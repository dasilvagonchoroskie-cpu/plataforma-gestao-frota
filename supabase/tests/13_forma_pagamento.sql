-- Forma de pagamento do gasto (pedido de 23/10/2026): dinheiro (do vale) ou
-- nota assinada. Gasto em dinheiro abate do vale; o que passa do vale volta
-- para o motorista. App antigo (sem a forma) conta como nota.
begin;
\ir apoio/fixtures.psql

select plan(19);

create or replace function pg_temp.enviar(p_uid uuid, p_itens jsonb)
returns jsonb language sql as $$
  select pg_temp.como(p_uid, format('select public.sincronizar_lote(%L)', jsonb_build_object('itens', p_itens)))
$$;
create or replace function pg_temp.gasto(p_id uuid, p_valor int, p_extra jsonb default '{}')
returns jsonb language sql as $$
  select jsonb_build_object('tabela', 'gastos_viagem', 'dados', jsonb_build_object(
    'id', p_id, 'caminhao_id', pg_temp.fx('cam_x1'), 'categoria_id', pg_temp.fx('cat_x'),
    'data', '2026-10-05T15:00:00Z', 'valor_centavos', p_valor) || p_extra)
$$;
create or replace function pg_temp.ajustar(p_uid uuid, p_registro uuid, p_valor jsonb)
returns text language sql as $$
  select pg_temp.erro_como(p_uid, format($q$insert into public.ajustes_gestor
    (id, empresa_id, tabela_alvo, registro_id, campo, valor_novo, motivo, autor_id)
    values (gen_random_uuid(), public.empresa_do_usuario(), 'gastos_viagem', %L, 'forma_pagamento', %L,
            'Conferido com o motorista', auth.uid())$q$, p_registro, p_valor))
$$;

insert into fx values
  ('g_antigo',   '60000000-0000-4000-8000-000000000001'),
  ('g_dinheiro', '60000000-0000-4000-8000-000000000002'),
  ('g_nota',     '60000000-0000-4000-8000-000000000003'),
  ('g_pix',      '60000000-0000-4000-8000-000000000004'),
  ('vale_a',     '60000000-0000-4000-8000-000000000005'),
  ('acerto_a',   '60000000-0000-4000-8000-000000000006');

-- ------------------------------------------------------- lançamento

select pg_temp.enviar(pg_temp.fx('u_a'), jsonb_build_array(pg_temp.gasto(pg_temp.fx('g_antigo'), 3000)));
select is((select forma_pagamento from public.gastos_viagem where id = pg_temp.fx('g_antigo')), 'nota',
  'app antigo (sem a forma de pagamento): o gasto conta como nota');
select pg_temp.enviar(pg_temp.fx('u_a'), jsonb_build_array(
  pg_temp.gasto(pg_temp.fx('g_dinheiro'), 12000, '{"forma_pagamento": "dinheiro"}'),
  pg_temp.gasto(pg_temp.fx('g_nota'), 8000, '{"forma_pagamento": "nota"}'),
  jsonb_build_object('tabela', 'vales', 'dados', jsonb_build_object('id', pg_temp.fx('vale_a'),
    'data', '2026-10-03T12:00:00Z', 'valor_centavos', 50000))));
select is((select string_agg(forma_pagamento, ',' order by valor_centavos) from public.gastos_viagem
  where id in (pg_temp.fx('g_dinheiro'), pg_temp.fx('g_nota'))), 'nota,dinheiro',
  'o celular manda a forma escolhida: dinheiro ou nota');
select is(pg_temp.enviar(pg_temp.fx('u_a'), jsonb_build_array(
  pg_temp.gasto(pg_temp.fx('g_pix'), 1000, '{"forma_pagamento": "pix"}'))) -> 'rejeitados' -> 0 ->> 'motivo', 'invalido',
  'forma que não existe é recusada');
select is((select count(*)::int from public.gastos_viagem where id = pg_temp.fx('g_pix')), 0, 'e não grava');
select pg_temp.enviar(pg_temp.fx('u_a'), jsonb_build_array(
  pg_temp.gasto(pg_temp.fx('g_dinheiro'), 12000, '{"observacao": "Pátio"}')));
select is((select forma_pagamento || ':' || observacao from public.gastos_viagem where id = pg_temp.fx('g_dinheiro')),
  'dinheiro:Pátio', 'app antigo editando o gasto não muda a forma de pagamento');
select is((select forma_pagamento from public.gastos_viagem_efetivos where id = pg_temp.fx('g_dinheiro')), 'dinheiro',
  'o painel lê a forma de pagamento');
select is((select g ->> 'forma_pagamento' from jsonb_array_elements(pg_temp.como(pg_temp.fx('u_a'),
  'select public.baixar_alteracoes()') -> 'gastos_viagem') g where g ->> 'id' = pg_temp.fx('g_dinheiro')::text), 'dinheiro',
  'celular novo baixa a forma de pagamento');

-- ------------------------------------------------------- a conta

select is((pg_temp.como(pg_temp.fx('u_gestor_x'), format($q$select public.previa_acerto(%L, '2026-10-01', '2026-10-15')$q$,
  pg_temp.fx('mot_a'))) ->> 'gastos_dinheiro_centavos'), '12000', 'a prévia do acerto soma os gastos pagos em dinheiro');
select is((pg_temp.como(pg_temp.fx('u_gestor_x'), format($q$select public.fechar_acerto(%L, %L, '2026-10-01', '2026-10-15',
  150000)$q$, pg_temp.fx('acerto_a'), pg_temp.fx('mot_a'))) ->> 'para_receber_centavos'), '112000',
  'empresa paga os gastos: comissão - vale + gastos pagos em dinheiro (150.000 - 50.000 + 12.000)');
select is((select gastos_dinheiro_centavos || ':' || gastos_centavos from public.acertos where id = pg_temp.fx('acerto_a')),
  '12000:23000', 'o acerto guarda os gastos em dinheiro e o total');
select is(public.para_receber_acerto(150000, 0, 10000, 0, 30000, 30000, true, false), 170000::bigint,
  'gastou mais do que o vale: a diferença volta para o motorista');
select is(public.para_receber_acerto(150000, 0, 50000, 40000, 20000, 12000, true, true), 52000::bigint,
  'gastos do motorista: desconta vale, diesel e só os gastos na nota (o dinheiro já saiu do vale)');
select is(public.para_receber_acerto(150000, 0, 50000, 0, 20000, 12000, false, false), 150000::bigint,
  'vale que não desconta: os gastos em dinheiro também não mexem na conta');
select is(public.para_receber_acerto(150000, 10000, 50000, 40000, 20000, 0, true, false), 90000::bigint,
  'sem gasto em dinheiro, a conta é a de antes');

-- ------------------------------------------------------- correção

select is(pg_temp.ajustar(pg_temp.fx('u_gestor_x'), pg_temp.fx('g_dinheiro'), '"nota"'), 'ok',
  'o gestor corrige a forma de pagamento');
select is((select forma_pagamento || ':' || array_to_string(campos_ajustados, ',') from public.gastos_viagem_efetivos
  where id = pg_temp.fx('g_dinheiro')), 'nota:forma_pagamento', 'a correção vale no painel e fica marcada');
select is(pg_temp.ajustar(pg_temp.fx('u_gestor_x'), pg_temp.fx('g_nota'), '"pix"'), '23514',
  'correção para uma forma que não existe é recusada');
select is(pg_temp.ajustar(pg_temp.fx('u_a'), pg_temp.fx('g_nota'), '"dinheiro"'), '42501',
  'o motorista não corrige pelo gestor');
select is((pg_temp.como(pg_temp.fx('u_gestor_x'), format($q$select public.fechar_acerto(%L, %L, '2026-10-01', '2026-10-15',
  150000)$q$, pg_temp.fx('acerto_a'), pg_temp.fx('mot_a'))) ->> 'para_receber_centavos'), '100000',
  'corrigido para nota, o acerto refeito desconta o vale inteiro');

select * from finish();
rollback;
