-- Área da Plataforma (super administrador) e senha provisória forçada no banco.
begin;
\ir apoio/fixtures.psql

select plan(27);

-- Super administrador de teste (não é dono de empresa nenhuma).
insert into fx values ('u_admin', '10000000-0000-4000-8000-0000000000aa');
insert into auth.users (id, email, email_confirmed_at, encrypted_password)
values (pg_temp.fx('u_admin'), 'admin@plataforma.teste', now(), extensions.crypt('admin12345', extensions.gen_salt('bf')));
insert into public.admins_plataforma (usuario_id) values (pg_temp.fx('u_admin'));

-- ------------------------------------------- só o super administrador

select is(pg_temp.erro_como(pg_temp.fx('u_dono_x'), 'select public.plataforma_empresas()'), '42501',
  'dono de empresa não vê a lista da plataforma');
select is(pg_temp.erro_como(pg_temp.fx('u_gestor_x'), 'select public.plataforma_empresas()'), '42501',
  'gestor não vê a lista da plataforma');
select is(pg_temp.erro_como(pg_temp.fx('u_a'), 'select public.plataforma_empresas()'), '42501',
  'motorista não vê a lista da plataforma');
select is(pg_temp.erro_como(pg_temp.fx('u_d'), $q$select public.plataforma_criar_empresa('Invasora', 'Fulano', 'x@y.com')$q$),
  '42501', 'conta sem vínculo não cadastra empresa');
select is(pg_temp.erro_como(pg_temp.fx('u_dono_x'), format('select public.plataforma_bloquear(%L, %L)', pg_temp.fx('empresa_y'), 'teste')),
  '42501', 'dono não bloqueia outra empresa');
select is(pg_temp.erro_como(pg_temp.fx('u_gestor_x'), format('select public.plataforma_nova_senha_dono(%L)', pg_temp.fx('empresa_x'))),
  '42501', 'gestor não gera senha do dono');
select is(pg_temp.erro_como(pg_temp.fx('u_dono_x'), format('select public.plataforma_liberar(%L, null)', pg_temp.fx('empresa_x'))),
  '42501', 'dono não tira o prazo de teste da própria empresa');
select ok(not has_function_privilege('authenticated', 'public.marcar_senha_provisoria(uuid)', 'execute')
  and not has_function_privilege('authenticated', 'public.eh_admin_plataforma()', 'execute')
  and not has_function_privilege('authenticated', 'public.gerar_senha_provisoria()', 'execute'),
  'as funções internas da plataforma não ficam abertas para o app');

select is(pg_temp.como(pg_temp.fx('u_admin'), 'select public.situacao_acesso()') ->> 'admin_plataforma', 'true',
  'o app sabe que é o super administrador');
select is(pg_temp.como(pg_temp.fx('u_dono_x'), 'select public.situacao_acesso()') ->> 'admin_plataforma', 'false',
  'dono comum não é super administrador');
select is(pg_jsonb_len.n, (select count(*)::int from public.empresas), 'o super administrador vê todas as empresas')
from (select jsonb_array_length(pg_temp.como(pg_temp.fx('u_admin'), 'select public.plataforma_empresas()')) as n) pg_jsonb_len;

-- ------------------------------------------------- cadastrar empresa

create temp table nova as
select pg_temp.como(pg_temp.fx('u_admin'),
  $q$select public.plataforma_criar_empresa('Transportes Nova', 'Maria Dona', ' Maria@Nova.com ', 30, 8)$q$) as r;
grant select on nova to authenticated;
insert into fx select 'empresa_nova', (r ->> 'empresa_id')::uuid from nova;
insert into fx select 'u_dono_nova', id from auth.users where email = 'maria@nova.com';

select ok((select (r ->> 'senha_provisoria') ~ '^[A-HJ-NP-Z2-9]{10}$' from nova)
  and public.senha_aceita((select r ->> 'senha_provisoria' from nova)),
  'a senha provisória tem 10 letras e números, sem os que confundem');
select is((select papel || ':' || email || ':' || nome from public.perfis where id = pg_temp.fx('u_dono_nova')),
  'dono:maria@nova.com:Maria Dona', 'o dono nasce com o e-mail dele na empresa nova');
