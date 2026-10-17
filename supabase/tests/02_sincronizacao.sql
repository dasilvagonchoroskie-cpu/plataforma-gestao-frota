-- Sincronização offline: reenvio, ordem, conflitos, ajustes, troca de caminhão.
begin;
\ir apoio/fixtures.psql

-- Envia um lote como o usuário e devolve a resposta do servidor.
create or replace function pg_temp.enviar(p_uid uuid, p_itens jsonb, p_extra jsonb default '{}')
returns jsonb language sql as $$
  select pg_temp.como(p_uid, format('select public.sincronizar_lote(%L)',
    jsonb_build_object('itens', p_itens) || p_extra))
$$;
create or replace function pg_temp.item(p_tabela text, p_dados jsonb) returns jsonb language sql as $$
  select jsonb_build_object('tabela', p_tabela, 'dados', p_dados)
$$;
create or replace function pg_temp.qtd(j jsonb, k text) returns int language sql as $$
  select jsonb_array_length(j -> k)
$$;

insert into fx values
  ('abast_a', '40000000-0000-4000-8000-000000000001'),
  ('gasto_a', '40000000-0000-4000-8000-000000000002'),
  ('vale_a',  '40000000-0000-4000-8000-000000000003'),
  ('vale_a2', '40000000-0000-4000-8000-000000000004'),
  ('frete_a2','40000000-0000-4000-8000-000000000005'),
  ('uso_1',   '40000000-0000-4000-8000-000000000006'),
  ('uso_2',   '40000000-0000-4000-8000-000000000007'),
  ('uso_3',   '40000000-0000-4000-8000-000000000008'),
  ('uso_4',   '40000000-0000-4000-8000-000000000009'),
  ('cam_novo','40000000-0000-4000-8000-00000000000a'),
  ('cam_dup', '40000000-0000-4000-8000-00000000000b'),
  ('frete_a3','40000000-0000-4000-8000-00000000000c'),
  ('frete_a4','40000000-0000-4000-8000-00000000000d'),
  ('frete_b2','40000000-0000-4000-8000-00000000000e'),
  ('disp_a',  '40000000-0000-4000-8000-00000000000f');

create temp table lote_a as select jsonb_build_array(
  pg_temp.item('abastecimentos', jsonb_build_object('id', pg_temp.fx('abast_a'), 'caminhao_id', pg_temp.fx('cam_x1'),
    'frete_id', pg_temp.fx('frete_a'), 'data', '2026-10-06T12:00:00Z', 'cidade', 'Rio Verde', 'posto', 'Posto 1',
    'litros', 350.5, 'valor_centavos', 210300, 'km_odometro', 412300, 'tanque_cheio', true)),
  pg_temp.item('gastos_viagem', jsonb_build_object('id', pg_temp.fx('gasto_a'), 'caminhao_id', pg_temp.fx('cam_x1'),
    'data', '2026-10-06T15:00:00Z', 'categoria_id', pg_temp.fx('cat_x'), 'valor_centavos', 8000)),
  pg_temp.item('vales', jsonb_build_object('id', pg_temp.fx('vale_a'), 'data', '2026-10-07T10:00:00Z',
    'valor_centavos', 50000, 'observacao', 'Adiantamento')),
  pg_temp.item('fretes', (pg_temp.frete(pg_temp.fx('frete_a'), pg_temp.fx('cam_x1')) -> 'dados'))
) as itens;

select plan(48);

-- Lote normal e reenvio
select is(pg_temp.qtd(pg_temp.enviar(pg_temp.fx('u_a'), (select itens from lote_a)), 'aceitos'), 4,
  'lote com frete, diesel, gasto e vale é aceito');
select is(pg_temp.qtd(pg_temp.enviar(pg_temp.fx('u_a'), (select itens from lote_a)), 'aceitos'), 4,
  'reenviar o mesmo lote (resposta perdida, app fechado) é aceito de novo');
select is((select count(*)::int from public.fretes where motorista_id = pg_temp.fx('mot_a')), 1, 'reenvio não duplica frete');
select is((select count(*)::int from public.vales where motorista_id = pg_temp.fx('mot_a')), 1, 'reenvio não duplica vale');
select is((select count(*)::int from public.abastecimentos), 1, 'reenvio não duplica abastecimento');

