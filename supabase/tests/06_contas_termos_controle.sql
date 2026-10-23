-- Código individual do motorista, termos, recuperação, registros de acesso,
-- controle da plataforma (bloqueio e fim do teste) e exclusão de dados.
begin;
\ir apoio/fixtures.psql

select plan(91);

-- Dois motoristas novos, ainda sem empresa.
insert into fx values
  ('u_e', '10000000-0000-4000-8000-000000000008'),
  ('u_f', '10000000-0000-4000-8000-000000000009');
insert into auth.users (id, email, email_confirmed_at) values
  (pg_temp.fx('u_e'), 'motorista.e@teste.com', now()),
  (pg_temp.fx('u_f'), 'motorista.f@teste.com', now());
select pg_temp.como(pg_temp.fx('u_e'), $q$select public.completar_cadastro('Motorista E', '123.456.789-09')$q$);
select pg_temp.como(pg_temp.fx('u_f'), $q$select public.completar_cadastro('Motorista F', '98765432100')$q$);

create temp table cv (nome text primary key, dados jsonb);
create or replace function pg_temp.cv(p text, c text default 'codigo') returns text language sql as $$
  select dados ->> c from cv where nome = p
$$;

-- ------------------------------------------------ código individual

insert into cv select 'd', pg_temp.como(pg_temp.fx('u_gestor_x'),
  $q$select public.gerar_convite_motorista('Motorista  D', '153.509.460-56')$q$);
insert into cv select 'e', pg_temp.como(pg_temp.fx('u_dono_x'),
  $q$select public.gerar_convite_motorista('Motorista E', '12345678909')$q$);

select ok(pg_temp.cv('d') ~ '^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}$',
  'o painel gera um código de 6 letras e números para o motorista');
select isnt(pg_temp.cv('d'), pg_temp.cv('e'), 'cada motorista recebe um código diferente');
select ok(not exists (select 1 from public.empresas e where e.codigo_entrada in (pg_temp.cv('d'), pg_temp.cv('e'))),
  'o código do motorista nunca é igual ao código de uma empresa');
select is(pg_temp.erro_como(pg_temp.fx('u_a'), $q$select public.gerar_convite_motorista('X Y', '15350946056')$q$),
  '42501', 'motorista não gera código');
select is(pg_temp.mensagem_como(pg_temp.fx('u_gestor_x'), $q$select public.gerar_convite_motorista('Motorista A', '52998224725')$q$),
  'Este motorista já está na empresa.', 'não gera código para quem já está na empresa');
select is((pg_temp.como(pg_temp.fx('u_dono_y'), $q$select to_jsonb(count(*)) from public.convites_motorista$q$))::int, 0,
  'outra empresa não vê os códigos gerados');
select is((pg_temp.como(pg_temp.fx('u_gestor_x'), $q$select to_jsonb(count(*)) from public.convites_motorista$q$))::int, 2,
  'a gestão vê os códigos da própria empresa');
select is((pg_temp.como(pg_temp.fx('u_a'), $q$select to_jsonb(count(*)) from public.convites_motorista$q$))::int, 0,
  'motorista não vê os códigos');

select is(pg_temp.como(pg_temp.fx('u_e'), format('select public.pedir_entrada(%L)', pg_temp.cv('d'))) ->> 'codigo',
  'cpf_diferente', 'o código só serve para o CPF cadastrado pelo gestor');
select is(pg_temp.como(pg_temp.fx('u_d'), format('select public.pedir_entrada(%L)', lower(pg_temp.cv('d')))) ->> 'status',
  'aprovado', 'com o código dele, o motorista entra na empresa na hora');
select is((select empresa_id from public.perfis where id = pg_temp.fx('u_d')), pg_temp.fx('empresa_x'),
  'o perfil fica ligado à empresa');
select is((select nome || ':' || ativo from public.motoristas where perfil_id = pg_temp.fx('u_d')), 'Motorista D:true',
  'o motorista aparece na empresa com o nome cadastrado pelo gestor');
select is(pg_temp.como(pg_temp.fx('u_d'), $q$select to_jsonb(public.motorista_do_usuario() is not null)$q$)::text, 'true',
  'e já pode enviar lançamentos');
