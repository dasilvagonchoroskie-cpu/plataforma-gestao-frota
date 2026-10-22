-- Segurança da plataforma (22/10/2026).
--
-- O que muda (nada é apagado):
--   1. Objetos novos no schema public não nascem liberados para quem não
--      entrou (anon), e funções novas não nascem liberadas para todos (PUBLIC).
--   2. O IP de quem chamou vem do cabeçalho que o aparelho não consegue
--      falsificar (cf-connecting-ip, ou o último endereço de x-forwarded-for).
--   3. Regra de senha única: de 8 a 72 caracteres, com letras e números.
--   4. Registro das ações da plataforma (auditoria_plataforma): criar,
--      bloquear, liberar, alterar e excluir empresa, trocar código, criar o
--      login do dono e mudar a configuração (ex.: modo da limpeza diária).
--      Guarda só o que mudou nos campos de controle, a data e quem fez
--      (plataforma, dono, gestor, agendamento...), nunca nome, e-mail, CPF ou
--      documento. A tabela só aceita inclusão: ninguém altera nem apaga.

-- ---------------------------------------------------- 1. permissões padrão

alter default privileges for role postgres in schema public revoke all on tables from anon;
alter default privileges for role postgres in schema public revoke all on sequences from anon;
alter default privileges for role postgres in schema public revoke all on functions from anon;
alter default privileges for role postgres revoke execute on functions from public;
-- E o que já existe: nenhuma tabela ou sequência do public liberada para anon.
revoke all on all tables in schema public from anon;
revoke all on all sequences in schema public from anon;

-- ------------------------------------------------------ 2. IP verdadeiro

create or replace function public.ip_da_requisicao()
returns text
language plpgsql
stable
set search_path = ''
as $$
declare
  v_cab jsonb;
  v_lista text[];
  v_ip text;
begin
  begin
    v_cab := nullif(pg_catalog.current_setting('request.headers', true), '')::jsonb;
  exception when others then
    return null;
  end;
  -- cf-connecting-ip é escrito pela Cloudflare (o aparelho não muda). No
  -- x-forwarded-for, quem chama pode inventar o começo da lista; o último
  -- endereço é o que o servidor viu de verdade.
  v_ip := nullif(pg_catalog.btrim(v_cab ->> 'cf-connecting-ip'), '');
  if v_ip is null then
    v_lista := pg_catalog.string_to_array(coalesce(v_cab ->> 'x-forwarded-for', ''), ',');
    if pg_catalog.array_length(v_lista, 1) > 0 then
      v_ip := nullif(pg_catalog.btrim(v_lista[pg_catalog.array_length(v_lista, 1)]), '');
    end if;
  end if;
  v_ip := coalesce(v_ip, nullif(pg_catalog.btrim(v_cab ->> 'x-real-ip'), ''));
  return pg_catalog.left(v_ip, 64);
end;
$$;

-- ------------------------------------------------------ 3. regra de senha