-- O servidor manda no atualizado_em e na empresa
select ok((select atualizado_em > now() - interval '1 hour' from public.vales where id = pg_temp.fx('vale_a')),
  'atualizado_em é do servidor');
select is(pg_temp.qtd(pg_temp.enviar(pg_temp.fx('u_a'), jsonb_build_array(pg_temp.item('vales', jsonb_build_object(
  'id', pg_temp.fx('vale_a2'), 'data', '2031-01-01T10:00:00Z', 'valor_centavos', 1000,
  'atualizado_em', '2000-01-01T00:00:00Z', 'criado_no_aparelho_em', '2031-01-01T10:00:00Z',
  'empresa_id', pg_temp.fx('empresa_y'))))), 'aceitos'), 1, 'relógio do celular adiantado: lançamento aceito');
select ok((select atualizado_em > now() - interval '1 hour' and empresa_id = pg_temp.fx('empresa_x')
  from public.vales where id = pg_temp.fx('vale_a2')),
  'relógio do celular não manda no atualizado_em e a empresa vem do servidor');
select is((select data from public.vales where id = pg_temp.fx('vale_a2')), '2031-01-01T10:00:00Z'::timestamptz,
  'a data escolhida pelo motorista fica guardada como ele escolheu');

-- Dois motoristas offline enviando ao mesmo tempo
select is(pg_temp.qtd(pg_temp.enviar(pg_temp.fx('u_b'), jsonb_build_array(
  pg_temp.frete(pg_temp.fx('frete_b2'), pg_temp.fx('cam_x2')))), 'aceitos'), 1, 'motorista B envia o lote dele');
select is(pg_temp.qtd(pg_temp.enviar(pg_temp.fx('u_a'), jsonb_build_array(
  pg_temp.frete(pg_temp.fx('frete_a2'), pg_temp.fx('cam_x1')))), 'aceitos'), 1, 'motorista A envia o lote dele');
select is(pg_temp.como(pg_temp.fx('u_a'), 'select to_jsonb(count(*)) from public.fretes'), '2'::jsonb,
  'depois dos dois envios, A vê só os próprios 2 fretes');
select is(pg_temp.como(pg_temp.fx('u_gestor_x'), 'select to_jsonb(count(*)) from public.fretes'), '4'::jsonb,
  'o gestor vê os 4 fretes da empresa');

-- Tentativas de mexer no que é de outro
select is(pg_temp.enviar(pg_temp.fx('u_a'), jsonb_build_array(pg_temp.item('vales', jsonb_build_object(
  'id', gen_random_uuid(), 'motorista_id', pg_temp.fx('mot_b'), 'data', now(), 'valor_centavos', 1))))
  -> 'rejeitados' -> 0 ->> 'motivo', 'outro_motorista', 'não grava lançamento em nome de outro motorista');
select is(pg_temp.enviar(pg_temp.fx('u_a'), jsonb_build_array(
  pg_temp.frete(pg_temp.fx('frete_b'), pg_temp.fx('cam_x1'), '{"saldo_centavos": 1}')))
  -> 'rejeitados' -> 0 ->> 'motivo', 'id_em_uso', 'não altera o frete de outro motorista usando o mesmo id');
select is((select saldo_centavos from public.fretes where id = pg_temp.fx('frete_b')), 195000::bigint,
  'o frete de B continua igual');
select is(pg_temp.enviar(pg_temp.fx('u_a'), jsonb_build_array(pg_temp.item('gastos_viagem', jsonb_build_object(
  'id', gen_random_uuid(), 'caminhao_id', pg_temp.fx('cam_x1'), 'data', now(),
  'categoria_id', pg_temp.fx('cat_y'), 'valor_centavos', 100)))) -> 'rejeitados' -> 0 ->> 'motivo', 'invalido',
  'categoria de outra empresa é recusada');
