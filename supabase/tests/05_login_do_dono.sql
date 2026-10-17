-- Login do dono criado pela plataforma (sem e-mail), com senha provisória.
begin;
\ir apoio/fixtures.psql

select plan(8);

insert into fx select 'empresa_z', (public.criar_empresa('Transportes Z', 'Dono.Z@teste.com') ->> 'empresa_id')::uuid;
insert into fx select 'u_dono_z', (public.criar_login_dono('dono.z@teste.com', 'Dono Z', 'provisoria1') ->> 'usuario_id')::uuid;

select is((select papel || ':' || (empresa_id = pg_temp.fx('empresa_z'))::text from public.perfis where id = pg_temp.fx('u_dono_z')),
  'dono:true', 'o dono entra na empresa dele');
select ok((select encrypted_password = extensions.crypt('provisoria1', encrypted_password) from auth.users
  where id = pg_temp.fx('u_dono_z')), 'a senha provisória fica guardada cifrada');
select is((select raw_user_meta_data ->> 'trocar_senha' from auth.users where id = pg_temp.fx('u_dono_z')), 'true',
  'o app pede para trocar a senha no primeiro login');
select is((select count(*)::int from auth.identities where user_id = pg_temp.fx('u_dono_z') and provider = 'email'), 1,
  'a identidade de e-mail é criada (o login do Supabase precisa dela)');

select public.criar_login_dono('DONO.Z@teste.com', 'Dono Z', 'outra-senha');
select ok((select encrypted_password = extensions.crypt('outra-senha', encrypted_password) from auth.users
  where id = pg_temp.fx('u_dono_z')), 'chamar de novo troca a senha, sem criar outro usuário');
select is((select count(*)::int from auth.users where lower(email) = 'dono.z@teste.com'), 1, 'um usuário só');

select throws_ok($$select public.criar_login_dono('qualquer@teste.com', 'Fulano', 'senha123')$$,
  'P0001', 'Este e-mail não está liberado como dono de nenhuma empresa.', 'e-mail sem liberação de dono é recusado');
select is(pg_temp.erro_como(pg_temp.fx('u_dono_x'), $q$select public.criar_login_dono('dono.z@teste.com', 'X', 'senha123')$q$),
  '42501', 'usuário do app não cria login de dono');

select * from finish();
rollback;