-- A mesma regra do app, das Edge Functions e do Supabase Auth.
create or replace function public.senha_aceita(p text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select coalesce(pg_catalog.length(p) between 8 and 72 and p ~ '[A-Za-z]' and p ~ '[0-9]', false)
$$;

-- ------------------------------------------- 4. auditoria da plataforma

create table public.auditoria_plataforma (
  id bigint generated always as identity primary key,
  quando timestamptz not null default pg_catalog.now(),
  acao text not null,
  empresa_id uuid,
  campos jsonb not null default '{}'::jsonb,
  origem text not null,
  usuario_banco text not null default session_user
);
comment on table public.auditoria_plataforma is
  'Ações da plataforma sobre empresas e configuração. Sem dados pessoais. Só inclusão.';
create index auditoria_plataforma_empresa on public.auditoria_plataforma (empresa_id, quando);
alter table public.auditoria_plataforma enable row level security;
revoke all on table public.auditoria_plataforma from public, anon, authenticated, service_role;

-- Quem fez: o papel de quem entrou no app, o servidor (Edge Function), o
-- agendamento (pg_cron) ou a plataforma (SQL do dono da plataforma).
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

create or replace function public.auditar_empresa_plataforma()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_novo jsonb;
  v_velho jsonb;
  v_campos jsonb := '{}'::jsonb;
  v_acao text;
  c text;
begin
  if tg_op = 'INSERT' then
    insert into public.auditoria_plataforma (acao, empresa_id, campos, origem)
    values ('empresa_criada', new.id, pg_catalog.jsonb_build_object(
      'plano', new.plano, 'status', new.status, 'limite_caminhoes', new.limite_caminhoes,
      'acesso_ate', new.acesso_ate), public.origem_da_acao());
    return new;
  elsif tg_op = 'DELETE' then
    insert into public.auditoria_plataforma (acao, empresa_id, origem)
    values ('empresa_apagada', old.id, public.origem_da_acao());
    return old;
  end if;

  v_novo := pg_catalog.to_jsonb(new);
  v_velho := pg_catalog.to_jsonb(old);
  -- Campos de controle: guarda antes e depois.
  foreach c in array array['status', 'plano', 'limite_caminhoes', 'acesso_ate', 'bloqueada_em',
                           'motivo_bloqueio', 'excluir_em', 'excluida_em', 'apagado_em'] loop
    if v_novo -> c is distinct from v_velho -> c then
      v_campos := v_campos || pg_catalog.jsonb_build_object(c,
        pg_catalog.jsonb_build_object('antes', v_velho -> c, 'depois', v_novo -> c));
    end if;
  end loop;
  -- Nome, documento e código: só registra que mudou (sem o conteúdo).
  foreach c in array array['nome', 'documento', 'codigo_entrada'] loop
    if v_novo -> c is distinct from v_velho -> c then
      v_campos := v_campos || pg_catalog.jsonb_build_object(c, 'alterado');
    end if;
  end loop;
  if v_campos = '{}'::jsonb then
    return new;
  end if;

  v_acao := case
    when old.excluida_em is null and new.excluida_em is not null then 'empresa_excluida'
    when old.bloqueada_em is null and new.bloqueada_em is not null then 'empresa_bloqueada'
    when old.bloqueada_em is not null and new.bloqueada_em is null then 'empresa_liberada'
    when v_campos = pg_catalog.jsonb_build_object('codigo_entrada', 'alterado') then 'codigo_trocado'
    else 'empresa_alterada' end;
  insert into public.auditoria_plataforma (acao, empresa_id, campos, origem)
  values (v_acao, new.id, v_campos, public.origem_da_acao());
  return new;
end;
$$;

create trigger auditar_empresa_plataforma
after insert or update or delete on public.empresas
for each row execute function public.auditar_empresa_plataforma();

create or replace function public.auditar_configuracao_plataforma()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.auditoria_plataforma (acao, campos, origem)
  values ('configuracao_alterada', pg_catalog.jsonb_build_object(
    'chave', coalesce(new.chave, old.chave),
    'antes', case when tg_op <> 'INSERT' then old.valor end,
    'depois', case when tg_op <> 'DELETE' then new.valor end), public.origem_da_acao());
  return coalesce(new, old);
end;
$$;

create trigger auditar_configuracao_plataforma
after insert or update or delete on public.configuracao_plataforma
for each row execute function public.auditar_configuracao_plataforma();

-- O registro só aceita inclusão.
create or replace function public.auditoria_somente_inclusao()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'O registro de auditoria da plataforma não pode ser alterado nem apagado.'
    using errcode = '42501';
end;
$$;

create trigger somente_inclusao
before update or delete on public.auditoria_plataforma
for each row execute function public.auditoria_somente_inclusao();
create trigger somente_inclusao_tudo
before truncate on public.auditoria_plataforma
for each statement execute function public.auditoria_somente_inclusao();

-- ------------------------------------- login do dono com a regra de senha

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

  insert into public.auditoria_plataforma (acao, empresa_id, origem)
  values ('login_dono_criado', v_empresa, public.origem_da_acao());

  return pg_catalog.jsonb_build_object('usuario_id', v_id, 'empresa_id', v_empresa, 'email', v_email);
end;

$$;

-- ------------------------------------------------------------ privilégios

revoke all on function public.ip_da_requisicao() from public, anon, authenticated;
revoke all on function public.senha_aceita(text) from public, anon, authenticated;
revoke all on function public.origem_da_acao() from public, anon, authenticated;
revoke all on function public.auditar_empresa_plataforma() from public, anon, authenticated;
revoke all on function public.auditar_configuracao_plataforma() from public, anon, authenticated;
revoke all on function public.auditoria_somente_inclusao() from public, anon, authenticated;
revoke all on function public.criar_login_dono(text, text, text) from public, anon, authenticated;
grant execute on function public.criar_login_dono(text, text, text) to service_role;