select is(pg_temp.enviar(pg_temp.fx('u_a'), jsonb_build_array(pg_temp.item('abastecimentos', jsonb_build_object(
  'id', gen_random_uuid(), 'caminhao_id', pg_temp.fx('cam_x1'), 'frete_id', pg_temp.fx('frete_b'), 'data', now(),
  'litros', 10, 'valor_centavos', 100, 'km_odometro', 1)))) -> 'rejeitados' -> 0 ->> 'motivo', 'frete_invalido',
  'abastecimento não pode ser ligado ao frete de outro motorista');
select is(pg_temp.enviar(pg_temp.fx('u_a'), jsonb_build_array(pg_temp.item('fretes', (pg_temp.frete(
  pg_temp.fx('frete_a4'), pg_temp.fx('cam_y1')) -> 'dados')))) -> 'rejeitados' -> 0 ->> 'motivo', 'invalido',
  'frete em caminhão de outra empresa é recusado');

-- Um item ruim não derruba o lote
create temp table r_misto as select pg_temp.enviar(pg_temp.fx('u_a'), jsonb_build_array(
  pg_temp.item('vales', jsonb_build_object('id', gen_random_uuid(), 'data', now(), 'valor_centavos', -5)),
  pg_temp.item('vales', jsonb_build_object('id', gen_random_uuid(), 'data', now(), 'valor_centavos', 700)))) as r;
select is((select pg_temp.qtd(r, 'aceitos') || '/' || pg_temp.qtd(r, 'rejeitados') from r_misto), '1/1',
  'valor negativo é recusado e o outro item do lote entra');

-- Motorista corrige o próprio lançamento enquanto o gestor não ajustou
select is(pg_temp.qtd(pg_temp.enviar(pg_temp.fx('u_a'), jsonb_build_array(
  pg_temp.frete(pg_temp.fx('frete_a'), pg_temp.fx('cam_x1'), '{"saldo_centavos": 200000}'))), 'aceitos'), 1,
  'motorista corrige o próprio frete');
select is((select saldo_centavos from public.fretes where id = pg_temp.fx('frete_a')), 200000::bigint, 'correção gravada');
select is((select count(*)::int from public.auditoria where tabela = 'fretes' and registro_id = pg_temp.fx('frete_a')
  and acao = 'update'), 1, 'a correção ficou na auditoria');

-- Depois do ajuste do gestor, o motorista não muda mais
select pg_temp.como(pg_temp.fx('u_gestor_x'), format($q$insert into public.ajustes_gestor
  (id, empresa_id, tabela_alvo, registro_id, campo, valor_novo, motivo, autor_id)
  values (gen_random_uuid(), public.empresa_do_usuario(), 'fretes', %L, 'saldo_centavos', '210000', 'Conferido no extrato', auth.uid())
  returning '{}'::jsonb$q$, pg_temp.fx('frete_a')));
create temp table r_ajustado as select pg_temp.enviar(pg_temp.fx('u_a'), jsonb_build_array(
  pg_temp.frete(pg_temp.fx('frete_a'), pg_temp.fx('cam_x1'), '{"saldo_centavos": 1}'))) as r;
select is((select r -> 'rejeitados' -> 0 ->> 'motivo' from r_ajustado), 'ajustado',
  'depois do ajuste do gestor o motorista não altera o lançamento');
select is((select (r -> 'rejeitados' -> 0 -> 'atual' ->> 'saldo_centavos')::bigint from r_ajustado), 200000::bigint,
  'a recusa devolve o registro do servidor para o app voltar ao certo');
select is(pg_temp.qtd(pg_temp.enviar(pg_temp.fx('u_a'), jsonb_build_array(
  pg_temp.frete(pg_temp.fx('frete_a'), pg_temp.fx('cam_x1'), '{"saldo_centavos": 200000}'))), 'aceitos'), 1,
  'reenviar o mesmo conteúdo depois do ajuste continua aceito');
select is(pg_temp.como(pg_temp.fx('u_a'), format('select to_jsonb(saldo_centavos) from public.fretes_efetivos where id = %L',
  pg_temp.fx('frete_a'))), '210000'::jsonb, 'o motorista vê o valor ajustado pela view');

