-- Auditoria de segurança do banco (22/10/2026).
--
-- Confere de forma geral, para TODAS as tabelas e funções do schema public
-- (inclusive as que forem criadas no futuro):
--   - RLS ligado em toda tabela e visões que respeitam o RLS de quem consulta;
--   - quem não entrou (anon) não lê nem grava nada e não executa nenhuma função;
--   - nenhuma função liberada para todos (PUBLIC) e toda função com dono
--     (SECURITY DEFINER) com search_path fixo;
--   - objetos novos já nascem fechados (permissões padrão);
--   - uma empresa nunca vê dados de outra e um motorista não vê os de outro;
--   - empresa bloqueada (acesso encerrado) não vê nem grava mais nada
--     (empresa com status 'suspensa' lê e não envia: teste 02);
--   - o registro das ações da plataforma (sem dado pessoal, só inclusão);
--   - IP verdadeiro e regra de senha.
begin;
\ir apoio/fixtures.psql

select plan(39);

-- --------------------------------------------------- estrutura e permissões

select is(array(
  select c.relname::text from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind in ('r', 'p') and not c.relrowsecurity order by 1),
  '{}'::text[], 'RLS ligado em todas as tabelas');

select is(array(
  select c.relname::text from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind = 'v'
    and not coalesce('security_invoker=true' = any(c.reloptions), false) order by 1),
  '{}'::text[], 'todas as visões respeitam o RLS de quem consulta (security_invoker)');

select is(array(
  select c.relname::text from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind in ('r', 'p', 'v', 'm')
    and (has_table_privilege('anon', c.oid, 'select') or has_table_privilege('anon', c.oid, 'insert')
      or has_table_privilege('anon', c.oid, 'update') or has_table_privilege('anon', c.oid, 'delete'))
  order by 1),
  '{}'::text[], 'quem não entrou (anon) não tem permissão em nenhuma tabela ou visão');

select is(array(
  select c.relname::text from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and case when c.relkind = 'S' then has_sequence_privilege('anon', c.oid, 'usage') else false end
  order by 1),
  '{}'::text[], 'anon não usa nenhuma sequência');

select is(array(
  select p.proname::text from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and has_function_privilege('anon', p.oid, 'execute') order by 1),
  '{}'::text[], 'anon não executa nenhuma função do schema public');

select is(array(
  select p.proname::text from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and exists (
    select 1 from aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
    where a.grantee = 0 and a.privilege_type = 'EXECUTE')
  order by 1),
  '{}'::text[], 'nenhuma função liberada para todos (PUBLIC)');

select is(array(
  select p.proname::text from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.prosecdef
    and not exists (select 1 from unnest(coalesce(p.proconfig, '{}')) cfg where cfg like 'search_path=%')
  order by 1),
  '{}'::text[], 'toda função SECURITY DEFINER tem search_path fixo');

select is(array(
  select c.relname::text from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relname in ('tentativas_acesso', 'codigos_recuperacao', 'registros_acesso',
    'registro_exclusoes', 'configuracao_plataforma', 'limpeza_execucoes', 'auditoria_plataforma',
    'admins_plataforma', 'senhas_provisorias')
    and (has_table_privilege('authenticated', c.oid, 'select') or has_table_privilege('authenticated', c.oid, 'insert'))
  order by 1),
  '{}'::text[], 'o app não lê nem grava as tabelas internas (tentativas, códigos, registros, auditoria)');

-- Objetos novos já nascem fechados para anon e PUBLIC.
create table public.teste_permissao_padrao (id int);
create function public.teste_funcao_padrao() returns int language sql as 'select 1';
select ok(not has_table_privilege('anon', 'public.teste_permissao_padrao', 'select')
  and not has_function_privilege('anon', 'public.teste_funcao_padrao()', 'execute')
  and not exists (select 1 from aclexplode(coalesce(
    (select proacl from pg_proc where proname = 'teste_funcao_padrao'),
    acldefault('f', (select proowner from pg_proc where proname = 'teste_funcao_padrao')))) a
    where a.grantee = 0),
  'tabela e função novas nascem fechadas para anon e PUBLIC');
