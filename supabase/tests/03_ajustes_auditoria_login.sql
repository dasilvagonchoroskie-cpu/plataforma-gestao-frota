-- Ajustes do gestor, auditoria, limite do plano, troca pelo gestor e login por CPF.
begin;
\ir apoio/fixtures.psql

create or replace function pg_temp.ajustar(p_uid uuid, p_tabela text, p_registro uuid, p_campo text, p_valor jsonb,
  p_autor uuid default null) returns text language sql as $$
  select pg_temp.erro_como(p_uid, format($q$insert into public.ajustes_gestor
    (id, empresa_id, tabela_alvo, registro_id, campo, valor_novo, motivo, autor_id)
    values (gen_random_uuid(), public.empresa_do_usuario(), %L, %L, %L, %L, 'Conferido com o recibo', %s)$q$,
    p_tabela, p_registro, p_campo, p_valor, coalesce(quote_literal(p_autor), 'auth.uid()')))
$$;

select plan(47);

-- Ajustes
select is(pg_temp.ajustar(pg_temp.fx('u_gestor_x'), 'fretes', pg_temp.fx('frete_a'), 'saldo_centavos', '200000'), 'ok',
  'gestor corrige o saldo do frete');
select is((select valor_antigo from public.ajustes_gestor where registro_id = pg_temp.fx('frete_a')), '195000'::jsonb,
  'o ajuste guarda o valor original');
select is(pg_temp.ajustar(pg_temp.fx('u_dono_x'), 'fretes', pg_temp.fx('frete_a'), 'saldo_centavos', '205000'), 'ok',
  'dono corrige de novo');
select is((select valor_antigo from public.ajustes_gestor where registro_id = pg_temp.fx('frete_a') order by criado_em desc limit 1),
  '200000'::jsonb, 'o segundo ajuste guarda o valor do ajuste anterior');
select is(pg_temp.como(pg_temp.fx('u_gestor_x'), format('select to_jsonb(saldo_centavos) from public.fretes_efetivos where id = %L',
  pg_temp.fx('frete_a'))), '205000'::jsonb, 'o valor efetivo é o do último ajuste');
select is(pg_temp.como(pg_temp.fx('u_gestor_x'), format('select to_jsonb(campos_ajustados) from public.fretes_efetivos where id = %L',
  pg_temp.fx('frete_a'))), '["saldo_centavos"]'::jsonb, 'a tela sabe qual campo foi ajustado');
select is((select saldo_centavos from public.fretes where id = pg_temp.fx('frete_a')), 195000::bigint,
  'o lançamento original do motorista não muda');
select is(pg_temp.ajustar(pg_temp.fx('u_gestor_x'), 'fretes', pg_temp.fx('frete_a'), 'motorista_id', to_jsonb(pg_temp.fx('mot_b'))),
  '23514', 'não dá para trocar o motorista de um lançamento por ajuste');
select is(pg_temp.ajustar(pg_temp.fx('u_gestor_x'), 'fretes', pg_temp.fx('frete_a'), 'empresa_id', to_jsonb(pg_temp.fx('empresa_y'))),
  '23514', 'não dá para trocar a empresa por ajuste');
select is(pg_temp.ajustar(pg_temp.fx('u_gestor_x'), 'fretes', pg_temp.fx('frete_a'), 'saldo_centavos', '"muito"'),
  '23514', 'valor de dinheiro precisa ser número');
select is(pg_temp.ajustar(pg_temp.fx('u_gestor_x'), 'fretes', pg_temp.fx('frete_a'), 'saldo_centavos', '10.5'),
  '23514', 'centavos precisam ser inteiros');
select is(pg_temp.ajustar(pg_temp.fx('u_gestor_x'), 'fretes', pg_temp.fx('frete_a'), 'percentual_comissao', '120'),
  '23514', 'comissão acima de 100 é recusada');
select is(pg_temp.ajustar(pg_temp.fx('u_gestor_x'), 'fretes', pg_temp.fx('frete_c'), 'saldo_centavos', '1'),
  '23503', 'gestor X não ajusta frete da empresa Y');
select is(pg_temp.ajustar(pg_temp.fx('u_gestor_x'), 'fretes', pg_temp.fx('frete_a'), 'saldo_centavos', '1', pg_temp.fx('u_dono_x')),
  '42501', 'o ajuste sempre leva o nome de quem fez');
select is(pg_temp.ajustar(pg_temp.fx('u_a'), 'fretes', pg_temp.fx('frete_a'), 'saldo_centavos', '1'),
  '42501', 'motorista não cria ajuste');
