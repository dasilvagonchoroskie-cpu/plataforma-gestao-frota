-- Modalidades de operação: Graneleiro por padrão, Baú por viagem, acerto do
-- gestor, campos ajustados pelo dono e campos novos da Plataforma.
begin;
\ir apoio/fixtures.psql

select plan(67);

create or replace function pg_temp.enviar(p_uid uuid, p_itens jsonb)
returns jsonb language sql as $$
  select pg_temp.como(p_uid, format('select public.sincronizar_lote(%L)', jsonb_build_object('itens', p_itens)))
$$;
create or replace function pg_temp.item(p_tabela text, p_dados jsonb) returns jsonb language sql as $$
  select jsonb_build_object('tabela', p_tabela, 'dados', p_dados)
$$;
create or replace function pg_temp.qtd(j jsonb, k text) returns int language sql as $$
  select jsonb_array_length(j -> k)
$$;
create or replace function pg_temp.mod_da_empresa(p_uid uuid, p_codigo text) returns jsonb language sql as $$
  select x from jsonb_array_elements(pg_temp.como(p_uid, 'select public.modalidades_da_empresa()')) x
  where x ->> 'codigo' = p_codigo
$$;
create or replace function pg_temp.campo(p_modalidade jsonb, p_chave text) returns jsonb language sql as $$
  select c from jsonb_array_elements(p_modalidade -> 'campos') c where c ->> 'chave' = p_chave
$$;

insert into fx values
  ('u_admin', '10000000-0000-4000-8000-0000000000aa'),
  ('u_e',     '10000000-0000-4000-8000-000000000008'),
  ('viagem_d1', '50000000-0000-4000-8000-000000000001'),
  ('viagem_d2', '50000000-0000-4000-8000-000000000002'),
  ('viagem_d3', '50000000-0000-4000-8000-000000000003'),
  ('vale_d',    '50000000-0000-4000-8000-000000000004'),
  ('abast_d',   '50000000-0000-4000-8000-000000000005'),
  ('gasto_d',   '50000000-0000-4000-8000-000000000006'),
  ('acerto_d',  '50000000-0000-4000-8000-000000000007'),
  ('acerto_d2', '50000000-0000-4000-8000-000000000008'),
  ('frete_a5',  '50000000-0000-4000-8000-000000000009');
insert into auth.users (id, email, email_confirmed_at) values
  (pg_temp.fx('u_admin'), 'admin@plataforma.teste', now()),
  (pg_temp.fx('u_e'), 'motorista.e@teste.com', now());
insert into public.admins_plataforma (usuario_id) values (pg_temp.fx('u_admin'));

-- ------------------------------------------- tudo o que existe é Graneleiro

select is((select modalidade from public.fretes where id = pg_temp.fx('frete_a')), 'graneleiro',
  'frete enviado sem modalidade fica Graneleiro');
select is((select string_agg(modalidade, ',') from public.motoristas where empresa_id = pg_temp.fx('empresa_x')),
  'graneleiro,graneleiro', 'motoristas da empresa com uma modalidade só ficam nela');
select is(pg_temp.como(pg_temp.fx('u_a'), 'select public.situacao_acesso()') -> 'motorista' ->> 'modalidade', 'graneleiro',
  'o app do motorista sabe a modalidade dele');
select is((select string_agg(x ->> 'codigo', ',') from jsonb_array_elements(
  pg_temp.como(pg_temp.fx('u_a'), 'select public.situacao_acesso()') -> 'empresa' -> 'modalidades') x), 'graneleiro',
  'e as modalidades ligadas na empresa (só Graneleiro)');
select is(pg_temp.campo((pg_temp.como(pg_temp.fx('u_a'), 'select public.situacao_acesso()')
  -> 'empresa' -> 'modalidades') -> 0, 'embarcador') ->> 'rotulo', 'Embarcador ou cliente',
  'os campos de fábrica do Graneleiro são os de sempre');
select is(jsonb_array_length(pg_temp.como(pg_temp.fx('u_gestor_x'), 'select public.modalidades_da_empresa()')), 5,
  'o gestor vê as cinco modalidades do catálogo');
select is((pg_temp.mod_da_empresa(pg_temp.fx('u_gestor_x'), 'graneleiro') ->> 'motoristas')::int, 2,
  'com quantos motoristas usam cada uma');

-- ------------------------------------------------ só o dono liga e ajusta

select is(pg_temp.erro_como(pg_temp.fx('u_gestor_x'), $q$select public.salvar_modalidade_empresa('bau', true)$q$),
  '42501', 'gestor não liga modalidade');
