-- Área da Plataforma no app (super administrador) e senha provisória forçada.
--
-- Pedido do dono (22/10/2026): cadastrar empresas e cuidar delas pelo app
-- Frota Gestor, sem abrir o Supabase.
--
-- 1. Super administrador: tabela admins_plataforma (só a plataforma mexe, pelo
--    SQL do Supabase). Hoje: a conta gestaodefrota2027@gmail.com.
-- 2. Ações da plataforma pelo app (plataforma_*): cada uma confere no banco se
--    quem chama é o super administrador. Nenhuma apaga dados. Tudo fica na
--    auditoria da plataforma (origem "plataforma_app").
-- 3. Senha provisória forçada no banco: o login de dono criado pela plataforma
--    (criar_login_dono) fica marcado; enquanto a pessoa não trocar a senha, as
--    permissões de dono e gestor negam tudo (o app pede a senha nova). A marca
--    é um resumo (SHA-256) da senha cifrada: trocou a senha, deixa de valer.
-- Melhoria futura anotada: verificação em duas etapas (código do Google
-- Authenticator) para abrir a área da Plataforma.
--
-- Esta migration só cria objetos ou troca funções (nada é apagado).

-- --------------------------------------------- 1. senha provisória forçada

create table public.senhas_provisorias (
  usuario_id uuid primary key references auth.users (id) on delete cascade,
  marca text not null,
  criada_em timestamptz not null default pg_catalog.now()
);
comment on table public.senhas_provisorias is
  'Logins com senha provisória (criada pela plataforma). marca = SHA-256 da senha cifrada naquele momento.';
alter table public.senhas_provisorias enable row level security;
revoke all on table public.senhas_provisorias from public, anon, authenticated, service_role;

-- Marca a senha atual do usuário como provisória (uso interno).
create or replace function public.marcar_senha_provisoria(p_usuario uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.senhas_provisorias (usuario_id, marca)
  select u.id, pg_catalog.encode(extensions.digest(u.encrypted_password, 'sha256'), 'hex')
  from auth.users u where u.id = p_usuario and u.encrypted_password is not null
  on conflict (usuario_id) do update set marca = excluded.marca, criada_em = pg_catalog.now();
end;
$$;

-- Quem chamou ainda está com a senha provisória?
create or replace function public.senha_provisoria_pendente()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.senhas_provisorias s
    join auth.users u on u.id = s.usuario_id
    where s.usuario_id = (select auth.uid())
      and s.marca = pg_catalog.encode(extensions.digest(u.encrypted_password, 'sha256'), 'hex')
  )
$$;

-- As permissões de dono e gestor passam a exigir a senha trocada (o resto igual).
create or replace function public.empresa_do_usuario()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select p.empresa_id
  from public.perfis p
  where p.id = (select auth.uid()) and p.ativo and p.apagado_em is null
    and public.empresa_liberada(p.empresa_id)
    and not public.senha_provisoria_pendente()
  limit 1
$$;

create or replace function public.eh_dono()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.perfis p
    where p.id = (select auth.uid()) and p.papel = 'dono'
      and p.ativo and p.apagado_em is null and p.empresa_id is not null
      and public.empresa_liberada(p.empresa_id)
  ) and not public.senha_provisoria_pendente()
$$;

create or replace function public.eh_gestor_ou_dono()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.perfis p
    where p.id = (select auth.uid()) and p.papel in ('gestor', 'dono')
      and p.ativo and p.apagado_em is null and p.empresa_id is not null
      and public.empresa_liberada(p.empresa_id)
  ) and not public.senha_provisoria_pendente()
$$;