select is(pg_temp.erro_como(pg_temp.fx('u_gestor_x'), $q$update public.ajustes_gestor set motivo = 'outro'$q$),
  '42501', 'ajuste feito não pode ser alterado');
select is(pg_temp.ajustar(pg_temp.fx('u_gestor_x'), 'fretes', pg_temp.fx('frete_a'), 'caminhao_id', to_jsonb(pg_temp.fx('cam_y1'))),
  '23503', 'não dá para pôr o frete num caminhão de outra empresa');
select is(pg_temp.ajustar(pg_temp.fx('u_gestor_x'), 'fretes', pg_temp.fx('frete_a'), 'caminhao_id', to_jsonb(pg_temp.fx('cam_x2'))),
  'ok', 'lançou no caminhão errado: gestor corrige o caminhão por ajuste');
select is(pg_temp.como(pg_temp.fx('u_gestor_x'), format('select to_jsonb(caminhao_id) from public.fretes_efetivos where id = %L',
  pg_temp.fx('frete_a'))), to_jsonb(pg_temp.fx('cam_x2')), 'o frete passa a contar no caminhão certo');
select is(pg_temp.como(pg_temp.fx('u_a'), 'select to_jsonb(count(*)) from public.ajustes_gestor'), '3'::jsonb,
  'o motorista vê os ajustes dos próprios lançamentos');
select is(pg_temp.como(pg_temp.fx('u_b'), 'select to_jsonb(count(*)) from public.ajustes_gestor'), '0'::jsonb,
  'outro motorista não vê esses ajustes');

-- Auditoria
select is((select count(*)::int from public.auditoria where tabela = 'ajustes_gestor' and autor_id = pg_temp.fx('u_gestor_x')), 2,
  'cada ajuste do gestor fica na auditoria com o nome dele');
select ok(pg_temp.como(pg_temp.fx('u_gestor_x'), 'select to_jsonb(count(*) > 0) from public.auditoria')::boolean,
  'o gestor consulta a auditoria da empresa');
select is(pg_temp.como(pg_temp.fx('u_dono_y'), format('select to_jsonb(count(*)) from public.auditoria where registro_id = %L',
  pg_temp.fx('frete_a'))), '0'::jsonb, 'empresa Y não vê a auditoria da X');
select is(pg_temp.erro_como(pg_temp.fx('u_gestor_x'), format($q$insert into public.auditoria (empresa_id, acao, tabela, registro_id)
  values (%L, 'x', 'y', gen_random_uuid())$q$, pg_temp.fx('empresa_x'))), '42501', 'ninguém escreve na auditoria na mão');

-- Regras de acerto e dados da empresa: só o dono
select pg_temp.como(pg_temp.fx('u_gestor_x'), $q$update public.empresas set vale_desconta_do_liquido = false returning '{}'::jsonb$q$);
select is((select vale_desconta_do_liquido from public.empresas where id = pg_temp.fx('empresa_x')), true,
  'gestor não muda as regras da empresa');
select pg_temp.como(pg_temp.fx('u_dono_x'), $q$update public.empresas set vale_desconta_do_liquido = false returning '{}'::jsonb$q$);
select is((select vale_desconta_do_liquido from public.empresas where id = pg_temp.fx('empresa_x')), false,
  'dono muda as regras da empresa');
select is(pg_temp.erro_como(pg_temp.fx('u_dono_x'), $q$update public.empresas set codigo_entrada = 'AAAAAA'$q$), '42501',
  'o código só muda pela função própria');
select is(pg_temp.erro_como(pg_temp.fx('u_dono_x'), $q$update public.empresas set status = 'ativa'$q$), '42501',
  'o dono não muda o status do plano (isso é da plataforma)');

-- Limite de caminhões do plano (5 na empresa X, já tem 2)
select is(pg_temp.erro_como(pg_temp.fx('u_gestor_x'), $q$insert into public.caminhoes (id, empresa_id, placa, confirmado) values
  (gen_random_uuid(), public.empresa_do_usuario(), 'AAA1A11', true),
  (gen_random_uuid(), public.empresa_do_usuario(), 'AAA1A12', true),
  (gen_random_uuid(), public.empresa_do_usuario(), 'AAA1A13', true)$q$), 'ok', 'cadastra até o limite do plano');
select is(pg_temp.mensagem_como(pg_temp.fx('u_gestor_x'), $q$insert into public.caminhoes (id, empresa_id, placa, confirmado)
  values (gen_random_uuid(), public.empresa_do_usuario(), 'AAA1A14', true)$q$),
  'O plano da empresa permite até 5 caminhões ativos', 'passou do limite: mensagem clara');