-- Apagar (sem apagar de verdade)
select is(pg_temp.qtd(pg_temp.enviar(pg_temp.fx('u_a'), jsonb_build_array(pg_temp.item('vales', jsonb_build_object(
  'id', pg_temp.fx('vale_a2'), 'data', '2031-01-01T10:00:00Z', 'valor_centavos', 1000, 'apagado_em', now())))), 'aceitos'), 1,
  'motorista apaga um vale');
select ok((select apagado_em is not null from public.vales where id = pg_temp.fx('vale_a2')), 'a linha continua guardada');
select is(pg_temp.como(pg_temp.fx('u_gestor_x'), format('select to_jsonb(count(*)) from public.vales where id = %L',
  pg_temp.fx('vale_a2'))), '0'::jsonb, 'o vale apagado some das listas');
select is(pg_temp.enviar(pg_temp.fx('u_a'), jsonb_build_array(pg_temp.item('vales', jsonb_build_object(
  'id', pg_temp.fx('vale_a2'), 'data', '2031-01-01T10:00:00Z', 'valor_centavos', 1000))))
  -> 'rejeitados' -> 0 ->> 'motivo', 'apagado', 'um envio antigo não ressuscita o vale apagado');

-- Troca de caminhão no meio do mês
select is(pg_temp.qtd(pg_temp.enviar(pg_temp.fx('u_a'), jsonb_build_array(
  pg_temp.item('uso_caminhao', jsonb_build_object('id', pg_temp.fx('uso_1'), 'caminhao_id', pg_temp.fx('cam_x1'),
    'inicio_em', '2026-10-01T08:00:00Z')),
  pg_temp.item('uso_caminhao', jsonb_build_object('id', pg_temp.fx('uso_2'), 'caminhao_id', pg_temp.fx('cam_x2'),
    'inicio_em', '2026-10-15T08:00:00Z')),
  pg_temp.frete(pg_temp.fx('frete_a3'), pg_temp.fx('cam_x2'), '{"data_carga": "2026-10-16T08:00:00Z"}'))), 'aceitos'), 3,
  'troca de caminhão no meio do mês');
select is((select fim_em from public.uso_caminhao where id = pg_temp.fx('uso_1')), '2026-10-15T08:00:00Z'::timestamptz,
  'o uso do caminhão anterior fecha na hora da troca');
select is((select count(*)::int from public.uso_caminhao where motorista_id = pg_temp.fx('mot_a') and fim_em is null), 1,
  'só um caminhão em uso por motorista');
select is((select string_agg(c.placa || ':' || n, ',' order by c.placa) from (
  select caminhao_id, count(*) n from public.fretes where motorista_id = pg_temp.fx('mot_a') and apagado_em is null
  group by caminhao_id) f join public.caminhoes c on c.id = f.caminhao_id), 'ABC1D23:2,DEF4567:1',
  'relatório por caminhão: cada frete fica no caminhão em que foi lançado');

-- Trocas feitas sem internet chegando fora de ordem
select pg_temp.enviar(pg_temp.fx('u_a'), jsonb_build_array(pg_temp.item('uso_caminhao', jsonb_build_object(
  'id', pg_temp.fx('uso_4'), 'caminhao_id', pg_temp.fx('cam_x1'), 'inicio_em', '2026-10-25T08:00:00Z'))));
select pg_temp.enviar(pg_temp.fx('u_a'), jsonb_build_array(pg_temp.item('uso_caminhao', jsonb_build_object(
  'id', pg_temp.fx('uso_3'), 'caminhao_id', pg_temp.fx('cam_x2'), 'inicio_em', '2026-10-20T08:00:00Z'))));
select is((select string_agg(to_char(inicio_em at time zone 'UTC', 'DD') || '-' || coalesce(to_char(fim_em at time zone 'UTC', 'DD'), 'aberto'),
  ',' order by inicio_em) from public.uso_caminhao where motorista_id = pg_temp.fx('mot_a')),
  '01-15,15-20,20-25,25-aberto', 'trocas offline fora de ordem ficam na sequência certa');