-- O login de dono criado pela plataforma nasce com a senha provisória marcada.
create or replace function public.criar_login_dono(p_email text, p_nome text, p_senha text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_email text := pg_catalog.lower(pg_catalog.btrim(coalesce(p_email, '')));
  v_nome text := pg_catalog.btrim(coalesce(p_nome, ''));
  v_empresa uuid;
  v_id uuid;
begin
  select a.empresa_id into v_empresa from public.acessos_autorizados a
  where a.email = v_email and a.papel = 'dono' and a.ativo and a.apagado_em is null
  order by a.criado_em
  limit 1;
  if v_empresa is null then
    perform public.erro('Este e-mail não está liberado como dono de nenhuma empresa.', 'nao_autorizado');
  end if;
  if not public.senha_aceita(p_senha) then
    perform public.erro('A senha precisa ter pelo menos 8 caracteres, com letras e números.', 'senha_fraca');
  end if;
  if pg_catalog.length(v_nome) < 2 then
    perform public.erro('Escreva o nome do dono.', 'nome_invalido');
  end if;

  select u.id into v_id from auth.users u where pg_catalog.lower(u.email) = v_email limit 1;
  if v_id is null then
    v_id := pg_catalog.gen_random_uuid();
    insert into auth.users (
      instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
      raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
      confirmation_token, recovery_token, email_change_token_new, email_change,
      phone_change, phone_change_token, email_change_token_current, reauthentication_token)
    values (
      '00000000-0000-0000-0000-000000000000', v_id, 'authenticated', 'authenticated', v_email,
      extensions.crypt(p_senha, extensions.gen_salt('bf')), pg_catalog.now(),
      '{"provider": "email", "providers": ["email"]}'::jsonb, '{"trocar_senha": true}'::jsonb,
      pg_catalog.now(), pg_catalog.now(), '', '', '', '', '', '', '', '');
    insert into auth.identities (provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
    values (v_id::text, v_id,
      pg_catalog.jsonb_build_object('sub', v_id::text, 'email', v_email, 'email_verified', true, 'phone_verified', false),
      'email', pg_catalog.now(), pg_catalog.now(), pg_catalog.now());
  else
    update auth.users u
       set encrypted_password = extensions.crypt(p_senha, extensions.gen_salt('bf')),
           email_confirmed_at = coalesce(u.email_confirmed_at, pg_catalog.now()),
           raw_user_meta_data = coalesce(u.raw_user_meta_data, '{}'::jsonb) || '{"trocar_senha": true}'::jsonb,
           updated_at = pg_catalog.now()
     where u.id = v_id;
  end if;

  insert into public.perfis (id, empresa_id, papel, nome, email)
  values (v_id, v_empresa, 'dono', v_nome, v_email)
  on conflict (id) do update
    set empresa_id = excluded.empresa_id, papel = 'dono', ativo = true, apagado_em = null;

  perform public.marcar_senha_provisoria(v_id);

  insert into public.auditoria_plataforma (acao, empresa_id, origem)
  values ('login_dono_criado', v_empresa, public.origem_da_acao());

  return pg_catalog.jsonb_build_object('usuario_id', v_id, 'empresa_id', v_empresa, 'email', v_email);
end;
$$;

-- ------------------------------------------------ 2. super administrador

create table public.admins_plataforma (
  usuario_id uuid primary key references auth.users (id) on delete cascade,
  criado_em timestamptz not null default pg_catalog.now()
);
comment on table public.admins_plataforma is
  'Super administradores da plataforma (área Plataforma do app). Só a plataforma mexe, pelo SQL do Supabase.';
alter table public.admins_plataforma enable row level security;
revoke all on table public.admins_plataforma from public, anon, authenticated, service_role;

insert into public.admins_plataforma (usuario_id)
select u.id from auth.users u where pg_catalog.lower(u.email) = 'gestaodefrota2027@gmail.com'
on conflict (usuario_id) do nothing;

-- Quem chamou é super administrador (e já trocou a senha provisória, se tinha)?
create or replace function public.eh_admin_plataforma()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.admins_plataforma a where a.usuario_id = (select auth.uid()))
    and not public.senha_provisoria_pendente()
$$;

create or replace function public.exigir_admin_plataforma()
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.eh_admin_plataforma() then
    perform public.erro('Só o administrador da plataforma pode fazer isso.', 'sem_permissao', '42501');
  end if;
end;
$$;

-- Na auditoria, o que o super administrador faz pelo app aparece como "plataforma_app".
create or replace function public.origem_da_acao()
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_papel text;
begin
  if (select auth.uid()) is not null then
    if exists (select 1 from public.admins_plataforma a where a.usuario_id = (select auth.uid())) then
      return 'plataforma_app';
    end if;
    v_papel := public.papel_do_usuario();
    return coalesce(v_papel, 'usuario');
  end if;
  begin
    if nullif(pg_catalog.current_setting('request.jwt.claims', true), '')::jsonb ->> 'role' = 'service_role' then
      return 'servidor';
    end if;
  exception when others then
    null;
  end;
  if pg_catalog.current_setting('application_name', true) = 'pg_cron' then
    return 'agendamento';
  end if;
  return 'plataforma';
end;
$$;

-- Senha provisória forte: 10 letras e números, sem 0/O e 1/I (32 símbolos, sorteio sem viés).
create or replace function public.gerar_senha_provisoria()
returns text
language plpgsql
volatile
set search_path = ''
as $$
declare
  v_alfabeto constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_bytes bytea;
  v_senha text;
begin
  loop
    v_bytes := extensions.gen_random_bytes(10);
    v_senha := '';
    for i in 0..9 loop
      v_senha := v_senha || pg_catalog.substr(v_alfabeto, (pg_catalog.get_byte(v_bytes, i) % 32) + 1, 1);
    end loop;
    exit when public.senha_aceita(v_senha);
  end loop;
  return v_senha;
end;
$$;

-- ----------------------------------------------- ações da área Plataforma

-- Lista das empresas, com o dono, a situação e o uso.
create or replace function public.plataforma_empresas()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform public.exigir_admin_plataforma();
  return coalesce((
    select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'id', e.id, 'nome', e.nome,
      'dono_nome', d.nome, 'dono_email', coalesce(d.email, a.email),
      'dono_primeiro_acesso_pendente', d.id is not null and exists (
        select 1 from public.senhas_provisorias s join auth.users u on u.id = s.usuario_id
        where s.usuario_id = d.id
          and s.marca = pg_catalog.encode(extensions.digest(u.encrypted_password, 'sha256'), 'hex')),
      'situacao', case when e.excluida_em is not null then 'excluida'
                       when e.bloqueada_em is not null then 'bloqueada'
                       when e.acesso_ate is not null and e.acesso_ate <= pg_catalog.now() then 'teste_vencido'
                       when e.acesso_ate is not null then 'teste'
                       else 'liberada' end,
      'acesso_ate', e.acesso_ate,
      'motivo_bloqueio', e.motivo_bloqueio,
      'excluir_em', case when e.excluida_em is not null then null
                         when e.excluir_em is not null then e.excluir_em
                         when e.bloqueada_em is null and e.acesso_ate is not null then e.acesso_ate + interval '30 days' end,
      'limite_caminhoes', e.limite_caminhoes,
      'motoristas', (select count(*) from public.motoristas m where m.empresa_id = e.id and m.ativo and m.apagado_em is null),
      'caminhoes', (select count(*) from public.caminhoes c where c.empresa_id = e.id and c.ativo and c.apagado_em is null),
      'ultimo_envio', (select pg_catalog.max(x.ultimo_sync_em) from public.dispositivos x where x.empresa_id = e.id),
      'criada_em', e.criado_em)
      order by (e.excluida_em is not null), e.criado_em desc)
    from public.empresas e
    left join lateral (
      select p.id, p.nome, p.email from public.perfis p
      where p.empresa_id = e.id and p.papel = 'dono' and p.apagado_em is null
      order by p.criado_em limit 1) d on true
    left join lateral (
      select au.email from public.acessos_autorizados au
      where au.empresa_id = e.id and au.papel = 'dono' and au.apagado_em is null
      order by au.criado_em limit 1) a on true
  ), '[]'::jsonb);