select is(pg_temp.como(pg_temp.fx('u_f'), format('select public.pedir_entrada(%L)', pg_temp.cv('d'))) ->> 'codigo',
  'convite_vencido', 'código usado não serve de novo');

insert into cv select 'e2', pg_temp.como(pg_temp.fx('u_gestor_x'),
  $q$select public.gerar_convite_motorista('Motorista E', '12345678909')$q$);
select ok((select cancelado_em is not null from public.convites_motorista where codigo = pg_temp.cv('e')),
  'gerar outro código para o mesmo CPF cancela o anterior');
select is(pg_temp.como(pg_temp.fx('u_e'), format('select public.pedir_entrada(%L)', pg_temp.cv('e'))) ->> 'codigo',
  'convite_vencido', 'código cancelado não serve');
update public.convites_motorista set expira_em = now() - interval '1 minute' where codigo = pg_temp.cv('e2');
select is(pg_temp.como(pg_temp.fx('u_e'), format('select public.pedir_entrada(%L)', pg_temp.cv('e2'))) ->> 'codigo',
  'convite_vencido', 'código vencido não serve');
select ok((select expira_em between now() + interval '6 days 23 hours' and now() + interval '7 days 1 minute'
  from public.convites_motorista where codigo = pg_temp.cv('d')), 'o código vale por 7 dias');

insert into cv select 'f', pg_temp.como(pg_temp.fx('u_gestor_x'),
  $q$select public.gerar_convite_motorista('Motorista F', '98765432100')$q$);
select is(pg_temp.erro_como(pg_temp.fx('u_dono_y'), format('select public.cancelar_convite(%L)', pg_temp.cv('f', 'id'))),
  'P0001', 'outra empresa não cancela o código');
select pg_temp.como(pg_temp.fx('u_gestor_x'), format('select public.cancelar_convite(%L)', pg_temp.cv('f', 'id')));
select is(pg_temp.como(pg_temp.fx('u_f'), format('select public.pedir_entrada(%L)', pg_temp.cv('f'))) ->> 'codigo',
  'convite_vencido', 'o gestor cancela um código');

-- ------------------------------------------------------------ termos

select is(pg_temp.como(pg_temp.fx('u_a'), $q$select public.situacao_acesso() -> 'termos' -> 'aceito'$q$)::text, 'false',
  'quem ainda não aceitou os termos vê o aviso');
select is(pg_temp.mensagem_como(pg_temp.fx('u_a'), $q$select public.aceitar_termos('2020-01-01')$q$),
  'Os termos foram atualizados. Feche e abra o app para ler a versão nova.', 'aceite de versão antiga é recusado');
select pg_temp.como(pg_temp.fx('u_a'), $q$select public.aceitar_termos(public.versao_termos())$q$);
select pg_temp.como(pg_temp.fx('u_a'), $q$select public.aceitar_termos(public.versao_termos())$q$);
select is(pg_temp.como(pg_temp.fx('u_a'), $q$select public.situacao_acesso() -> 'termos' -> 'aceito'$q$)::text, 'true',
  'o aceite fica guardado');
select is((select count(*)::int from public.aceites_termos where perfil_id = pg_temp.fx('u_a')
  and versao = public.versao_termos() and aceito_em is not null), 1, 'com a versão e a data, uma vez só');

-- --------------------------------------------- código de recuperação