select is(pg_temp.qtd(pg_temp.enviar(pg_temp.fx('u_a'), jsonb_build_array(pg_temp.item('uso_caminhao', jsonb_build_object(
  'id', pg_temp.fx('uso_3'), 'caminhao_id', pg_temp.fx('cam_x2'), 'inicio_em', '2026-10-20T08:00:00Z')))), 'aceitos'), 1,
  'reenviar a mesma troca não duplica');

-- Caminhão que o motorista não achou na lista
select is(pg_temp.qtd(pg_temp.enviar(pg_temp.fx('u_a'), jsonb_build_array(
  pg_temp.item('caminhoes', jsonb_build_object('id', pg_temp.fx('cam_novo'), 'placa', 'ghi-2j34')),
  pg_temp.frete(gen_random_uuid(), pg_temp.fx('cam_novo')))), 'aceitos'), 2,
  'motorista cadastra a placa e já lança nela');
select is((select placa || ':' || confirmado from public.caminhoes where id = pg_temp.fx('cam_novo')), 'GHI2J34:false',
  'o caminhão entra como não confirmado, com a placa normalizada');
create temp table r_dup as select pg_temp.enviar(pg_temp.fx('u_a'), jsonb_build_array(
  pg_temp.item('caminhoes', jsonb_build_object('id', pg_temp.fx('cam_dup'), 'placa', 'ABC-1D23')),
  pg_temp.frete(pg_temp.fx('frete_a4'), pg_temp.fx('cam_dup')))) as r;
select is((select (r -> 'aceitos' -> 0 ->> 'substituido_por')::uuid from r_dup), pg_temp.fx('cam_x1'),
  'placa que o gestor já tinha cadastrado: o app recebe o id certo');
select is((select caminhao_id from public.fretes where id = pg_temp.fx('frete_a4')), pg_temp.fx('cam_x1'),
  'o frete do mesmo lote vai para o caminhão certo');

-- Baixar alterações (celular novo e conferência)
create temp table baixa as select pg_temp.como(pg_temp.fx('u_a'), 'select public.baixar_alteracoes(null)') as b;
select is((select pg_temp.qtd(b, 'fretes') from baixa), 5, 'celular novo baixa todos os fretes do motorista');
select is((select pg_temp.qtd(b, 'caminhoes') from baixa), 3, 'baixa os caminhões da empresa X (e não os de Y)');
select is((select pg_temp.qtd(b, 'ajustes') from baixa), 1, 'baixa o ajuste do gestor nos próprios lançamentos');
select is(pg_temp.como(pg_temp.fx('u_a'), $q$select jsonb_array_length(public.baixar_alteracoes(now() + interval '1 hour') -> 'fretes')$q$),
  '0'::jsonb, 'sem nada novo, não baixa nada de novo');

-- Aparelho desligado pelo gestor
select pg_temp.enviar(pg_temp.fx('u_a'), '[]', jsonb_build_object('dispositivo_id', pg_temp.fx('disp_a'), 'apelido', 'Moto G35'));
select pg_temp.como(pg_temp.fx('u_gestor_x'), format($q$update public.dispositivos set revogado_em = now() where id = %L
  returning '{}'::jsonb$q$, pg_temp.fx('disp_a')));
select is(pg_temp.erro_como(pg_temp.fx('u_a'), format('select public.sincronizar_lote(%L)',
  jsonb_build_object('dispositivo_id', pg_temp.fx('disp_a'), 'itens', '[]'::jsonb))), '42501',
  'celular desligado pelo gestor não envia mais');

-- Empresa suspensa: lê, mas não envia
update public.empresas set status = 'suspensa' where id = pg_temp.fx('empresa_x');
select is(pg_temp.enviar(pg_temp.fx('u_a'), jsonb_build_array(pg_temp.item('vales', jsonb_build_object(
  'id', gen_random_uuid(), 'data', now(), 'valor_centavos', 100)))) -> 'rejeitados' -> 0 ->> 'motivo',
  'empresa_suspensa', 'empresa suspensa não recebe envios novos');
select is(pg_temp.como(pg_temp.fx('u_a'), 'select to_jsonb(count(*)) from public.fretes'), '5'::jsonb,
  'com a empresa suspensa os dados continuam guardados e o motorista ainda vê os seus');

select * from finish();
rollback;