select ok((select acesso_ate between now() + interval '29 days' and now() + interval '31 days'
  from public.empresas where id = pg_temp.fx('empresa_nova')), 'o prazo de teste fica em 30 dias');
select is((select limite_caminhoes from public.empresas where id = pg_temp.fx('empresa_nova')), 8,
  'o limite de caminhões é o escolhido');
select ok((select encrypted_password = extensions.crypt((select r ->> 'senha_provisoria' from nova), encrypted_password)
  from auth.users where id = pg_temp.fx('u_dono_nova')), 'o dono entra com a senha provisória');

-- ------------------------------------- senha provisória forçada no banco

select is(pg_temp.como(pg_temp.fx('u_dono_nova'), 'select public.situacao_acesso()') ->> 'senha_provisoria', 'true',
  'com a senha provisória, o app pede a senha nova');
select is(pg_temp.como(pg_temp.fx('u_dono_nova'), 'select to_jsonb(count(*)) from public.categorias_gasto')::text, '0',
  'com a senha provisória, o banco não mostra nada da empresa');
update auth.users set encrypted_password = extensions.crypt('senhaDaMaria9', extensions.gen_salt('bf'))
where id = pg_temp.fx('u_dono_nova');
select is(pg_temp.como(pg_temp.fx('u_dono_nova'), 'select to_jsonb(count(*)) from public.categorias_gasto')::text, '11',
  'trocou a senha: o dono vê a empresa');
select is(pg_temp.como(pg_temp.fx('u_dono_nova'), 'select public.situacao_acesso()') ->> 'senha_provisoria', 'false',
  'e o app não pede mais a senha nova');

-- ----------------------------------------------- e-mail repetido ou errado

select is(pg_temp.mensagem_como(pg_temp.fx('u_admin'),
  $q$select public.plataforma_criar_empresa('Outra', 'Fulano', 'dono.x@teste.com')$q$),
  'Este e-mail já tem conta na plataforma. Use outro e-mail para o dono.', 'e-mail que já tem conta é recusado');
select is(pg_temp.mensagem_como(pg_temp.fx('u_admin'),
  $q$select public.plataforma_criar_empresa('Outra', 'Fulano', 'sem-arroba')$q$),
  'Este e-mail não parece certo. Confira.', 'e-mail errado é recusado');

-- ------------------------------------- bloquear, liberar e senha nova do dono

select pg_temp.como(pg_temp.fx('u_admin'), format('select public.plataforma_bloquear(%L, %L)',
  pg_temp.fx('empresa_nova'), 'Falta de pagamento'));
select is((select x ->> 'situacao' from jsonb_array_elements(pg_temp.como(pg_temp.fx('u_admin'),
  'select public.plataforma_empresas()')) x where x ->> 'id' = pg_temp.fx('empresa_nova')::text), 'bloqueada',
  'o super administrador bloqueia a empresa');
select pg_temp.como(pg_temp.fx('u_admin'), format('select public.plataforma_liberar(%L, null)', pg_temp.fx('empresa_nova')));
select is((select coalesce(bloqueada_em::text, 'livre') || ':' || coalesce(acesso_ate::text, 'sem prazo')
  from public.empresas where id = pg_temp.fx('empresa_nova')), 'livre:sem prazo', 'e libera sem prazo');

select ok((pg_temp.como(pg_temp.fx('u_admin'), format('select public.plataforma_nova_senha_dono(%L)',
  pg_temp.fx('empresa_nova'))) ->> 'senha_provisoria') ~ '^[A-HJ-NP-Z2-9]{10}$'
  and (pg_temp.como(pg_temp.fx('u_dono_nova'), 'select public.situacao_acesso()') ->> 'senha_provisoria') = 'true',
  'senha provisória nova para o dono: o app volta a pedir a troca');

select ok((select count(*) from public.auditoria_plataforma
  where empresa_id = pg_temp.fx('empresa_nova') and origem = 'plataforma_app') >= 4,
  'tudo o que o super administrador faz fica na auditoria (origem plataforma_app)');

-- Super administrador com senha provisória também precisa trocar antes.
select public.marcar_senha_provisoria(pg_temp.fx('u_admin'));
select is(pg_temp.erro_como(pg_temp.fx('u_admin'), 'select public.plataforma_empresas()'), '42501',
  'super administrador com senha provisória não usa a plataforma até trocar');

select * from finish();
rollback;
