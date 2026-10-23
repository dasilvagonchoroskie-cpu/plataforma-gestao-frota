-- Motorista que sai da empresa (regra aprovada em 23/10/2026): o login fica
-- livre na hora para outra empresa ou para voltar; a empresa fica com o
-- registro (nome, CPF e lançamentos), sem o e-mail; quem volta começa um
-- cadastro novo.
begin;
\ir apoio/fixtures.psql

select plan(24);

-- O motorista B usa o celular e ele mesmo registrou o caminhão.
insert into public.dispositivos (id, empresa_id, perfil_id, apelido)
values (gen_random_uuid(), pg_temp.fx('empresa_x'), pg_temp.fx('u_b'), 'Celular do B');
select public.registrar_uso_caminhao(gen_random_uuid(), pg_temp.fx('empresa_x'), pg_temp.fx('mot_b'),
  pg_temp.fx('cam_x2'), now() - interval '3 days', pg_temp.fx('u_b'));
select ok(exists (select 1 from public.auditoria where tabela = 'motoristas' and registro_id = pg_temp.fx('mot_b')
  and depois ? 'email'), 'antes de sair, o histórico do cadastro tem o e-mail');

-- ------------------------------------------------------ a empresa desliga

select is(pg_temp.erro_como(pg_temp.fx('u_gestor_x'), format(
  'update public.motoristas set ativo = false where id = %L', pg_temp.fx('mot_b'))), 'ok',
  'o gestor desliga o motorista');
select is((select empresa_id from public.perfis where id = pg_temp.fx('u_b')), null,
  'o login dele fica livre na hora');
select is((select nome || ':' || cpf || ':' || coalesce(perfil_id::text, 'sem login') || ':' || ativo
  from public.motoristas where id = pg_temp.fx('mot_b')), 'Motorista B:11144477735:sem login:false',
  'o registro fica com o nome e o CPF, sem login');
select is((select count(*)::int from public.fretes where motorista_id = pg_temp.fx('mot_b')), 1,
  'e com os lançamentos');
select is((select email from public.motoristas where id = pg_temp.fx('mot_b')), null, 'o e-mail sai do registro');
select is((select count(*)::int from public.auditoria where tabela = 'motoristas' and registro_id = pg_temp.fx('mot_b')
  and (antes ? 'email' or depois ? 'email')), 0, 'e do histórico do cadastro');
select ok((select desligado_em is not null from public.motoristas where id = pg_temp.fx('mot_b')),
  'a data em que ele saiu fica marcada');
select is((select count(*)::int from public.uso_caminhao where motorista_id = pg_temp.fx('mot_b')
  and registrado_por is null), 1, 'o uso do caminhão fica, sem o login de quem registrou');
select is((select count(*)::int from public.dispositivos where perfil_id = pg_temp.fx('u_b')), 0,
  'os celulares dele saem da empresa');
select is((pg_temp.como(pg_temp.fx('u_b'), 'select to_jsonb(count(*)) from public.fretes'))::int, 0,
  'ele não vê mais nada da empresa');
select is((pg_temp.como(pg_temp.fx('u_gestor_x'), format('select to_jsonb(count(*)) from public.motoristas where id = %L',
  pg_temp.fx('mot_b'))))::int, 1, 'a empresa continua vendo o registro');
select is(pg_temp.erro_como(pg_temp.fx('u_gestor_x'), format(
  'update public.motoristas set ativo = true where id = %L', pg_temp.fx('mot_b'))), '23514',
  'registro sem login não é religado');
select is(pg_temp.mensagem_como(pg_temp.fx('u_gestor_x'), format('select public.perfil_para_redefinir(%L)', pg_temp.fx('mot_b'))),
  'Este motorista não tem mais login na empresa (saiu ou excluiu a conta). Se ele voltar, gere um código novo para ele.',
  'nem tem acesso para redefinir');

-- ------------------------------------------------ vai para outra empresa

select is(pg_temp.como(pg_temp.fx('u_b'), format('select public.pedir_entrada(%L)',
  (select codigo_entrada from public.empresas where id = pg_temp.fx('empresa_y')))) ->> 'status', 'pendente',
  'com o mesmo login, ele pede para entrar em outra empresa');
select is(pg_temp.como(pg_temp.fx('u_dono_y'), format('select public.decidir_entrada(%L, true)',
  (select id from public.pedidos_entrada where perfil_id = pg_temp.fx('u_b') and empresa_id = pg_temp.fx('empresa_y'))))
  ->> 'status', 'aprovado', 'e a outra empresa aprova');
select is((select count(*)::int from public.motoristas where perfil_id = pg_temp.fx('u_b')
  and empresa_id = pg_temp.fx('empresa_y') and ativo), 1, 'ele trabalha na empresa nova');
select is((pg_temp.como(pg_temp.fx('u_gestor_x'), format('select to_jsonb(count(*)) from public.motoristas where cpf = %L',
  '11144477735')))::int, 1, 'a empresa antiga só tem o registro dele');

-- ------------------------------------------ volta para a primeira empresa

update public.motoristas set ativo = false where perfil_id = pg_temp.fx('u_b');
insert into fx select 'conv_b', (pg_temp.como(pg_temp.fx('u_gestor_x'),
  $q$select public.gerar_convite_motorista('Motorista B', '111.444.777-35')$q$) ->> 'id')::uuid;
select ok(pg_temp.fx('conv_b') is not null, 'para quem já saiu, o painel gera um código novo');
select is(pg_temp.como(pg_temp.fx('u_b'), format('select public.pedir_entrada(%L)',
  (select codigo from public.convites_motorista where id = pg_temp.fx('conv_b')))) ->> 'status', 'aprovado',
  'com o código, ele volta na hora');
select is((select count(*)::int from public.motoristas where empresa_id = pg_temp.fx('empresa_x') and cpf = '11144477735'), 2,
  'volta com um cadastro novo; o registro antigo fica separado');
select is((select count(*)::int from public.fretes f join public.motoristas m on m.id = f.motorista_id
  where m.perfil_id = pg_temp.fx('u_b')), 0, 'o cadastro novo começa do zero');
select is(pg_temp.mensagem_como(pg_temp.fx('u_gestor_x'), $q$select public.gerar_convite_motorista('Motorista B', '11144477735')$q$),
  'Este motorista já está na empresa.', 'enquanto ele está na empresa, não gera outro código');
select is(pg_temp.como(pg_temp.fx('u_b'), 'select to_jsonb(public.motorista_do_usuario())') #>> '{}',
  (select id::text from public.motoristas where perfil_id = pg_temp.fx('u_b')), 'e envia os lançamentos no cadastro novo');

select * from finish();
rollback;