drop table public.teste_permissao_padrao;
drop function public.teste_funcao_padrao();

-- ------------------------------------------------ isolamento entre empresas

-- Tabelas e visões com empresa_id, e as que têm dados da empresa Y.
create temp table tabs as
  select c.relname::text as nome,
         exists (select 1 from information_schema.columns ic where ic.table_schema = 'public'
                 and ic.table_name = c.relname and ic.column_name = 'motorista_id') as tem_motorista
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind in ('r', 'p', 'v')
    and has_table_privilege('authenticated', c.oid, 'select')  -- as internas já foram conferidas acima
    and exists (select 1 from information_schema.columns ic where ic.table_schema = 'public'
                and ic.table_name = c.relname and ic.column_name = 'empresa_id');
grant select on tabs to authenticated;

create or replace function pg_temp.vazamento(p_uid uuid, p_empresa uuid) returns text[] language plpgsql as $$
declare
  t record;
  n bigint;
  r text[] := '{}';
begin
  for t in select nome from tabs order by nome loop
    n := (pg_temp.como(p_uid, format('select to_jsonb(count(*)) from public.%I where empresa_id is distinct from %L',
      t.nome, p_empresa)))::text::bigint;
    if n > 0 then r := r || (t.nome || '=' || n); end if;
  end loop;
  return r;
end;
$$;

select ok((select count(*) from tabs) >= 15, 'há pelo menos 15 tabelas e visões com empresa_id na conferência');
select ok((select count(*) from public.motoristas where empresa_id = pg_temp.fx('empresa_y')) > 0
  and (select count(*) from public.fretes where empresa_id = pg_temp.fx('empresa_y')) > 0
  and (select count(*) from public.caminhoes where empresa_id = pg_temp.fx('empresa_y')) > 0,
  'a empresa Y tem motorista, caminhão e frete (o teste de vazamento tem o que vazar)');
select is(pg_temp.vazamento(pg_temp.fx('u_dono_x'), pg_temp.fx('empresa_x')), '{}'::text[],
  'o dono de X não vê nenhuma linha de outra empresa em nenhuma tabela');
select is(pg_temp.vazamento(pg_temp.fx('u_gestor_x'), pg_temp.fx('empresa_x')), '{}'::text[],
  'o gestor de X não vê nenhuma linha de outra empresa em nenhuma tabela');
select is(pg_temp.vazamento(pg_temp.fx('u_a'), pg_temp.fx('empresa_x')), '{}'::text[],
  'o motorista A não vê nenhuma linha de outra empresa em nenhuma tabela');
select is(pg_temp.vazamento(pg_temp.fx('u_dono_y'), pg_temp.fx('empresa_y')), '{}'::text[],
  'o dono de Y não vê nenhuma linha de outra empresa em nenhuma tabela');

-- Motorista A não vê lançamentos do motorista B (mesma empresa).
create or replace function pg_temp.de_outro_motorista(p_uid uuid, p_motorista uuid) returns text[] language plpgsql as $$
declare
  t record;
  n bigint;
  r text[] := '{}';
begin
  for t in select nome from tabs where tem_motorista order by nome loop
    n := (pg_temp.como(p_uid, format('select to_jsonb(count(*)) from public.%I where motorista_id is distinct from %L',
      t.nome, p_motorista)))::text::bigint;
    if n > 0 then r := r || (t.nome || '=' || n); end if;
  end loop;
  return r;
end;
$$;
select ok((select count(*) from fretes where motorista_id = pg_temp.fx('mot_b')) > 0, 'o motorista B tem frete');
select is(pg_temp.de_outro_motorista(pg_temp.fx('u_a'), pg_temp.fx('mot_a')), '{}'::text[],
  'o motorista A não vê lançamentos de outro motorista');