end;
$$;

-- Cadastra a empresa e o login do dono com uma senha provisória (mostrada uma vez).
create or replace function public.plataforma_criar_empresa(
  p_nome text,
  p_dono_nome text,
  p_dono_email text,
  p_dias_teste integer default 30,
  p_limite_caminhoes integer default 5
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_nome text := pg_catalog.btrim(coalesce(p_nome, ''));
  v_dono text := pg_catalog.btrim(coalesce(p_dono_nome, ''));
  v_email text := pg_catalog.lower(pg_catalog.btrim(coalesce(p_dono_email, '')));
  v_empresa jsonb;
  v_id uuid;
  v_senha text;
  v_ate timestamptz;
begin
  perform public.exigir_admin_plataforma();
  if pg_catalog.length(v_nome) < 2 or pg_catalog.length(v_nome) > 120 then
    perform public.erro('Escreva o nome da empresa.', 'nome_invalido');
  end if;
  if pg_catalog.length(v_dono) < 2 or pg_catalog.length(v_dono) > 120 then
    perform public.erro('Escreva o nome do dono.', 'nome_invalido');
  end if;
  if pg_catalog.length(v_email) > 254 or v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'
     or v_email like '%@motorista.fortalezadigitalsecurity.com.br' then
    perform public.erro('Este e-mail não parece certo. Confira.', 'email_invalido');
  end if;
  if p_dias_teste is not null and (p_dias_teste < 1 or p_dias_teste > 3650) then
    perform public.erro('O prazo de teste vai de 1 a 3650 dias (ou sem prazo).', 'prazo_invalido');
  end if;
  if p_limite_caminhoes is null or p_limite_caminhoes < 1 or p_limite_caminhoes > 1000 then
    perform public.erro('O limite de caminhões vai de 1 a 1000.', 'limite_invalido');
  end if;
  if exists (select 1 from public.perfis p where pg_catalog.lower(p.email) = v_email and p.apagado_em is null)
     or exists (select 1 from public.acessos_autorizados a
                where a.email = v_email and a.ativo and a.apagado_em is null) then
    perform public.erro('Este e-mail já tem conta na plataforma. Use outro e-mail para o dono.', 'email_em_uso');
  end if;

  v_empresa := public.criar_empresa(v_nome, v_email, null, 'piloto', p_limite_caminhoes, 'teste');
  v_id := (v_empresa ->> 'empresa_id')::uuid;
  v_senha := public.gerar_senha_provisoria();
  perform public.criar_login_dono(v_email, v_dono, v_senha);
  if p_dias_teste is not null then
    v_ate := pg_catalog.now() + pg_catalog.make_interval(days => p_dias_teste);
    perform public.liberar_empresa(v_id, v_ate);
  end if;
  return pg_catalog.jsonb_build_object('empresa_id', v_id, 'nome', v_nome, 'dono_nome', v_dono,
    'dono_email', v_email, 'senha_provisoria', v_senha, 'acesso_ate', v_ate);
end;
$$;

-- Libera a empresa (tira o bloqueio) por p_dias a partir de agora; nulo = sem prazo.
create or replace function public.plataforma_liberar(p_empresa uuid, p_dias integer default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.exigir_admin_plataforma();
  if p_dias is not null and (p_dias < 1 or p_dias > 3650) then
    perform public.erro('O prazo vai de 1 a 3650 dias (ou sem prazo).', 'prazo_invalido');
  end if;
  return public.liberar_empresa(p_empresa,
    case when p_dias is null then null else pg_catalog.now() + pg_catalog.make_interval(days => p_dias) end);
end;
$$;

-- Bloqueia a empresa (os dados são apagados 30 dias depois, se não for liberada).
create or replace function public.plataforma_bloquear(p_empresa uuid, p_motivo text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.exigir_admin_plataforma();
  if pg_catalog.length(pg_catalog.btrim(coalesce(p_motivo, ''))) < 3 then
    perform public.erro('Escreva o motivo do bloqueio (o dono vai ver).', 'motivo_invalido');
  end if;
  return public.bloquear_empresa(p_empresa, p_motivo, 30);
end;
$$;

-- Senha provisória nova para o dono que perdeu o acesso ao e-mail.
create or replace function public.plataforma_nova_senha_dono(p_empresa uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_email text;
  v_nome text;
  v_senha text;
begin
  perform public.exigir_admin_plataforma();
  select a.email, coalesce(p.nome, 'Dono') into v_email, v_nome
  from public.acessos_autorizados a
  join public.empresas e on e.id = a.empresa_id and e.excluida_em is null
  left join public.perfis p on pg_catalog.lower(p.email) = a.email and p.papel = 'dono' and p.empresa_id = a.empresa_id
  where a.empresa_id = p_empresa and a.papel = 'dono' and a.ativo and a.apagado_em is null
  order by a.criado_em limit 1;
  if v_email is null then
    perform public.erro('Empresa sem dono cadastrado.', 'empresa_inexistente');
  end if;
  v_senha := public.gerar_senha_provisoria();
  perform public.criar_login_dono(v_email, v_nome, v_senha);
  return pg_catalog.jsonb_build_object('dono_nome', v_nome, 'dono_email', v_email, 'senha_provisoria', v_senha);
end;
$$;

-- ---------------------------------------------------- 3. situação de acesso

-- Igual à anterior, mais: admin_plataforma e senha_provisoria (o app pede a senha nova).
create or replace function public.situacao_acesso()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_perfil public.perfis;
  v_empresa public.empresas;
  v_motorista public.motoristas;
  v_pedido jsonb;
  v_email_confirmado boolean;
  v_bloqueada boolean;
  v_excluir_em timestamptz;
  v_admin boolean;
  v_provisoria boolean;
begin
  if v_uid is null then
    return pg_catalog.jsonb_build_object('logado', false);
  end if;
  select (u.email_confirmed_at is not null) into v_email_confirmado from auth.users u where u.id = v_uid;
  v_admin := exists (select 1 from public.admins_plataforma a where a.usuario_id = v_uid);
  v_provisoria := public.senha_provisoria_pendente();
  select * into v_perfil from public.perfis p where p.id = v_uid;
  if not found then
    return pg_catalog.jsonb_build_object('logado', true, 'email_confirmado', coalesce(v_email_confirmado, false),
      'perfil', null, 'empresa', null, 'motorista', null, 'pedido', null,
      'admin_plataforma', v_admin, 'senha_provisoria', v_provisoria);
  end if;
  if v_perfil.empresa_id is not null and v_perfil.ativo and v_perfil.apagado_em is null then
    select * into v_empresa from public.empresas e where e.id = v_perfil.empresa_id and e.apagado_em is null;
  end if;
  if v_perfil.papel = 'motorista' and v_perfil.empresa_id is not null then
    select * into v_motorista from public.motoristas m
    where m.perfil_id = v_uid and m.empresa_id = v_perfil.empresa_id;
  end if;
  select pg_catalog.jsonb_build_object(
      'id', pe.id, 'status', pe.status, 'pedido_em', pe.pedido_em,
      'decidido_em', pe.decidido_em, 'empresa_nome', e.nome)
    into v_pedido
  from public.pedidos_entrada pe
  join public.empresas e on e.id = pe.empresa_id
  where pe.perfil_id = v_uid and pe.apagado_em is null
  order by pe.pedido_em desc
  limit 1;

  if v_empresa.id is not null then
    v_bloqueada := v_empresa.bloqueada_em is not null
      or (v_empresa.acesso_ate is not null and v_empresa.acesso_ate <= pg_catalog.now());
    v_excluir_em := case
      when v_empresa.excluir_em is not null then v_empresa.excluir_em
      when v_empresa.bloqueada_em is null and v_empresa.acesso_ate is not null
        then v_empresa.acesso_ate + interval '30 days' end;
  end if;

  return pg_catalog.jsonb_build_object(
    'logado', true,
    'email_confirmado', coalesce(v_email_confirmado, false),
    'admin_plataforma', v_admin,
    'senha_provisoria', v_provisoria,
    'perfil', pg_catalog.jsonb_build_object(
      'id', v_perfil.id, 'nome', v_perfil.nome, 'papel', v_perfil.papel,
      'email', v_perfil.email, 'cpf', v_perfil.cpf, 'ativo', v_perfil.ativo and v_perfil.apagado_em is null,
      'exclusao_pedida_em', v_perfil.exclusao_pedida_em),
    'empresa', case when v_empresa.id is null then null else pg_catalog.jsonb_build_object(
      'id', v_empresa.id, 'nome', v_empresa.nome, 'status', v_empresa.status,
      'plano', v_empresa.plano, 'limite_caminhoes', v_empresa.limite_caminhoes,
      'percentual_comissao_padrao', v_empresa.percentual_comissao_padrao,
      'comissao_sobre_bruto_padrao', v_empresa.comissao_sobre_bruto_padrao,
      'gastos_descontam_do_liquido', v_empresa.gastos_descontam_do_liquido,
      'vale_desconta_do_liquido', v_empresa.vale_desconta_do_liquido,
      'codigo_entrada', case when v_perfil.papel in ('dono', 'gestor') then v_empresa.codigo_entrada end,
      'bloqueada', v_bloqueada,
      'motivo_bloqueio', case when v_bloqueada then coalesce(v_empresa.motivo_bloqueio,
        'O período de teste terminou.') end,
      'acesso_ate', v_empresa.acesso_ate,
      'excluir_em', v_excluir_em) end,
    'motorista', case when v_motorista.id is null then null else pg_catalog.jsonb_build_object(
      'id', v_motorista.id, 'nome', v_motorista.nome, 'ativo', v_motorista.ativo and v_motorista.apagado_em is null) end,
    'pedido', v_pedido,
    'termos', pg_catalog.jsonb_build_object('versao', public.versao_termos(),
      'aceito', exists (select 1 from public.aceites_termos a
                        where a.perfil_id = v_uid and a.versao = public.versao_termos())),
    'recuperacao', exists (select 1 from public.codigos_recuperacao c where c.perfil_id = v_uid)
  );
end;
$$;

-- ------------------------------------------------------------ privilégios

revoke all on function public.marcar_senha_provisoria(uuid) from public, anon, authenticated;
revoke all on function public.senha_provisoria_pendente() from public, anon, authenticated;
revoke all on function public.eh_admin_plataforma() from public, anon, authenticated;
revoke all on function public.exigir_admin_plataforma() from public, anon, authenticated;
revoke all on function public.gerar_senha_provisoria() from public, anon, authenticated;
revoke all on function public.criar_login_dono(text, text, text) from public, anon, authenticated;
revoke all on function public.origem_da_acao() from public, anon, authenticated;

revoke all on function public.plataforma_empresas() from public, anon;
revoke all on function public.plataforma_criar_empresa(text, text, text, integer, integer) from public, anon;
revoke all on function public.plataforma_liberar(uuid, integer) from public, anon;
revoke all on function public.plataforma_bloquear(uuid, text) from public, anon;
revoke all on function public.plataforma_nova_senha_dono(uuid) from public, anon;
grant execute on function public.plataforma_empresas() to authenticated;
grant execute on function public.plataforma_criar_empresa(text, text, text, integer, integer) to authenticated;
grant execute on function public.plataforma_liberar(uuid, integer) to authenticated;
grant execute on function public.plataforma_bloquear(uuid, text) to authenticated;
grant execute on function public.plataforma_nova_senha_dono(uuid) to authenticated;

revoke all on function public.situacao_acesso() from public, anon;
grant execute on function public.situacao_acesso() to authenticated;