select is(pg_temp.erro_como(pg_temp.fx('u_gestor_x'), $q$insert into public.caminhoes (id, empresa_id, placa, confirmado)
  values (gen_random_uuid(), public.empresa_do_usuario(), 'AAA-1A15', true)$q$), '23514', 'placa com hífen não é gravada (o app normaliza)');

-- Gestor troca o caminhão do motorista; dois motoristas no mesmo caminhão
select is(pg_temp.como(pg_temp.fx('u_gestor_x'), format('select public.definir_caminhao_atual(%L, %L) -> %L',
  pg_temp.fx('mot_a'), pg_temp.fx('cam_x1'), 'ok')), 'true'::jsonb, 'gestor define o caminhão atual do motorista A');
select is(pg_temp.como(pg_temp.fx('u_gestor_x'), format('select public.definir_caminhao_atual(%L, %L) -> %L',
  pg_temp.fx('mot_b'), pg_temp.fx('cam_x1'), 'ok')), 'true'::jsonb, 'dois motoristas no mesmo caminhão é permitido');
select is((select registrado_por from public.uso_caminhao where motorista_id = pg_temp.fx('mot_a')), pg_temp.fx('u_gestor_x'),
  'a troca feita pelo gestor fica com o nome dele');
select is(pg_temp.erro_como(pg_temp.fx('u_a'), format('select public.definir_caminhao_atual(%L, %L)',
  pg_temp.fx('mot_b'), pg_temp.fx('cam_x2'))), '42501', 'motorista não troca o caminhão de outro');

-- Redefinir acesso (usado pela Edge Function com o token do gestor)
select is(pg_temp.como(pg_temp.fx('u_gestor_x'), format('select public.perfil_para_redefinir(%L) -> %L',
  pg_temp.fx('mot_a'), 'email')), '"motorista.a@teste.com"'::jsonb, 'gestor pode redefinir o acesso do motorista dele');
select is(pg_temp.mensagem_como(pg_temp.fx('u_gestor_x'), format('select public.perfil_para_redefinir(%L)',
  pg_temp.fx('mot_c'))), 'Motorista não encontrado.', 'gestor não redefine motorista de outra empresa');

-- Funções só do servidor
select is(pg_temp.erro_como(pg_temp.fx('u_dono_x'), $q$select public.criar_empresa('Nova', 'a@b.com')$q$), '42501',
  'só a plataforma cria empresa');
select is(pg_temp.erro_como(pg_temp.fx('u_a'), $q$select public.login_cpf_preparar('52998224725', 'x')$q$), '42501',
  'o app não consulta e-mail por CPF');

-- Login por CPF: 5 erros seguidos bloqueiam por 15 minutos
select public.login_cpf_registrar('52998224725', 'aparelho-1', false) from generate_series(1, 4);
select is(public.login_cpf_preparar('529.982.247-25', 'aparelho-1') -> 'email', '"motorista.a@teste.com"'::jsonb,
  'com 4 erros ainda deixa tentar');
select public.login_cpf_registrar('52998224725', 'aparelho-1', false);
select is(public.login_cpf_preparar('52998224725', 'aparelho-1') -> 'bloqueado', 'true'::jsonb,
  'no quinto erro o CPF fica bloqueado');
select is(public.login_cpf_preparar('52998224725', 'aparelho-2') -> 'bloqueado', 'true'::jsonb,
  'trocar de celular não fura o bloqueio do CPF');
select is(public.login_cpf_preparar('11144477735', 'aparelho-1') -> 'bloqueado', 'true'::jsonb,
  'o celular que errou 5 vezes também fica bloqueado para outros CPFs');
select is(public.login_cpf_preparar('11144477735', 'aparelho-3') -> 'bloqueado', 'false'::jsonb,
  'outro CPF em outro celular entra normal');
select is(public.login_cpf_preparar('00000000191', 'aparelho-3') ->> 'email', null,
  'CPF sem cadastro não devolve e-mail (a mensagem de erro é sempre a mesma)');
select public.login_cpf_registrar('11144477735', 'aparelho-4', false) from generate_series(1, 4);
select public.login_cpf_registrar('11144477735', 'aparelho-4', true);
select public.login_cpf_registrar('11144477735', 'aparelho-4', false);
select is(public.login_cpf_preparar('11144477735', 'aparelho-4') -> 'bloqueado', 'false'::jsonb,
  'acertar a senha zera a contagem de erros');

select * from finish();
rollback;