select is(pg_temp.como(pg_temp.fx('u_a'), 'select to_jsonb(count(*)) from public.motoristas')::text, '1',
  'o motorista vê só o próprio cadastro de motorista');

-- Sem login: nenhuma tabela responde.
create or replace function pg_temp.anon_le() returns text[] language plpgsql as $$
declare
  t record;
  r text[] := '{}';
begin
  for t in select c.relname::text as nome from pg_class c join pg_namespace n on n.oid = c.relnamespace
           where n.nspname = 'public' and c.relkind in ('r', 'p', 'v') order by 1 loop
    begin
      perform set_config('request.jwt.claims', '{"role":"anon"}', true);
      execute 'set local role anon';
      execute format('select 1 from public.%I limit 1', t.nome);
      execute 'reset role';
      r := r || t.nome;
    exception when insufficient_privilege then
      execute 'reset role';
    end;
  end loop;
  perform set_config('request.jwt.claims', '', true);
  return r;
end;
$$;
select is(pg_temp.anon_le(), '{}'::text[], 'sem login, toda tabela e visão responde "sem permissão"');

-- Empresa bloqueada: ninguém dela vê mais nada (fora o próprio perfil e o próprio pedido de entrada).
select public.bloquear_empresa(pg_temp.fx('empresa_x'), 'Teste de suspensão', 30);
create or replace function pg_temp.ve_algo(p_uid uuid) returns text[] language plpgsql as $$
declare
  t record;
  n bigint;
  r text[] := '{}';
begin
  for t in select nome from tabs order by nome loop
    n := (pg_temp.como(p_uid, format(
      'select to_jsonb(count(*)) from public.%I where %s', t.nome,
      case t.nome when 'perfis' then 'id <> auth.uid()'
                  when 'pedidos_entrada' then 'perfil_id <> auth.uid()' else 'true' end)))::text::bigint;
    if n > 0 then r := r || (t.nome || '=' || n); end if;
  end loop;
  return r;
end;
$$;
select is(pg_temp.ve_algo(pg_temp.fx('u_dono_x')), '{}'::text[], 'empresa bloqueada: o dono não vê mais nada');
select is(pg_temp.ve_algo(pg_temp.fx('u_gestor_x')), '{}'::text[], 'empresa bloqueada: o gestor não vê mais nada');
select is(pg_temp.ve_algo(pg_temp.fx('u_a')), '{}'::text[], 'empresa bloqueada: o motorista não vê mais nada');
select isnt(pg_temp.erro_como(pg_temp.fx('u_gestor_x'), format($q$
  insert into public.caminhoes (id, empresa_id, placa, modelo, confirmado)
  values (gen_random_uuid(), %L, 'BLQ1A23', 'Teste', true) $q$, pg_temp.fx('empresa_x'))), 'ok',
  'empresa bloqueada: o gestor não cadastra nada');
select is((select count(*)::int from public.fretes where empresa_id = pg_temp.fx('empresa_x')
  and id not in (pg_temp.fx('frete_a'), pg_temp.fx('frete_b'))), 0, 'antes do envio: só os fretes do teste');
select pg_temp.erro_como(pg_temp.fx('u_a'), format('select public.sincronizar_lote(%L)',
  jsonb_build_object('itens', jsonb_build_array(pg_temp.frete(gen_random_uuid(), pg_temp.fx('cam_x1'))))));
select is((select count(*)::int from public.fretes where empresa_id = pg_temp.fx('empresa_x')
  and id not in (pg_temp.fx('frete_a'), pg_temp.fx('frete_b'))), 0, 'empresa bloqueada: o envio do motorista não grava nada');

-- ------------------------------------------- auditoria das ações da plataforma

select is((select acao || ':' || origem || ':' || (campos ? 'bloqueada_em')::text from public.auditoria_plataforma
  where empresa_id = pg_temp.fx('empresa_x') order by id desc limit 1),
  'empresa_bloqueada:plataforma:true', 'bloquear a empresa fica registrado (ação, campos e quem fez)');