insert into cv select 'rec_a', jsonb_build_object('codigo',
  pg_temp.como(pg_temp.fx('u_a'), $q$select to_jsonb(public.gerar_codigo_recuperacao())$q$) #>> '{}');
select ok(pg_temp.cv('rec_a') ~ '^[A-Z2-9]{4}-[A-Z2-9]{4}-[A-Z2-9]{4}$', 'o código de recuperação tem 12 letras e números');
select ok(not exists (select 1 from public.codigos_recuperacao
  where hash like '%' || replace(pg_temp.cv('rec_a'), '-', '') || '%'), 'o código fica guardado só cifrado');
select is(pg_temp.como(pg_temp.fx('u_a'), $q$select public.situacao_acesso() -> 'recuperacao'$q$)::text, 'true',
  'o app sabe que a pessoa já tem código');
select is(public.recuperacao_conferir('529.982.247-25', lower(pg_temp.cv('rec_a')), 'ap1') ->> 'perfil_id',
  pg_temp.fx('u_a')::text, 'CPF e código certos: libera criar a senha nova');
select is(public.recuperacao_conferir('52998224725', 'AAAA-BBBB-CCCC', 'ap2') ->> 'ok', 'false', 'código errado é recusado');
select public.recuperacao_conferir('52998224725', 'AAAA-BBBB-CCCC', 'ap2') from generate_series(1, 4);
select is(public.recuperacao_conferir('52998224725', pg_temp.cv('rec_a'), 'ap3') ->> 'bloqueado', 'true',
  'depois de 5 erros fica bloqueado por 15 minutos');
insert into cv select 'rec_g', jsonb_build_object('codigo',
  pg_temp.como(pg_temp.fx('u_gestor_x'), $q$select to_jsonb(public.gerar_codigo_recuperacao())$q$) #>> '{}');
select is(public.recuperacao_conferir(' GESTOR.X@teste.com', pg_temp.cv('rec_g'), 'ap4') ->> 'papel', 'gestor',
  'gestor recupera com o e-mail e o código');
select is(pg_temp.erro_como(pg_temp.fx('u_a'), $q$select public.recuperacao_conferir('x', 'y', 'z')$q$), '42501',
  'o app não chama a conferência direto (só a Edge Function)');

-- ------------------------------------------------ registros de acesso

select pg_temp.como(pg_temp.fx('u_gestor_x'), $q$select '{}'::jsonb from public.registrar_acesso('gestor')$q$);
select pg_temp.como(pg_temp.fx('u_gestor_x'), $q$select '{}'::jsonb from public.registrar_acesso('gestor')$q$);
select is((select count(*)::int from public.registros_acesso where perfil_id = pg_temp.fx('u_gestor_x')), 1,
  'o acesso fica registrado (um por hora)');
select is(pg_temp.erro_como(pg_temp.fx('u_dono_x'), 'select count(*) from public.registros_acesso'), '42501',
  'ninguém lê os registros de acesso pelo app');

-- ----------------------------------------- controle da plataforma

select public.bloquear_empresa(pg_temp.fx('empresa_x'), 'Teste encerrado.', 30);
select is((pg_temp.como(pg_temp.fx('u_gestor_x'), $q$select to_jsonb(count(*)) from public.fretes$q$))::int, 0,
  'empresa bloqueada: o gestor não vê mais nada');
select is(pg_temp.como(pg_temp.fx('u_gestor_x'), $q$select public.situacao_acesso() -> 'empresa' -> 'bloqueada'$q$)::text,
  'true', 'o app sabe que o acesso foi encerrado');
select is(pg_temp.como(pg_temp.fx('u_dono_x'), $q$select public.situacao_acesso() -> 'empresa' -> 'motivo_bloqueio'$q$) #>> '{}',
  'Teste encerrado.', 'e mostra o motivo');
select is(pg_temp.erro_como(pg_temp.fx('u_a'), format('select public.sincronizar_lote(%L)', '{"itens": []}')), '42501',
  'empresa bloqueada: o motorista não envia nada');
select is(pg_temp.erro_como(pg_temp.fx('u_gestor_x'), $q$select public.gerar_convite_motorista('Fulano', '24681357928')$q$),
  '42501', 'nem cadastra motoristas');
select is((pg_temp.como(pg_temp.fx('u_dono_y'), $q$select to_jsonb(count(*)) from public.fretes$q$))::int, 1,
  'a outra empresa continua normal');
select is(pg_temp.erro_como(pg_temp.fx('u_dono_x'), format('select public.bloquear_empresa(%L)', pg_temp.fx('empresa_y'))),
  '42501', 'só a plataforma bloqueia ou libera (pelo app não dá)');
select public.liberar_empresa(pg_temp.fx('empresa_x'));
select is((pg_temp.como(pg_temp.fx('u_gestor_x'), $q$select to_jsonb(count(*)) from public.fretes$q$))::int, 2,
  'liberada de novo, tudo volta');
select public.liberar_empresa(pg_temp.fx('empresa_x'), now() - interval '1 minute');
select is((pg_temp.como(pg_temp.fx('u_gestor_x'), $q$select to_jsonb(count(*)) from public.fretes$q$))::int, 0,
  'fim do período de teste: o acesso fecha sozinho');
select ok((pg_temp.como(pg_temp.fx('u_gestor_x'), $q$select public.situacao_acesso() -> 'empresa' -> 'excluir_em'$q$) #>> '{}')::timestamptz
  > now() + interval '29 days', 'os dados ficam guardados 30 dias antes de serem apagados');
select public.liberar_empresa(pg_temp.fx('empresa_x'));

-- ------------------------------------------------------- exclusões

select pg_temp.como(pg_temp.fx('u_gestor_x'), format('select public.excluir_motorista(%L)', pg_temp.fx('mot_b')));
select is((select count(*)::int from public.fretes where id = pg_temp.fx('frete_b')), 0, 'excluir o motorista apaga os fretes dele');
select is((select count(*)::int from public.auditoria where registro_id = pg_temp.fx('frete_b')), 0,
  'e não sobra cópia na auditoria');
select is((select count(*)::int from public.motoristas where id = pg_temp.fx('mot_b')), 0, 'o cadastro sai da empresa');
select ok((select empresa_id is null from public.perfis where id = pg_temp.fx('u_b')),
  'a conta dele continua, sem empresa (pode entrar em outra)');
select is((select count(*)::int from public.fretes where id = pg_temp.fx('frete_a')), 1, 'os outros motoristas não são afetados');
select is(pg_temp.mensagem_como(pg_temp.fx('u_dono_y'), format('select public.excluir_motorista(%L)', pg_temp.fx('mot_a'))),
  'Motorista não encontrado.', 'outra empresa não exclui motorista que não é dela');
select is(pg_temp.erro_como(pg_temp.fx('u_a'), format('select public.excluir_motorista(%L)', pg_temp.fx('mot_a'))), '42501',
  'motorista não exclui ninguém');
select is((select count(*)::int from public.registro_exclusoes
  where empresa_id = pg_temp.fx('empresa_x') and tipo = 'motorista' and pedido_por = 'gestor'), 1,
  'a exclusão do motorista deixa um registro: empresa, data e quem pediu (gestor)');
select is((select array_agg(column_name::text order by column_name::text) from information_schema.columns
  where table_schema = 'public' and table_name = 'registro_exclusoes'),
  array['empresa_id', 'id', 'pedido_por', 'quando', 'tipo'], 'o registro não tem nome, CPF, e-mail nem id de pessoa');
select is(pg_temp.erro_como(pg_temp.fx('u_gestor_x'), 'select count(*) from public.registro_exclusoes'), '42501',
  'o registro de exclusões não é lido pelos apps');

select is(pg_temp.como(pg_temp.fx('u_b'), $q$select public.excluir_minha_conta()$q$) ->> 'apagada', 'true',
  'sem empresa, a conta do motorista some na hora');
select is((select count(*)::int from auth.users where id = pg_temp.fx('u_b')), 0, 'inclusive o login');
select is((select count(*)::int from public.registro_exclusoes
  where empresa_id is null and tipo = 'conta_motorista' and pedido_por = 'motorista'), 1,
  'a exclusão da própria conta também deixa registro');

-- Motorista de empresa que exclui a conta (regra de 23/10/2026): o login sai
-- na hora e o CPF fica livre; os lançamentos ficam 15 dias com a empresa.
select is(pg_temp.como(pg_temp.fx('u_a'), $q$select public.excluir_minha_conta()$q$) ->> 'login_apagado', 'true',
  'ligado a uma empresa, a exclusão da conta é aceita');
select is((select count(*)::int from public.perfis where id = pg_temp.fx('u_a'))
  + (select count(*)::int from auth.users where id = pg_temp.fx('u_a')), 0,
  'o login (conta, CPF e e-mail) sai na hora');
select is((select count(*)::int from public.fretes where id = pg_temp.fx('frete_a'))::text
  || ':' || (select coalesce(perfil_id::text, 'sem login') || ':' || ativo from public.motoristas where id = pg_temp.fx('mot_a')),
  '1:sem login:false', 'os lançamentos ficam com a empresa, sem login');
select is(pg_temp.como(pg_temp.fx('u_gestor_x'), format(
  'select to_jsonb(exclusao_pedida_em is not null) from public.motoristas where id = %L', pg_temp.fx('mot_a')))::text, 'true',
  'o gestor vê que ele excluiu a conta');

insert into fx values ('u_a2', '10000000-0000-4000-8000-00000000000a');
insert into auth.users (id, email, email_confirmed_at) values (pg_temp.fx('u_a2'), 'motorista.a2@teste.com', now());
select pg_temp.como(pg_temp.fx('u_a2'), $q$select public.completar_cadastro('Motorista A', '529.982.247-25')$q$);
select is((select cpf from public.perfis where id = pg_temp.fx('u_a2')), '52998224725',
  'o mesmo CPF já cria conta nova na hora');
select ok(pg_temp.mensagem_como(pg_temp.fx('u_gestor_x'), $q$select public.gerar_convite_motorista('Motorista A', '52998224725')$q$)
  like 'Este motorista excluiu a conta. O cadastro antigo fica até __/__ para a empresa guardar o PDF.%',
  'código para quem excluiu a conta: o painel explica o que fazer');
select is(pg_temp.como(pg_temp.fx('u_a2'), format('select public.pedir_entrada(%L)',
  (select codigo_entrada from public.empresas where id = pg_temp.fx('empresa_x')))) ->> 'ok', 'true',
  'a conta nova pede para entrar na empresa');
select ok(pg_temp.mensagem_como(pg_temp.fx('u_gestor_x'), format('select public.decidir_entrada(%L, true)',
  (select id from public.pedidos_entrada where perfil_id = pg_temp.fx('u_a2'))))
  like 'Este motorista excluiu a conta antiga e o cadastro antigo dele ainda está na empresa (fica até __/__%',
  'aprovar com o cadastro antigo ainda lá: o painel explica o que fazer');
select is(pg_temp.erro_como(pg_temp.fx('u_gestor_x'), format(
  'update public.motoristas set ativo = true where id = %L', pg_temp.fx('mot_a'))), '23514',
  'cadastro sem login não é religado');
select is(pg_temp.mensagem_como(pg_temp.fx('u_gestor_x'), format('select public.perfil_para_redefinir(%L)', pg_temp.fx('mot_a'))),
  'Este motorista excluiu a conta. Não tem acesso para redefinir; se ele voltar, cria uma conta nova.',
  'nem tem acesso para redefinir');

update public.motoristas set exclusao_pedida_em = now() - interval '16 days' where id = pg_temp.fx('mot_a');
select is((select valor from public.configuracao_plataforma where chave = 'limpeza_modo'), 'simulacao',
  'a limpeza diária começa em modo simulação');
select is(public.limpeza_diaria() -> 'motoristas' -> 0 ->> 'motorista_id', pg_temp.fx('mot_a')::text,
  'em simulação, a limpeza lista o motorista que apagaria');
select is((select count(*)::int from public.motoristas where id = pg_temp.fx('mot_a'))
  + (select count(*)::int from public.fretes where id = pg_temp.fx('frete_a')), 2, 'e não apaga nada');
select is((select modo || ':' || (resultado -> 'motoristas' -> 0 ->> 'motorista_id') from public.limpeza_execucoes
  order by id desc limit 1), 'simulacao:' || pg_temp.fx('mot_a'), 'a lista fica guardada para conferir');
select is(pg_temp.erro_como(pg_temp.fx('u_dono_x'), $q$select public.definir_modo_limpeza('valendo')$q$), '42501',
  'só a plataforma confirma a limpeza de verdade');
select public.definir_modo_limpeza('valendo');
select public.limpeza_diaria();
select is((select count(*)::int from public.motoristas where id = pg_temp.fx('mot_a'))
  + (select count(*)::int from public.fretes where id = pg_temp.fx('frete_a')), 0,
  'depois de 15 dias, os lançamentos dele são apagados sozinhos');
select is((select count(*)::int from public.perfis where id = pg_temp.fx('u_a2')), 1,
  'e a conta nova continua');
select is(pg_temp.como(pg_temp.fx('u_gestor_x'), format('select public.decidir_entrada(%L, true)',
  (select id from public.pedidos_entrada where perfil_id = pg_temp.fx('u_a2')))) ->> 'status', 'aprovado',
  'sem o cadastro antigo, a conta nova entra na empresa');
select is((select count(*)::int from public.registro_exclusoes
  where empresa_id = pg_temp.fx('empresa_x') and tipo = 'motorista' and pedido_por = 'limpeza_diaria'), 1,
  'a limpeza deixa o registro de cada exclusão');

select is(pg_temp.erro_como(pg_temp.fx('u_gestor_x'), $q$select public.excluir_minha_empresa('Transportes X')$q$), '42501',
  'gestor não exclui a empresa');
select is(pg_temp.mensagem_como(pg_temp.fx('u_dono_x'), $q$select public.excluir_minha_empresa('Outra')$q$),
  'Para confirmar, digite o nome da empresa igual aparece na tela.', 'precisa digitar o nome da empresa');
select pg_temp.como(pg_temp.fx('u_dono_x'), $q$select public.excluir_minha_empresa('  transportes   x ')$q$);
select is((select nome from public.empresas where id = pg_temp.fx('empresa_x')), 'Empresa excluída',
  'o dono exclui a empresa: fica só uma linha sem dados');
select is((select count(*)::int from public.perfis where empresa_id = pg_temp.fx('empresa_x'))
  + (select count(*)::int from auth.users where id in (pg_temp.fx('u_dono_x'), pg_temp.fx('u_gestor_x'), pg_temp.fx('u_d')))
  + (select count(*)::int from public.caminhoes where empresa_id = pg_temp.fx('empresa_x'))
  + (select count(*)::int from public.motoristas where empresa_id = pg_temp.fx('empresa_x'))
  + (select count(*)::int from public.categorias_gasto where empresa_id = pg_temp.fx('empresa_x'))
  + (select count(*)::int from public.acessos_autorizados where empresa_id = pg_temp.fx('empresa_x'))
  + (select count(*)::int from public.auditoria where empresa_id = pg_temp.fx('empresa_x')), 0,
  'donos, gestores, motoristas, logins, caminhões e auditoria são apagados');
select is((select count(*)::int from public.registros_acesso where perfil_id = pg_temp.fx('u_gestor_x')), 1,
  'os registros de acesso ficam (obrigação legal de 6 meses)');
select is((select count(*)::int from public.registro_exclusoes
  where empresa_id = pg_temp.fx('empresa_x') and tipo = 'empresa' and pedido_por = 'dono'), 1,
  'a exclusão da empresa pelo dono deixa registro');
select is((select count(*)::int from public.registro_exclusoes where empresa_id = pg_temp.fx('empresa_x')), 4,
  'e os registros anteriores da empresa continuam depois da exclusão');
select is((pg_temp.como(pg_temp.fx('u_dono_y'), $q$select to_jsonb(count(*)) from public.fretes$q$))::int, 1,
  'a outra empresa não perde nada');

select public.bloquear_empresa(pg_temp.fx('empresa_y'), null, 0);
select is(public.limpeza_diaria('simulacao') -> 'empresas' ->> 0, pg_temp.fx('empresa_y')::text,
  'em simulação, lista a empresa com prazo vencido');
select is((select count(*)::int from public.fretes where empresa_id = pg_temp.fx('empresa_y')), 1,
  'sem apagar os dados dela');
select public.limpeza_diaria();
select ok((select excluida_em is not null from public.empresas where id = pg_temp.fx('empresa_y')),
  'prazo vencido: a limpeza diária apaga a empresa sozinha');
select is((select count(*)::int from public.fretes where empresa_id = pg_temp.fx('empresa_y')), 0, 'com todos os dados');
select is((select count(*)::int from public.registro_exclusoes
  where empresa_id = pg_temp.fx('empresa_y') and tipo = 'empresa' and pedido_por = 'limpeza_diaria'), 1,
  'e deixa o registro da exclusão');
select is(pg_temp.erro_como(pg_temp.fx('u_e'), $q$select public.limpeza_diaria()$q$), '42501', 'o app não chama a limpeza');
select is(pg_temp.erro_como(pg_temp.fx('u_e'), 'select count(*) from public.limpeza_execucoes'), '42501',
  'nem lê o resultado da limpeza');

select * from finish();
rollback;