select is(pg_temp.erro_como(pg_temp.fx('u_a'), $q$select public.salvar_modalidade_empresa('bau', true)$q$),
  '42501', 'motorista não liga modalidade');
select is(pg_temp.erro_como(pg_temp.fx('u_a'), 'select public.modalidades_da_empresa()'), '42501',
  'motorista não abre a tela de modalidades');
select is(pg_temp.mensagem_como(pg_temp.fx('u_dono_x'),
  $q$select public.salvar_modalidade_empresa('bau', true, '{"nao_existe": {"visivel": false}}')$q$),
  'Este campo não existe nesta modalidade.', 'campo que não existe é recusado');
select is(pg_temp.mensagem_como(pg_temp.fx('u_dono_x'),
  $q$select public.salvar_modalidade_empresa('bau', true, '{"observacao": {"rotulo": "Um nome de campo comprido demais para caber"}}')$q$),
  'O nome do campo pode ter até 40 letras.', 'nome de campo grande é recusado');

select pg_temp.como(pg_temp.fx('u_dono_x'), $q$select public.salvar_modalidade_empresa('bau', true,
  '{"entregas_cidades": {"rotulo": "Cidades atendidas", "obrigatorio": true},
    "observacao": {"visivel": false},
    "placa_carreta": {"visivel": false, "rotulo": "Carreta"}}')$q$);
create temp table bau_x as select pg_temp.mod_da_empresa(pg_temp.fx('u_dono_x'), 'bau') as m;
grant select on bau_x to authenticated;
select is((select (m ->> 'ativa')::boolean from bau_x), true, 'o dono liga o Baú');
select is((select pg_temp.campo(m, 'entregas_cidades') ->> 'rotulo' || ':' || (pg_temp.campo(m, 'entregas_cidades') ->> 'obrigatorio')
  from bau_x), 'Cidades atendidas:true', 'renomeia e torna obrigatório');
select is((select pg_temp.campo(m, 'observacao') ->> 'visivel' from bau_x), 'false', 'esconde um campo opcional');
select is((select pg_temp.campo(m, 'placa_carreta') ->> 'visivel' || ':' || (pg_temp.campo(m, 'placa_carreta') ->> 'rotulo')
  from bau_x), 'true:Carreta', 'campo que não pode sumir continua visível (só muda o nome)');
select is((select count(*)::int from jsonb_array_elements(
  pg_temp.como(pg_temp.fx('u_a'), 'select public.situacao_acesso()') -> 'empresa' -> 'modalidades')), 2,
  'o app passa a receber o Baú também');
select is(pg_temp.mensagem_como(pg_temp.fx('u_dono_x'), $q$select public.salvar_modalidade_empresa('graneleiro', false)$q$),
  'Há motoristas nesta modalidade. Troque a modalidade deles antes de desligar.',
  'não desliga modalidade com motorista');
select is(pg_temp.como(pg_temp.fx('u_dono_y'), $q$select to_jsonb(count(*)) from public.empresas_modalidades
  where modalidade = 'bau'$q$)::text, '0', 'a empresa Y não vê as modalidades da X');

-- ------------------------------------------------- modalidade do motorista

-- Código individual com Baú: o motorista entra já no Baú.
create temp table conv as select pg_temp.como(pg_temp.fx('u_gestor_x'),
  $q$select public.gerar_convite_motorista('Motorista D', '153.509.460-56', 'bau')$q$) as r;
grant select on conv to authenticated;
select is((select r ->> 'modalidade' from conv), 'bau', 'o código individual guarda a modalidade');
select is(pg_temp.mensagem_como(pg_temp.fx('u_gestor_x'),
  $q$select public.gerar_convite_motorista('Fulano', '123.456.789-09', 'sider')$q$),
  'Esta modalidade não está ligada na empresa.', 'código com modalidade desligada é recusado');
select pg_temp.como(pg_temp.fx('u_d'), format('select public.pedir_entrada(%L)', (select r ->> 'codigo' from conv)));
insert into fx select 'mot_d', id from public.motoristas where perfil_id = pg_temp.fx('u_d');
select is((select modalidade from public.motoristas where id = pg_temp.fx('mot_d')), 'bau',
  'motorista entra com a modalidade do código');

-- Código da empresa com duas modalidades ligadas: o motorista escolhe.
select pg_temp.como(pg_temp.fx('u_e'), $q$select public.completar_cadastro('Motorista E', '12345678909')$q$);
select pg_temp.como(pg_temp.fx('u_e'), format('select public.pedir_entrada(%L)',
  (select codigo_entrada from public.empresas where id = pg_temp.fx('empresa_x'))));
select pg_temp.como(pg_temp.fx('u_gestor_x'), format('select public.decidir_entrada(%L, true)',
  (select id from public.pedidos_entrada where perfil_id = pg_temp.fx('u_e'))));
insert into fx select 'mot_e', id from public.motoristas where perfil_id = pg_temp.fx('u_e');
select is((pg_temp.como(pg_temp.fx('u_e'), 'select public.situacao_acesso()') -> 'motorista' -> 'modalidade'), 'null'::jsonb,
  'com duas modalidades, o motorista fica sem e o app pergunta');
select is(pg_temp.mensagem_como(pg_temp.fx('u_e'), $q$select public.escolher_minha_modalidade('sider')$q$),
  'Esta modalidade não está ligada na empresa.', 'não escolhe modalidade desligada');
select is(pg_temp.como(pg_temp.fx('u_e'), $q$select public.escolher_minha_modalidade('bau')$q$) ->> 'modalidade', 'bau',
  'escolhe entre as ligadas');
select is(pg_temp.mensagem_como(pg_temp.fx('u_e'), $q$select public.escolher_minha_modalidade('graneleiro')$q$),
  'A sua modalidade já foi escolhida. Para trocar, fale com o seu patrão.', 'depois, só o gestor troca');

select is(pg_temp.como(pg_temp.fx('u_gestor_x'), format($q$select public.definir_modalidade_motorista(%L, 'graneleiro')$q$,
  pg_temp.fx('mot_e'))) ->> 'modalidade', 'graneleiro', 'o gestor troca a modalidade do motorista');
select is(pg_temp.mensagem_como(pg_temp.fx('u_gestor_x'), format($q$select public.definir_modalidade_motorista(%L, 'sider')$q$,
  pg_temp.fx('mot_e'))), 'Esta modalidade não está ligada na empresa.', 'só para modalidade ligada');
select is(pg_temp.mensagem_como(pg_temp.fx('u_dono_y'), format($q$select public.definir_modalidade_motorista(%L, 'graneleiro')$q$,
  pg_temp.fx('mot_e'))), 'Motorista não encontrado.', 'nem em motorista de outra empresa');
select is(pg_temp.erro_como(pg_temp.fx('u_a'), format($q$select public.definir_modalidade_motorista(%L, 'bau')$q$,
  pg_temp.fx('mot_a'))), '42501', 'motorista não troca a própria modalidade');

-- -------------------------------------------------------- viagens (Baú)

create temp table r1 as select pg_temp.enviar(pg_temp.fx('u_d'), jsonb_build_array(
  pg_temp.item('viagens', jsonb_build_object('id', pg_temp.fx('viagem_d1'), 'caminhao_id', pg_temp.fx('cam_x1'),
    'placa_carreta', 'abc-1d23', 'engate_local', 'Cajamar SP', 'engate_em', '2026-10-10T08:00:00Z',
    'entregas_quantidade', 3, 'entregas_cidades', '["Campinas", "Limeira"]'::jsonb,
    'extras', '{"nota": "NF 123"}'::jsonb)),
  pg_temp.item('vales', jsonb_build_object('id', pg_temp.fx('vale_d'), 'data', '2026-10-11T12:00:00Z', 'valor_centavos', 20000)),
  pg_temp.item('abastecimentos', jsonb_build_object('id', pg_temp.fx('abast_d'), 'caminhao_id', pg_temp.fx('cam_x1'),
    'data', '2026-10-11T13:00:00Z', 'litros', 100, 'valor_centavos', 50000, 'km_odometro', 1000)),
  pg_temp.item('gastos_viagem', jsonb_build_object('id', pg_temp.fx('gasto_d'), 'caminhao_id', pg_temp.fx('cam_x1'),
    'data', '2026-10-12T13:00:00Z', 'categoria_id', pg_temp.fx('cat_x'), 'valor_centavos', 5000))
)) as r;
grant select on r1 to authenticated;
select is((select pg_temp.qtd(r, 'aceitos') || '/' || pg_temp.qtd(r, 'rejeitados') from r1), '4/0',
  'o motorista do Baú envia viagem, vale, diesel e gasto');
select is((select placa_carreta || ':' || modalidade || ':' || entregas_quantidade || ':' || (entregas_cidades ->> 1)
  || ':' || (extras ->> 'nota') || ':' || coalesce(desengate_em::text, 'aberta')
  from public.viagens where id = pg_temp.fx('viagem_d1')), 'ABC1D23:bau:3:Limeira:NF 123:aberta',
  'a viagem fica com a placa arrumada, a modalidade do motorista e em andamento');

select is((select pg_temp.qtd(pg_temp.enviar(pg_temp.fx('u_d'), jsonb_build_array(
  pg_temp.item('viagens', jsonb_build_object('id', pg_temp.fx('viagem_d1'), 'caminhao_id', pg_temp.fx('cam_x1'),
    'placa_carreta', 'ABC1D23', 'engate_local', 'Cajamar SP', 'engate_em', '2026-10-10T08:00:00Z',
    'desengate_local', 'Ribeirão Preto SP', 'desengate_em', '2026-10-12T18:00:00Z', 'entregas_quantidade', 4,
    'entregas_cidades', '["Campinas", "Limeira", "Araras"]'::jsonb)))), 'aceitos')), 1, 'desengatou: a viagem fecha');
select is((select desengate_local || ':' || entregas_quantidade || ':' || (extras ->> 'nota')
  from public.viagens where id = pg_temp.fx('viagem_d1')), 'Ribeirão Preto SP:4:NF 123',
  'o que não veio no envio (extras) continua como estava');
select is((select pg_temp.qtd(pg_temp.enviar(pg_temp.fx('u_d'), jsonb_build_array(
  pg_temp.item('viagens', jsonb_build_object('id', pg_temp.fx('viagem_d2'), 'caminhao_id', pg_temp.fx('cam_x1'),
    'placa_carreta', 'XYZ1234', 'engate_em', '2026-10-13T08:00:00Z', 'desengate_em', '2026-10-12T08:00:00Z')))),
  'rejeitados')), 1, 'desengate antes do engate é recusado');
select is((select pg_temp.qtd(pg_temp.enviar(pg_temp.fx('u_d'), jsonb_build_array(
  pg_temp.item('viagens', jsonb_build_object('id', pg_temp.fx('viagem_d3'), 'caminhao_id', pg_temp.fx('cam_x1'),
    'placa_carreta', 'XY12', 'engate_em', '2026-10-13T08:00:00Z')))), 'rejeitados')), 1,
  'placa de carreta errada é recusada');
select is((select pg_temp.qtd(pg_temp.enviar(pg_temp.fx('u_a'), jsonb_build_array(
  pg_temp.item('viagens', jsonb_build_object('id', pg_temp.fx('viagem_d1'), 'caminhao_id', pg_temp.fx('cam_x1'),
    'placa_carreta', 'ABC1D23', 'engate_em', '2026-10-10T08:00:00Z')))), 'rejeitados')), 1,
  'outro motorista não muda a viagem');
select is(pg_temp.como(pg_temp.fx('u_a'), 'select to_jsonb(count(*)) from public.viagens')::text, '0',
  'outro motorista não vê a viagem');
select is(pg_temp.como(pg_temp.fx('u_gestor_x'), 'select to_jsonb(count(*)) from public.viagens')::text, '1',
  'o gestor vê a viagem');
select is(pg_temp.como(pg_temp.fx('u_dono_y'), 'select to_jsonb(count(*)) from public.viagens')::text, '0',
  'a outra empresa não vê a viagem');
select is(jsonb_array_length(pg_temp.como(pg_temp.fx('u_d'), 'select public.baixar_alteracoes()') -> 'viagens'), 1,
  'celular novo baixa as viagens');

-- Frete com campo novo (extras) e modalidade.
select pg_temp.enviar(pg_temp.fx('u_a'), jsonb_build_array(
  pg_temp.frete(pg_temp.fx('frete_a5'), pg_temp.fx('cam_x1'), '{"extras": {"ticket": "778"}}')));
select pg_temp.enviar(pg_temp.fx('u_a'), jsonb_build_array(
  pg_temp.frete(pg_temp.fx('frete_a5'), pg_temp.fx('cam_x1'), '{"saldo_centavos": 1}')));
select is((select modalidade || ':' || (extras ->> 'ticket') || ':' || saldo_centavos from public.fretes
  where id = pg_temp.fx('frete_a5')), 'graneleiro:778:1', 'frete guarda os campos extras e a modalidade');
select is((select extras ->> 'ticket' from public.fretes_efetivos where id = pg_temp.fx('frete_a5')), '778',
  'o painel lê os extras do frete');

-- ------------------------------------------------------------- acerto

select is((select (r ->> 'vales_centavos') || ':' || (r ->> 'diesel_centavos') || ':' || (r ->> 'gastos_centavos') || ':'
  || (r ->> 'quantidade_viagens') || ':' || (r ->> 'desconta_vales') from (select pg_temp.como(pg_temp.fx('u_gestor_x'),
  format($q$select public.previa_acerto(%L, '2026-10-01', '2026-10-15')$q$, pg_temp.fx('mot_d'))) as r) t),
  '20000:50000:5000:1:true', 'a prévia soma vales, diesel, gastos e viagens do período');
select is(pg_temp.erro_como(pg_temp.fx('u_d'), format($q$select public.fechar_acerto(%L, %L, '2026-10-01', '2026-10-15', 150000)$q$,
  pg_temp.fx('acerto_d'), pg_temp.fx('mot_d'))), '42501', 'motorista não fecha acerto');
select is(pg_temp.mensagem_como(pg_temp.fx('u_dono_y'), format($q$select public.previa_acerto(%L, '2026-10-01', '2026-10-15')$q$,
  pg_temp.fx('mot_d'))), 'Motorista não encontrado.', 'a outra empresa não vê o acerto deste motorista');
select is(pg_temp.mensagem_como(pg_temp.fx('u_gestor_x'), format($q$select public.fechar_acerto(%L, %L, '2026-10-01',
  '2026-10-15', 150000, '[{"descricao": " ", "valor_centavos": 100}]')$q$, pg_temp.fx('acerto_d'), pg_temp.fx('mot_d'))),
  'Escreva o motivo de cada desconto (até 80 letras).', 'desconto sem motivo é recusado');
select is(pg_temp.mensagem_como(pg_temp.fx('u_gestor_x'), format($q$select public.fechar_acerto(%L, %L, '2026-10-15',
  '2026-10-01', 150000)$q$, pg_temp.fx('acerto_d'), pg_temp.fx('mot_d'))),
  'Confira o período: o fim vem depois do começo.', 'período ao contrário é recusado');

create temp table ac as select pg_temp.como(pg_temp.fx('u_gestor_x'), format($q$select public.fechar_acerto(%L, %L,
  '2026-10-01', '2026-10-15', 150000, '[{"descricao": "Multa  de trânsito", "valor_centavos": 10000}]', 'Quinzena 1')$q$,
  pg_temp.fx('acerto_d'), pg_temp.fx('mot_d'))) as r;
grant select on ac to authenticated;
select is((select (r ->> 'para_receber_centavos') || ':' || (r ->> 'total_descontos_centavos') || ':'
  || (r -> 'descontos' -> 0 ->> 'descricao') || ':' || (r ->> 'quantidade_viagens') from ac),
  '120000:10000:Multa de trânsito:1', 'para receber = comissão - descontos - vales (diesel e gastos pela regra)');
select is(pg_temp.mensagem_como(pg_temp.fx('u_gestor_x'), format($q$select public.fechar_acerto(%L, %L, '2026-10-10',
  '2026-10-20', 1000)$q$, pg_temp.fx('acerto_d2'), pg_temp.fx('mot_d'))),
  'Já tem acerto fechado de 01/10/2026 a 15/10/2026. Abra esse acerto para corrigir.',
  'não fecha dois acertos no mesmo período');

-- Regra da empresa: diesel e gastos descontam.
select pg_temp.como(pg_temp.fx('u_dono_x'), $q$update public.empresas set gastos_descontam_do_liquido = true
  where id = public.empresa_do_usuario() returning '{}'::jsonb$q$);
select is((pg_temp.como(pg_temp.fx('u_gestor_x'), format($q$select public.fechar_acerto(%L, %L, '2026-10-01', '2026-10-15',
  150000, '[]')$q$, pg_temp.fx('acerto_d'), pg_temp.fx('mot_d'))) ->> 'para_receber_centavos'), '75000',
  'corrigir o acerto refaz a conta (agora diesel e gastos descontam)');
select ok((select count(*) from public.auditoria where tabela = 'acertos' and registro_id = pg_temp.fx('acerto_d')
  and acao = 'update') >= 1, 'a correção fica na auditoria');
select is(pg_temp.como(pg_temp.fx('u_d'), 'select to_jsonb(count(*)) from public.acertos')::text, '1',
  'o motorista vê o acerto fechado dele');
select is(pg_temp.como(pg_temp.fx('u_a'), 'select to_jsonb(count(*)) from public.acertos')::text, '0',
  'outro motorista não vê');
select ok((select not ((x -> 0) ? 'autor_id') from (select pg_temp.como(pg_temp.fx('u_d'), 'select public.baixar_alteracoes()')
  -> 'acertos' as x) t), 'o celular baixa o acerto (sem dizer quem fechou)');

-- ------------------------------------------- Plataforma: modalidades e campos

select is(pg_temp.erro_como(pg_temp.fx('u_dono_x'), $q$select public.plataforma_salvar_modalidade('porta_container', 'Porta-contêiner', 'viagem')$q$),
  '42501', 'dono de empresa não cria modalidade');
select is(pg_temp.como(pg_temp.fx('u_admin'), $q$select public.plataforma_salvar_modalidade('porta_container',
  'Porta-contêiner', 'viagem')$q$) ->> 'tipo', 'viagem', 'a Plataforma cria modalidade nova (com os campos do tipo)');
select is(pg_temp.mensagem_como(pg_temp.fx('u_admin'), $q$select public.plataforma_salvar_modalidade('porta_container',
  'Porta-contêiner', 'frete')$q$), 'O tipo de uma modalidade não muda depois de criada.', 'o tipo não muda');
select is(pg_temp.mensagem_como(pg_temp.fx('u_admin'), $q$select public.plataforma_salvar_campo('bau',
  '{"chave": "placa_carreta", "rotulo": "Placa", "tipo": "texto", "etapa": "engate"}')$q$),
  'Este código de campo é reservado. Escolha outro.', 'campo com nome de coluna é recusado');
select is(pg_temp.mensagem_como(pg_temp.fx('u_admin'), $q$select public.plataforma_salvar_campo('bau',
  '{"chave": "lacre", "rotulo": "Número do lacre", "tipo": "texto"}')$q$),
  'Escolha quando o motorista preenche: no engate, nas entregas ou no desengate.', 'campo de viagem precisa da etapa');
select pg_temp.como(pg_temp.fx('u_admin'), $q$select public.plataforma_salvar_campo('bau',
  '{"chave": "lacre", "rotulo": "Número do lacre", "tipo": "texto", "etapa": "engate", "obrigatorio": true}')$q$);
select is(pg_temp.campo((select x from jsonb_array_elements(pg_temp.como(pg_temp.fx('u_d'), 'select public.situacao_acesso()')
  -> 'empresa' -> 'modalidades') x where x ->> 'codigo' = 'bau'), 'lacre') ->> 'obrigatorio', 'true',
  'o campo novo chega no app do motorista sem APK novo');
select pg_temp.como(pg_temp.fx('u_admin'), $q$select public.plataforma_salvar_campo('bau',
  '{"chave": "lacre", "rotulo": "Lacre", "tipo": "texto", "etapa": "engate", "desativado": true}')$q$);
select is(pg_temp.campo((select x from jsonb_array_elements(pg_temp.como(pg_temp.fx('u_d'), 'select public.situacao_acesso()')
  -> 'empresa' -> 'modalidades') x where x ->> 'codigo' = 'bau'), 'lacre') ->> 'visivel', 'false',
  'campo desativado some dos formulários');
select ok((select count(*) from public.auditoria_plataforma where acao in ('modalidade_criada', 'campo_criado', 'campo_alterado')
  and origem = 'plataforma_app') >= 3, 'o que a Plataforma muda fica no registro');

-- ------------------------------------------------------------- exclusão

select is(pg_temp.como(pg_temp.fx('u_gestor_x'), format('select public.excluir_motorista(%L)', pg_temp.fx('mot_d'))) ->> 'ok',
  'true', 'excluir motorista com viagem e acerto funciona');
select is((select count(*)::int from public.viagens where motorista_id = pg_temp.fx('mot_d'))
  + (select count(*)::int from public.acertos where motorista_id = pg_temp.fx('mot_d'))
  + (select count(*)::int from public.auditoria where registro_id in (pg_temp.fx('viagem_d1'), pg_temp.fx('acerto_d'))), 0,
  'as viagens, os acertos e a auditoria deles vão junto');
select lives_ok(format('select public.expurgar_empresa(%L, %L)', pg_temp.fx('empresa_x'), 'teste'),
  'excluir a empresa com modalidades funciona');
select is((select count(*)::int from public.empresas_modalidades where empresa_id = pg_temp.fx('empresa_x')), 0,
  'as modalidades da empresa vão junto');

select * from finish();
rollback;