select public.liberar_empresa(pg_temp.fx('empresa_x'));
select is((select acao from public.auditoria_plataforma where empresa_id = pg_temp.fx('empresa_x') order by id desc limit 1),
  'empresa_liberada', 'liberar a empresa fica registrado');
select pg_temp.como(pg_temp.fx('u_dono_x'), 'select to_jsonb(public.gerar_novo_codigo_entrada())');
select is((select acao || ':' || origem || ':' || campos::text from public.auditoria_plataforma
  where empresa_id = pg_temp.fx('empresa_x') order by id desc limit 1),
  'codigo_trocado:dono:{"codigo_entrada": "alterado"}', 'trocar o código fica registrado sem o código');
select is((select count(*)::int from public.auditoria_plataforma where acao = 'empresa_criada'
  and empresa_id in (pg_temp.fx('empresa_x'), pg_temp.fx('empresa_y'))), 2, 'criar empresa fica registrado');
select is((select count(*)::int from public.auditoria_plataforma a
  where a.campos::text ~* '(transportes|teste\.com|@|\d{11})'), 0,
  'o registro não guarda nome, e-mail nem CPF');
select is(pg_temp.erro_como(pg_temp.fx('u_dono_x'), 'select * from public.auditoria_plataforma'), '42501',
  'o app não lê o registro da plataforma');
select throws_ok('delete from public.auditoria_plataforma', '42501',
  'O registro de auditoria da plataforma não pode ser alterado nem apagado.',
  'nem o dono do banco apaga o registro da plataforma');

-- --------------------------------------------------- IP verdadeiro e senha

select set_config('request.headers', '{"x-forwarded-for": "1.2.3.4, 200.1.1.1"}', true);
select set_config('frota.ip_1', coalesce(public.ip_da_requisicao(), ''), true);
select set_config('request.headers', '{"x-forwarded-for": "1.2.3.4, 200.1.1.1", "cf-connecting-ip": "200.9.9.9"}', true);
select is(current_setting('frota.ip_1') || ' ' || public.ip_da_requisicao(), '200.1.1.1 200.9.9.9',
  'o IP vem do cf-connecting-ip ou do último x-forwarded-for (o começo da lista pode ser inventado)');
select set_config('request.headers', '', true);

select is(array[public.senha_aceita('abc12345'), public.senha_aceita('abcdefgh'), public.senha_aceita('12345678'),
  public.senha_aceita('ab1'), public.senha_aceita(null)], array[true, false, false, false, false],
  'regra de senha: 8 ou mais, com letras e números');

-- --------------------------------------------- e-mail confirmado vai para o perfil

update auth.users set email = 'motorista.a.real@exemplo.com' where id = pg_temp.fx('u_a');
select is((select email from public.perfis where id = pg_temp.fx('u_a')), 'motorista.a.real@exemplo.com',
  'e-mail trocado no login (confirmado) vai para o perfil');
select is((select email from public.motoristas where perfil_id = pg_temp.fx('u_a')), 'motorista.a.real@exemplo.com',
  'e para o cadastro de motorista');

-- ------------------------------- troca de e-mail pelo próprio usuário: só motorista

select throws_ok($q$update auth.users set email_change = 'novo.dono@exemplo.com' where id = pg_temp.fx('u_dono_x')$q$,
  '42501', 'O e-mail de dono ou gestor só muda pela plataforma.', 'dono não pede troca do próprio e-mail');
select throws_ok($q$update auth.users set email_change = 'novo.gestor@exemplo.com' where id = pg_temp.fx('u_gestor_x')$q$,
  '42501', 'O e-mail de dono ou gestor só muda pela plataforma.', 'gestor não pede troca do próprio e-mail');
select lives_ok($q$update auth.users set email_change = 'motorista.b.real@exemplo.com' where id = pg_temp.fx('u_b')$q$,
  'motorista pede a troca para cadastrar o e-mail dele');

select * from finish();
rollback;
